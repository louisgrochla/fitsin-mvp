import { DateTime } from 'luxon';
import { config } from '../config.js';
import { fetchWithRetry } from '../utils/http.js';
import { getShopifyAccessToken } from './shopifyTokenStore.js';
import { SELLER_PREFIXES, COMMISSION_RATE, matchSellerPrefix } from './sellerConfig.js';
import { getPaidItemIds } from './sellerPayouts.js';

const SHOPIFY_URL = `https://${config.shopify.domain}/admin/api/2024-10/graphql.json`;

function round2(v) {
  return Math.round(v * 100) / 100;
}

async function shopifyGraphQL(query, variables = {}, retrySafe = true) {
  const accessToken = await getShopifyAccessToken();
  if (!accessToken) {
    throw new Error('Shopify is not connected. Complete OAuth install or set SHOPIFY_ADMIN_TOKEN.');
  }

  const res = await fetchWithRetry(SHOPIFY_URL, {
    method: 'POST',
    retrySafe,
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': accessToken
    },
    body: JSON.stringify({ query, variables })
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Shopify API error ${res.status}: ${text}`);
  }

  const data = await res.json();
  if (data.errors?.length) {
    throw new Error(`Shopify GraphQL errors: ${JSON.stringify(data.errors)}`);
  }

  return data.data;
}

// MARK: - Order Webhook Registration

function orderWebhookCallbackUrl() {
  if (!config.publicBaseUrl) {
    throw new Error('PUBLIC_BASE_URL is not set; cannot register the order webhook.');
  }
  return `${config.publicBaseUrl}/webhooks/shopify/order-created`;
}

export async function listOrderWebhooks() {
  const query = `#graphql
    query {
      webhookSubscriptions(first: 50, topics: [ORDERS_CREATE]) {
        edges {
          node {
            id
            endpoint {
              __typename
              ... on WebhookHttpEndpoint { callbackUrl }
            }
          }
        }
      }
    }
  `;
  const data = await shopifyGraphQL(query);
  return data.webhookSubscriptions.edges.map((edge) => ({
    id: edge.node.id,
    callbackUrl: edge.node.endpoint?.callbackUrl || null
  }));
}

// Idempotently register the orders/create webhook pointing at this backend.
export async function ensureOrderWebhook() {
  const callbackUrl = orderWebhookCallbackUrl();
  const existing = await listOrderWebhooks();
  if (existing.some((w) => w.callbackUrl === callbackUrl)) {
    return { created: false, callbackUrl };
  }

  const mutation = `#graphql
    mutation Register($topic: WebhookSubscriptionTopic!, $sub: WebhookSubscriptionInput!) {
      webhookSubscriptionCreate(topic: $topic, webhookSubscription: $sub) {
        webhookSubscription { id }
        userErrors { field message }
      }
    }
  `;
  const data = await shopifyGraphQL(mutation, {
    topic: 'ORDERS_CREATE',
    sub: { callbackUrl, format: 'JSON' }
  }, false);

  const errors = data.webhookSubscriptionCreate?.userErrors || [];
  if (errors.length) {
    throw new Error(`Webhook registration failed: ${JSON.stringify(errors)}`);
  }
  return { created: true, callbackUrl };
}

async function fetchOrdersBetween(startIso, endIso) {
  const query = `#graphql
    query OrdersInRange($first: Int!, $after: String, $query: String!) {
      orders(first: $first, after: $after, query: $query, sortKey: PROCESSED_AT) {
        pageInfo { hasNextPage endCursor }
        edges {
          node {
            id
            createdAt
            processedAt
            currentTotalPriceSet { shopMoney { amount currencyCode } }
            currentSubtotalPriceSet { shopMoney { amount currencyCode } }
            currentTotalTaxSet { shopMoney { amount currencyCode } }
          }
        }
      }
    }
  `;

  const q = `processed_at:>=${startIso} processed_at:<${endIso} status:any`;

  let after = null;
  const orders = [];

  do {
    const data = await shopifyGraphQL(query, { first: 100, after, query: q });
    const chunk = data.orders.edges.map((edge) => edge.node);
    orders.push(...chunk);
    after = data.orders.pageInfo.hasNextPage ? data.orders.pageInfo.endCursor : null;
  } while (after);

  return orders;
}

async function fetchOrdersWithLineItemsBetween(startIso, endIso) {
  const query = `#graphql
    query OrdersInRangeWithItems($first: Int!, $after: String, $query: String!) {
      orders(first: $first, after: $after, query: $query, sortKey: PROCESSED_AT) {
        pageInfo { hasNextPage endCursor }
        edges {
          node {
            id
            name
            createdAt
            processedAt
            currentTotalPriceSet { shopMoney { amount currencyCode } }
            currentSubtotalPriceSet { shopMoney { amount currencyCode } }
            currentTotalTaxSet { shopMoney { amount currencyCode } }
            lineItems(first: 100) {
              edges {
                node {
                  id
                  name
                  sku
                  quantity
                  originalUnitPriceSet { shopMoney { amount } }
                }
              }
            }
          }
        }
      }
    }
  `;

  const q = `processed_at:>=${startIso} processed_at:<${endIso} status:any`;

  let after = null;
  const orders = [];

  do {
    const data = await shopifyGraphQL(query, { first: 100, after, query: q });
    const chunk = data.orders.edges.map((edge) => edge.node);
    orders.push(...chunk);
    after = data.orders.pageInfo.hasNextPage ? data.orders.pageInfo.endCursor : null;
  } while (after);

  return orders;
}

function toDateKey(iso, timezone) {
  return DateTime.fromISO(iso, { setZone: true }).setZone(timezone).toFormat('yyyy-LL-dd');
}

function orderSaleTimestamp(order) {
  return order?.processedAt || order?.createdAt || null;
}

export async function fetchDailySalesMap(startDate, endDateExclusive, timezone) {
  const orders = await fetchOrdersBetween(startDate.toISO(), endDateExclusive.toISO());
  const map = new Map();

  for (const order of orders) {
    const saleTimestamp = orderSaleTimestamp(order);
    if (!saleTimestamp) continue;
    const key = toDateKey(saleTimestamp, timezone);
    const total = Number(order.currentTotalPriceSet?.shopMoney?.amount || 0);
    const subtotal = Number(order.currentSubtotalPriceSet?.shopMoney?.amount || 0);
    const tax = Number(order.currentTotalTaxSet?.shopMoney?.amount || 0);

    let amount = total;
    if (config.shopify.netSalesMode === 'subtotal_ex_tax_ship') {
      amount = subtotal > 0 ? subtotal : Math.max(total - tax, 0);
    }

    map.set(key, (map.get(key) || 0) + amount);
  }

  return map;
}

function mean(values) {
  if (!values.length) return 0;
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

export function computeTargetForDate(date, historicalRows) {
  // Store closed Sundays (Luxon weekday: 1 = Monday ... 7 = Sunday).
  if (date.weekday === 7) return 0;

  const overallAvg = mean(historicalRows.map((x) => x.amount));
  const byDow = new Map();

  for (const row of historicalRows) {
    const dow = row.date.weekday;
    byDow.set(dow, [...(byDow.get(dow) || []), row.amount]);
  }

  const prevYearRows = historicalRows.filter(
    (row) => row.date.year === date.year - 1 && row.date.month === date.month
  );
  const prevYearWeekdayAvg = mean(prevYearRows.filter((row) => row.date.weekday === date.weekday).map((row) => row.amount));

  const sameMonthAnyYearWeekdayAvg = mean(
    historicalRows
      .filter((row) => row.date.month === date.month && row.date.weekday === date.weekday)
      .map((row) => row.amount)
  );

  const weekdayAvg = mean(byDow.get(date.weekday) || []);
  const base = prevYearWeekdayAvg || sameMonthAnyYearWeekdayAvg || weekdayAvg || overallAvg;
  const growthMultiplier = 1 + config.shopify.targetGrowthPct / 100;
  return Math.max(0, base * growthMultiplier);
}

export function buildHistoricalRows(salesMap, beforeDate, timezone) {
  const rows = [];
  for (const [key, amount] of salesMap.entries()) {
    const date = DateTime.fromFormat(key, 'yyyy-LL-dd', { zone: timezone });
    if (date < beforeDate.startOf('day')) {
      rows.push({ date, amount });
    }
  }
  return rows;
}

export async function fetchDailySalesItems(dateKey, timezone) {
  const day = DateTime.fromFormat(dateKey, 'yyyy-LL-dd', { zone: timezone });
  if (!day.isValid) {
    throw new Error('Invalid date. Expected YYYY-MM-DD.');
  }

  const start = day.startOf('day');
  const end = start.plus({ days: 1 });
  const orders = await fetchOrdersWithLineItemsBetween(start.toISO(), end.toISO());
  const items = [];

  for (const order of orders) {
    const soldAt = orderSaleTimestamp(order);
    if (!soldAt) continue;
    if (toDateKey(soldAt, timezone) !== dateKey) continue;
    const lineItems = Array.isArray(order.lineItems?.edges) ? order.lineItems.edges : [];

    const names = lineItems
      .map((edge) => edge?.node?.name)
      .filter(Boolean);
    const totalQty = lineItems.reduce((sum, edge) => sum + Number(edge?.node?.quantity || 0), 0);

    const total = Number(order.currentTotalPriceSet?.shopMoney?.amount || 0);
    const subtotal = Number(order.currentSubtotalPriceSet?.shopMoney?.amount || 0);
    const tax = Number(order.currentTotalTaxSet?.shopMoney?.amount || 0);
    let amount = total;
    if (config.shopify.netSalesMode === 'subtotal_ex_tax_ship') {
      amount = subtotal > 0 ? subtotal : Math.max(total - tax, 0);
    }

    // Build a per-line breakdown. Consignment (seller-tagged) lines only earn
    // the store its commission; the seller keeps the rest. We surface both the
    // gross price and the amount the store actually keeps so the day view can
    // show the real store revenue rather than the full ticket price.
    const lineBreakdown = [];
    let sellerDeduction = 0;
    let hasCommission = false;

    for (const edge of lineItems) {
      const node = edge?.node;
      if (!node) continue;
      const qty = Number(node.quantity || 1);
      const unitPrice = Number(node.originalUnitPriceSet?.shopMoney?.amount || 0);
      const gross = round2(unitPrice * qty);
      const seller = matchSellerPrefix(node.name);

      if (seller) {
        hasCommission = true;
        const commission = round2(gross * COMMISSION_RATE);
        const sellerNet = round2(gross - commission);
        sellerDeduction = round2(sellerDeduction + sellerNet);
        lineBreakdown.push({
          name: node.name || 'Item',
          sku: typeof node.sku === 'string' && node.sku.trim() ? node.sku.trim() : null,
          source_shop: config.shopify.domain.toLowerCase(),
          quantity: qty,
          gross,
          seller,
          is_commission: true,
          commission,
          store_net: commission
        });
      } else {
        lineBreakdown.push({
          name: node.name || 'Item',
          sku: typeof node.sku === 'string' && node.sku.trim() ? node.sku.trim() : null,
          source_shop: config.shopify.domain.toLowerCase(),
          quantity: qty,
          gross,
          seller: null,
          is_commission: false,
          commission: 0,
          store_net: gross
        });
      }
    }

    // Order-level store revenue: total minus what the sellers are owed. Kept in
    // sync with the metrics deduction so the day view reconciles with the month.
    const storeNet = round2(Math.max(0, amount - sellerDeduction));

    const description = names.length
      ? names.slice(0, 4).join(' • ')
      : 'Order';

    items.push({
      id: `shopify:${order.id}`,
      kind: 'shopify',
      sold_at: soldAt,
      description,
      quantity: totalQty > 0 ? totalQty : 1,
      amount,
      store_net: storeNet,
      has_commission: hasCommission,
      line_items: lineBreakdown,
      order_name: order.name || null,
      source: 'shopify'
    });
  }

  items.sort((a, b) => String(b.sold_at).localeCompare(String(a.sold_at)));
  return items;
}

// MARK: - Seller Deductions (for metrics adjustment)

export async function fetchSellerDeductionsMap(startDate, endDateExclusive, timezone) {
  const orders = await fetchOrdersWithLineItemsBetween(startDate.toISO(), endDateExclusive.toISO());
  const deductions = new Map();

  for (const order of orders) {
    const saleTimestamp = orderSaleTimestamp(order);
    if (!saleTimestamp) continue;
    const key = toDateKey(saleTimestamp, timezone);

    const lineItems = Array.isArray(order.lineItems?.edges) ? order.lineItems.edges : [];

    for (const edge of lineItems) {
      const node = edge?.node;
      if (!node) continue;
      const seller = matchSellerPrefix(node.name);
      if (!seller) continue;

      const unitPrice = Number(node.originalUnitPriceSet?.shopMoney?.amount || 0);
      const qty = Number(node.quantity || 1);
      const sellerPortion = unitPrice * qty * (1 - COMMISSION_RATE);

      deductions.set(key, Math.round(((deductions.get(key) || 0) + sellerPortion) * 100) / 100);
    }
  }

  return deductions;
}

// MARK: - Seller Sales

export async function fetchSellerSales(monthKey, timezone) {
  const month = DateTime.fromFormat(monthKey, 'yyyy-LL', { zone: timezone });
  if (!month.isValid) throw new Error('Invalid month. Expected YYYY-MM.');

  const start = month.startOf('month');
  const end = month.endOf('month').plus({ days: 1 }).startOf('day');
  const [orders, paidIds] = await Promise.all([
    fetchOrdersWithLineItemsBetween(start.toISO(), end.toISO()),
    getPaidItemIds().catch(() => new Set())
  ]);

  const sellerItems = [];

  for (const order of orders) {
    const soldAt = orderSaleTimestamp(order);
    if (!soldAt) continue;

    const lineItems = Array.isArray(order.lineItems?.edges) ? order.lineItems.edges : [];

    for (const edge of lineItems) {
      const node = edge?.node;
      if (!node) continue;

      const seller = matchSellerPrefix(node.name);
      if (!seller) continue;

      const unitPrice = Number(node.originalUnitPriceSet?.shopMoney?.amount || 0);
      const qty = Number(node.quantity || 1);
      const gross = unitPrice * qty;
      const itemId = `${order.id}:${node.id}`;

      sellerItems.push({
        id: itemId,
        seller,
        item_name: node.name,
        quantity: qty,
        gross: round2(gross),
        commission: round2(gross * COMMISSION_RATE),
        seller_net: round2(gross * (1 - COMMISSION_RATE)),
        paid: paidIds.has(itemId),
        sold_at: soldAt,
        date: toDateKey(soldAt, timezone),
        order_name: order.name || null
      });
    }
  }

  // Build per-seller summaries, splitting what's owed into paid vs outstanding.
  const summaryMap = {};
  for (const prefix of SELLER_PREFIXES) {
    summaryMap[prefix] = {
      seller: prefix,
      total_gross: 0,
      total_commission: 0,
      total_net: 0,
      total_paid: 0,
      total_unpaid: 0,
      item_count: 0
    };
  }

  for (const item of sellerItems) {
    const s = summaryMap[item.seller];
    s.total_gross = round2(s.total_gross + item.gross);
    s.total_commission = round2(s.total_commission + item.commission);
    s.total_net = round2(s.total_net + item.seller_net);
    if (item.paid) {
      s.total_paid = round2(s.total_paid + item.seller_net);
    } else {
      s.total_unpaid = round2(s.total_unpaid + item.seller_net);
    }
    s.item_count += item.quantity;
  }

  sellerItems.sort((a, b) => String(b.sold_at).localeCompare(String(a.sold_at)));

  return {
    sellers: Object.values(summaryMap),
    items: sellerItems,
    commission_rate: COMMISSION_RATE,
    month: monthKey
  };
}
