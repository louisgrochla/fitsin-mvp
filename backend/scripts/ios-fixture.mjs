// Local manual-check server. No production integrations, persistence or credential logging.
// MODE=week-failure|today-failure|unauthorized|malformed|save-failure|healthy
import { createServer } from 'node:http';
import { DateTime } from 'luxon';
import { randomUUID } from 'node:crypto';
const mode = process.env.MODE || 'healthy';
const now = () => DateTime.now().setZone('Europe/London');
const entries = [];
const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  console.log(`${req.method} ${url.pathname}`);
  const send = (body, status = 200) => {
    res.writeHead(status, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(body));
  };
  if (url.pathname === '/health') return send({ ok: true });
  if (mode === 'unauthorized') return send({ error: 'Synthetic expired access' }, 401);
  if (mode === 'malformed') { res.writeHead(200); return res.end('{broken'); }
  if (url.pathname === '/v1/today') {
    if (mode === 'today-failure') return send({ error: 'Synthetic Today failure' }, 502);
    return send({ actual_today: 25, target_today: 100, month_goal: 1000,
      remaining: 75, pct: 25, updated_at: now().toISO(), data_delayed: false, warning: null });
  }
  if (url.pathname === '/v1/month') {
    await new Promise((resolve) => setTimeout(resolve, Number(process.env.MONTH_DELAY_MS || 2000)));
    if (mode === 'week-failure') return send({ error: 'Synthetic month failure' }, 502);
    const month = url.searchParams.get('month') || now().toFormat('yyyy-LL');
    const start = DateTime.fromFormat(month, 'yyyy-LL', { zone: 'Europe/London' });
    return send({ month, month_goal: 1000, mtd_actual: 25, mtd_target: 100, ahead_behind: -75,
      days: Array.from({ length: start.daysInMonth }, (_, i) => ({ date: start.plus({ days: i }).toFormat('yyyy-LL-dd'), actual: 0, target: 100 })),
      updated_at: now().toISO(), data_delayed: false, warning: null });
  }
  if (url.pathname === '/v1/manual-entries' && req.method === 'POST') {
    if (mode === 'save-failure') return send({ error: 'Synthetic unconfirmed save' }, 503);
    let input = '';
    for await (const chunk of req) input += chunk;
    try {
      const entry = { ...JSON.parse(input), id: randomUUID(), created_at: now().toISO() };
      entries.push(entry);
      return send(entry, 201);
    }
    catch { return send({ error: 'Bad synthetic input' }, 400); }
  }
  if (url.pathname === '/v1/manual-entries') return send({ entries, updated_at: now().toISO() });
  if (url.pathname === '/v1/rota') return send({ entries: [], updated_at: now().toISO() });
  if (url.pathname === '/v1/rota/schedule') return send({ schedule: null });
  return send({ error: 'Fixture route not implemented' }, 404);
});
server.listen(Number(process.env.PORT || 31988), '127.0.0.1', () => {
  console.log(`Synthetic iOS fixture: http://127.0.0.1:${server.address().port} (${mode})`);
});
