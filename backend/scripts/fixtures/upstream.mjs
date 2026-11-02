// Synthetic subprocess only. Never forwards a request to a real service.
import { Settings } from 'luxon';
import { setTimeout as delay } from 'node:timers/promises';

Settings.now = () => Date.parse('2026-11-02T12:00:00Z');
let calls = 0;
let failing = false;
process.on('message', (message) => {
  if (message === 'fail') failing = true;
  if (message === 'recover') failing = false;
  process.send?.({ calls });
});
globalThis.fetch = async (url, options) => {
  if (!String(url).startsWith('https://synthetic.invalid/')) {
    throw new Error('Fixture forbids external services');
  }
  calls += 1;
  await delay(2, undefined, { signal: options.signal });
  if (failing) return new Response('{}', { status: 503 });
  const { variables } = JSON.parse(options.body);
  const size = Number(process.env.FIXTURE_SIZE);
  const start = Number(variables.after || 0);
  const end = Math.min(start + 100, size);
  return Response.json({ data: { orders: {
    pageInfo: { hasNextPage: end < size, endCursor: String(end) },
    edges: Array.from({ length: end - start }, (_, offset) => {
      const i = start + offset;
      return { node: {
        id: `synthetic-${i}`, name: `Order ${i}`,
        processedAt: `2026-11-0${1 + i % 2}T10:00:00Z`,
        currentTotalPriceSet: { shopMoney: { amount: '10.00', currencyCode: 'GBP' } },
        currentSubtotalPriceSet: { shopMoney: { amount: '10.00', currencyCode: 'GBP' } },
        currentTotalTaxSet: { shopMoney: { amount: '0.00', currencyCode: 'GBP' } },
        lineItems: { edges: [] }
      } };
    })
  } } });
};
