import express from 'express';
import crypto from 'node:crypto';
import helmet from 'helmet';
import morgan from 'morgan';
import { config } from './config.js';
import { requireAppCode } from './middleware/auth.js';
import { computeMonthMetrics, computeTodayMetrics } from './services/metrics.js';
import { fetchEventById, fetchEventsMeta, fetchUpcomingEvents, updateEvent } from './services/notion.js';
import { buildInstallUrl, exchangeCodeForOfflineToken } from './services/shopifyOAuth.js';
import { hasShopifyAccessToken } from './services/shopifyTokenStore.js';
import { currentMonthKey, getMonthGoal, setMonthGoal } from './services/monthGoals.js';
import { createManualEntry, deleteManualEntry, listManualEntries } from './services/manualEntries.js';
import { getRotaEntries, addRotaEntry, removeRotaEntry, getSchedules, setSchedule, getScheduleForUser } from './services/rota.js';
import { fetchDailySalesItems, fetchSellerSales, ensureOrderWebhook, listOrderWebhooks } from './services/shopify.js';
import { setSellerItemPaid } from './services/sellerPayouts.js';
import { registerDevice, updatePreferences, removeDevice, getAllDevices, getDevice } from './services/pushDevices.js';
import { sendPushToPreference, sendPushToSeller } from './services/push.js';
import { COMMISSION_RATE, matchSellerPrefix } from './services/sellerConfig.js';
import { sendDailySummary, sendRotaReminders } from './services/pushJobs.js';
import { startScheduler } from './services/scheduler.js';
import { TTLCache } from './utils/cache.js';
import { DateTime } from 'luxon';

const app = express();
const cache = new TTLCache();
const oauthStateCache = new TTLCache();
const ttlMs = config.cacheTtlSeconds * 1000;
const staleMaxMs = config.staleCacheMaxAgeSeconds * 1000;

app.use(helmet({ hsts: config.nodeEnv === 'production' }));

// Shopify webhook needs raw body for HMAC verification — must come before express.json()
app.post('/webhooks/shopify/order-created', express.raw({ type: 'application/json' }), async (req, res) => {
  try {
    // Verify Shopify HMAC
    const hmacHeader = req.header('X-Shopify-Hmac-Sha256') || '';
    const secret = config.shopify.apiSecret;

    if (secret && hmacHeader) {
      const computed = crypto.createHmac('sha256', secret).update(req.body).digest('base64');
      if (!crypto.timingSafeEqual(Buffer.from(computed), Buffer.from(hmacHeader))) {
        return res.status(401).json({ error: 'Invalid webhook signature' });
      }
    }

    const order = JSON.parse(req.body.toString());
    const lineItems = Array.isArray(order.line_items) ? order.line_items : [];

    // Calculate order total (store revenue)
    const orderTotal = Number(order.subtotal_price || order.total_price || 0);
    const orderName = order.name || '';

    // London date the sale belongs to — used so tapping the notification opens
    // the correct day's sales page in the app.
    const saleDate = order.created_at
      ? DateTime.fromISO(order.created_at, { zone: config.timezone }).toFormat('yyyy-LL-dd')
      : DateTime.now().setZone(config.timezone).toFormat('yyyy-LL-dd');

    // Total quantity across all lines (multi-item orders show the count).
    const itemCount = lineItems.reduce((sum, li) => sum + Number(li.quantity || 1), 0);

    // Check for seller items and calculate deductions
    let sellerDeduction = 0;
    const sellerItems = [];

    for (const li of lineItems) {
      const name = li.title || li.name || '';
      const prefix = matchSellerPrefix(name);
      if (!prefix) continue;
      const gross = Number(li.price || 0) * Number(li.quantity || 1);
      const sellerNet = gross * (1 - COMMISSION_RATE);
      sellerDeduction += sellerNet;
      sellerItems.push({ prefix, name, gross, sellerNet, commission: gross * COMMISSION_RATE });
    }

    // Store's take. For consignment items this is only the 15% commission, so
    // the general audience never sees an inflated "we earned £100" figure.
    const storeRevenue = Math.max(0, orderTotal - sellerDeduction);
    const hasCommission = sellerItems.length > 0;

    // Compressed "new sale" copy for everyone with new_sale on. We deliberately
    // avoid listing item names — just how many sold and the store's net.
    const gbp = (v) => `£${Number(v).toFixed(2)}`;
    let body;
    if (itemCount > 1) {
      body = `${itemCount} items sold — ${gbp(storeRevenue)}`;
    } else {
      body = `Something sold — ${gbp(storeRevenue)}`;
    }
    if (hasCommission) body += ' · consignment';

    await sendPushToPreference('new_sale', {
      title: 'New Sale',
      body,
      data: { type: 'new_sale', order_name: orderName, date: saleDate }
    });

    // Send seller-specific notifications: the seller sees what they earn (after
    // commission) alongside the full sale price before commission.
    for (const si of sellerItems) {
      await sendPushToSeller(si.prefix, {
        title: 'Your Sale',
        body: `${gbp(si.sellerNet)} to you — sold for ${gbp(si.gross)}`,
        data: { type: 'commission_sale', prefix: si.prefix, date: saleDate }
      });
    }

    // Bust cache so next API call reflects new order
    cache.clear();

    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error('[webhook] order-created error:', error);
    return res.status(200).json({ ok: true }); // Always 200 to Shopify to prevent retries
  }
});

app.use(express.json());
app.use(morgan('tiny'));
app.use(requireAppCode);

app.get('/health', (_req, res) => {
  res.json({ ok: true, time: new Date().toISOString() });
});

app.get('/auth/shopify/start', (req, res) => {
  try {
    const state = crypto.randomBytes(24).toString('hex');
    oauthStateCache.set(`state:${state}`, true, 10 * 60 * 1000);
    const installUrl = buildInstallUrl(state, req.query.shop);
    return res.redirect(302, installUrl);
  } catch (error) {
    return res.status(500).json({ error: 'Failed to build Shopify install URL', detail: error.message });
  }
});

app.get('/auth/shopify/callback', async (req, res) => {
  try {
    const state = String(req.query.state || '');
    const stateIsValid = oauthStateCache.get(`state:${state}`);
    if (!state || !stateIsValid) {
      return res.status(400).json({ error: 'Invalid or expired OAuth state' });
    }

    const rawQuery = req.originalUrl.includes('?') ? req.originalUrl.split('?')[1] : '';
    const result = await exchangeCodeForOfflineToken(req.query, state, rawQuery);

    // Register the orders/create webhook now that we hold a token. Non-fatal:
    // the connection still succeeds even if webhook setup can't complete.
    try {
      const hook = await ensureOrderWebhook();
      console.log(`[shopify] order webhook ${hook.created ? 'created' : 'already present'} → ${hook.callbackUrl}`);
    } catch (hookError) {
      console.error('[shopify] webhook registration failed:', hookError.message);
    }

    return res.status(200).send(
      `Shopify connected successfully for ${result.shop}. You can return to the fit'sin app setup.`
    );
  } catch (error) {
    return res.status(400).json({ error: 'Shopify OAuth callback failed', detail: error.message });
  }
});

app.get('/auth/shopify/status', async (_req, res) => {
  const connected = await hasShopifyAccessToken();
  res.json({
    connected,
    shop: config.shopify.domain
  });
});

// Idempotently (re)register the orders/create webhook. Useful for stores that
// connected before webhook auto-registration existed, or after a URL change.
app.post('/v1/shopify/register-webhook', async (_req, res) => {
  try {
    const result = await ensureOrderWebhook();
    return res.json({ ok: true, ...result });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to register webhook', detail: error.message });
  }
});

app.get('/v1/shopify/webhooks', async (_req, res) => {
  try {
    const webhooks = await listOrderWebhooks();
    return res.json({ webhooks });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to list webhooks', detail: error.message });
  }
});

async function cached(key, producer) {
  const hit = cache.get(key);
  if (hit) return { payload: hit, stale: false };

  try {
    const val = await producer();
    cache.set(key, val, ttlMs);
    return { payload: val, stale: false };
  } catch (error) {
    const stale = cache.getStale(key, staleMaxMs);
    if (stale) {
      console.warn(`Serving stale cache for ${key}: ${error.message}`);
      return { payload: stale, stale: true };
    }
    throw error;
  }
}

app.get('/v1/today', async (_req, res) => {
  try {
    const { payload, stale } = await cached('today', () => computeTodayMetrics());
    return res.json({
      ...payload,
      data_delayed: Boolean(stale),
      warning: stale ? 'Showing cached data due to temporary upstream issues.' : null
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load today metrics', detail: error.message });
  }
});

app.get('/v1/month', async (req, res) => {
  try {
    const month = typeof req.query.month === 'string' ? req.query.month.trim() : '';
    if (month && !/^\d{4}-\d{2}$/.test(month)) {
      return res.status(400).json({ error: 'Invalid month format. Expected YYYY-MM.' });
    }

    const cacheKey = month ? `month:${month}` : 'month:current';
    const { payload, stale } = await cached(cacheKey, () => computeMonthMetrics(month || null));
    return res.json({
      ...payload,
      data_delayed: Boolean(stale),
      warning: stale ? 'Showing cached data due to temporary upstream issues.' : null
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load month metrics', detail: error.message });
  }
});

app.get('/v1/events', async (_req, res) => {
  try {
    const { payload, stale } = await cached('events', () => fetchUpcomingEvents(config.timezone));
    return res.json({
      events: payload,
      updated_at: new Date().toISOString(),
      data_delayed: Boolean(stale),
      warning: stale ? 'Showing cached data due to temporary upstream issues.' : null
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load events', detail: error.message });
  }
});

app.get('/v1/events/meta', async (_req, res) => {
  try {
    const meta = await fetchEventsMeta();
    return res.json({
      ...meta,
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load event metadata', detail: error.message });
  }
});

app.get('/v1/events/:id', async (req, res) => {
  try {
    const event = await fetchEventById(req.params.id);
    return res.json({
      event,
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load event detail', detail: error.message });
  }
});

app.patch('/v1/events/:id', async (req, res) => {
  try {
    const updates = {
      title: req.body?.title,
      date: req.body?.date,
      event: req.body?.event,
      type: req.body?.type,
      place: req.body?.place,
      tags: req.body?.tags,
      assignees: req.body?.assignees,
      note: req.body?.note
    };
    const event = await updateEvent(req.params.id, updates);
    cache.delete('events');
    return res.json({
      event,
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to update event', detail: error.message });
  }
});

app.get('/v1/day', async (req, res) => {
  try {
    const date = String(req.query.date || '').trim();
    const parsed = DateTime.fromFormat(date, 'yyyy-LL-dd', { zone: config.timezone });
    if (!parsed.isValid) {
      return res.status(400).json({ error: 'Invalid date. Expected YYYY-MM-DD.' });
    }

    const key = `day:${date}`;
    const { payload, stale } = await cached(key, async () => {
      const [shopifyItems, manualEntries] = await Promise.all([
        fetchDailySalesItems(date, config.timezone),
        listManualEntries({ from: date, to: date, limit: 500 }, config.timezone)
      ]);

      const manualItems = manualEntries.map((entry) => ({
        id: `manual:${entry.id}`,
        kind: 'manual',
        sold_at: entry.created_at,
        description: entry.description || `${entry.source} sale`,
        quantity: 1,
        amount: Number(entry.amount || 0),
        store_net: Number(entry.amount || 0),
        has_commission: false,
        line_items: [],
        source: entry.source,
        note: entry.note || null,
        order_name: null
      }));

      const items = [...shopifyItems, ...manualItems].sort((a, b) => String(b.sold_at).localeCompare(String(a.sold_at)));
      return {
        date,
        items,
        updated_at: new Date().toISOString()
      };
    });

    return res.json({
      ...payload,
      data_delayed: Boolean(stale),
      warning: stale ? 'Showing cached data due to temporary upstream issues.' : null
    });
  } catch (error) {
    return res.status(502).json({ error: 'Failed to load day sales', detail: error.message });
  }
});

app.get('/v1/month-goal', async (req, res) => {
  try {
    const month = String(req.query.month || currentMonthKey(config.timezone));
    const goal = await getMonthGoal(month);
    return res.json({ month, goal, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to load month goal', detail: error.message });
  }
});

app.put('/v1/month-goal', async (req, res) => {
  try {
    const month = String(req.body?.month || currentMonthKey(config.timezone));
    const rawGoal = req.body?.goal;
    const goal = rawGoal === null ? null : Number(rawGoal);
    const savedGoal = await setMonthGoal(month, goal);
    cache.delete('today');
    cache.clear();
    return res.json({ month, goal: savedGoal, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to save month goal', detail: error.message });
  }
});

app.get('/v1/manual-entries', async (req, res) => {
  try {
    const entries = await listManualEntries(
      {
        from: req.query.from,
        to: req.query.to,
        limit: req.query.limit
      },
      config.timezone
    );
    return res.json({
      entries,
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to load manual entries', detail: error.message });
  }
});

app.post('/v1/manual-entries', async (req, res) => {
  try {
    const entry = await createManualEntry(req.body, config.timezone);
    cache.delete('today');
    cache.clear();
    cache.delete(`day:${entry.date}`);
    return res.status(201).json(entry);
  } catch (error) {
    return res.status(400).json({ error: 'Failed to create manual entry', detail: error.message });
  }
});

app.delete('/v1/manual-entries/:id', async (req, res) => {
  try {
    const deleted = await deleteManualEntry(req.params.id);
    cache.delete('today');
    cache.clear();
    if (deleted?.date) cache.delete(`day:${deleted.date}`);
    return res.status(204).send();
  } catch (error) {
    if (error.message === 'Manual entry not found.') {
      return res.status(404).json({ error: 'Failed to delete manual entry', detail: error.message });
    }
    return res.status(400).json({ error: 'Failed to delete manual entry', detail: error.message });
  }
});

// ── Sellers ──────────────────────────────────────────

app.get('/v1/sellers', async (req, res) => {
  try {
    const month = req.query.month || currentMonthKey();
    const data = await fetchSellerSales(month, config.timezone);
    return res.json({ ...data, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to load seller sales', detail: error.message });
  }
});

// Toggle whether a consignment seller line item has been paid out. Shared state
// via the persistent disk so every device sees the same paid/unpaid status.
app.put('/v1/sellers/paid', async (req, res) => {
  try {
    const itemId = req.body?.item_id;
    const paid = req.body?.paid;
    if (!itemId) {
      return res.status(400).json({ error: 'item_id is required' });
    }
    const result = await setSellerItemPaid(itemId, Boolean(paid), req.body?.by || null);
    // Bust seller caches so the next fetch reflects the new paid state.
    cache.clear();
    return res.json({ ...result, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to update payout status', detail: error.message });
  }
});

// ── Rota ──────────────────────────────────────────────

app.get('/v1/rota', async (req, res) => {
  try {
    const entries = await getRotaEntries(req.query.from, req.query.to, config.timezone);
    return res.json({ entries, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to load rota', detail: error.message });
  }
});

app.post('/v1/rota', async (req, res) => {
  try {
    const entry = await addRotaEntry(req.body, config.timezone);
    return res.status(201).json(entry);
  } catch (error) {
    return res.status(400).json({ error: 'Failed to add rota entry', detail: error.message });
  }
});

app.delete('/v1/rota/:id', async (req, res) => {
  try {
    await removeRotaEntry(req.params.id);
    return res.status(204).send();
  } catch (error) {
    if (error.message === 'Rota entry not found.') {
      return res.status(404).json({ error: 'Failed to delete rota entry', detail: error.message });
    }
    return res.status(400).json({ error: 'Failed to delete rota entry', detail: error.message });
  }
});

app.get('/v1/rota/schedule', async (req, res) => {
  try {
    const name = req.query.name;
    if (name) {
      const schedule = await getScheduleForUser(name);
      return res.json({ schedule });
    }
    const schedules = await getSchedules();
    return res.json({ schedules, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to load schedules', detail: error.message });
  }
});

app.put('/v1/rota/schedule', async (req, res) => {
  try {
    const schedules = await setSchedule(req.body);
    return res.json({ schedules, updated_at: new Date().toISOString() });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to save schedule', detail: error.message });
  }
});

// ── Devices (Push Registration) ───────────────────────

app.get('/v1/devices', async (req, res) => {
  try {
    const devices = await getAllDevices();
    return res.json({ devices, count: devices.length });
  } catch (error) {
    return res.status(400).json({ error: 'Failed to list devices', detail: error.message });
  }
});

app.get('/v1/devices/:token', async (req, res) => {
  try {
    const device = await getDevice(req.params.token);
    if (!device) {
      return res.status(404).json({ error: 'Device not found' });
    }
    return res.json(device);
  } catch (error) {
    return res.status(400).json({ error: 'Failed to load device', detail: error.message });
  }
});

app.post('/v1/devices', async (req, res) => {
  try {
    const device = await registerDevice(req.body);
    return res.status(201).json(device);
  } catch (error) {
    return res.status(400).json({ error: 'Failed to register device', detail: error.message });
  }
});

app.put('/v1/devices', async (req, res) => {
  try {
    const device = await updatePreferences(req.body.token, req.body.preferences);
    return res.json(device);
  } catch (error) {
    return res.status(400).json({ error: 'Failed to update preferences', detail: error.message });
  }
});

app.delete('/v1/devices/:token', async (req, res) => {
  try {
    await removeDevice(req.params.token);
    return res.status(204).send();
  } catch (error) {
    return res.status(400).json({ error: 'Failed to remove device', detail: error.message });
  }
});

// ── Push Triggers (called by cron jobs) ───────────────

app.post('/v1/push/daily-summary', async (_req, res) => {
  try {
    const result = await sendDailySummary();
    return res.json({ ok: true, ...result });
  } catch (error) {
    console.error('[push] daily-summary error:', error);
    return res.status(500).json({ error: 'Failed to send daily summary', detail: error.message });
  }
});

app.post('/v1/push/rota-reminder', async (_req, res) => {
  try {
    const result = await sendRotaReminders();
    return res.json({ ok: true, ...result });
  } catch (error) {
    console.error('[push] rota-reminder error:', error);
    return res.status(500).json({ error: 'Failed to send rota reminders', detail: error.message });
  }
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal error' });
});

app.listen(config.port, () => {
  console.log(`fit'sin backend listening on :${config.port}`);
  startScheduler();
});
