import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { createStockSummary } from './services/stockSummary.js';
const secret = 'synthetic-bridge-secret-0000000000000000';
const counts = { drafts: 3, active: 8, reserved: 1, pendingManual: 2, doubleSales: 0, failedListings: 4, openQuestions: 5 };
const payload = () => ({ schemaVersion: 1, sellerId: 'shared', generatedAt: '2026-11-02T12:00:00Z', counts });
async function fixture(t, handler) {
  const server = createServer(handler);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  return { baseUrl, enabled: true, token: secret, sellerId: 'shared' };
}
test('bridge disabled or incomplete configuration produces no request', async (t) => {
  let calls = 0;
  const bridge = await fixture(t, (_req, res) => { calls++; res.end('{}'); });
  assert.equal((await createStockSummary({ ...bridge, enabled: false })()).status, 'disabled');
  assert.equal((await createStockSummary(bridge)()).status, 'unavailable'); // HTTP forbidden outside explicit test fixture
  assert.equal((await createStockSummary({ ...bridge, token: '' }, { allowLoopback: true })()).status, 'unavailable');
  for (const token of ['x'.repeat(1025), 'x'.repeat(32) + ' ', 'x'.repeat(32) + '\n', 'x'.repeat(32) + 'é']) {
    assert.equal((await createStockSummary({ ...bridge, token }, { allowLoopback: true })()).status, 'unavailable');
  }
  for (const baseUrl of ['https://user:password@synthetic.invalid', 'https://synthetic.invalid/path', 'https://synthetic.invalid?query=1']) {
    assert.equal((await createStockSummary({ ...bridge, baseUrl })()).status, 'unavailable');
  }
  assert.equal(calls, 0);
});
test('only GETs the fixed read route, coalesces overlap, validates scope and strips extra fields', async (t) => {
  let calls = 0;
  const bridge = await fixture(t, (req, res) => {
    calls++;
    assert.equal(req.method, 'GET');
    assert.equal(req.url, '/integrations/fitsin/stock-summary');
    assert.equal(req.headers.authorization, `Bearer ${secret}`);
    setTimeout(() => res.end(JSON.stringify({ ...payload(), token: secret, listedValue: 999 })), 20);
  });
  const read = createStockSummary(bridge, { allowLoopback: true });
  const results = await Promise.all(Array.from({ length: 8 }, () => read()));
  assert.equal(calls, 1);
  assert.deepEqual(results[0].data, counts);
  assert.equal(results[0].status, 'fresh');
  assert.equal(results[0].complete, true);
  assert.equal(JSON.stringify(results).includes(secret), false);
  assert.equal(JSON.stringify(results).includes('listedValue'), false);
  await read();
  assert.equal(calls, 2);
});
test('scope mismatch, malformed counts and revoked credentials never become successful data', async (t) => {
  let mode = 'healthy';
  const bridge = await fixture(t, (_req, res) => {
    if (mode === 'revoked') { res.writeHead(401).end(); return; }
    const body = payload();
    if (mode === 'scope') body.sellerId = 'other';
    if (mode === 'counts') body.counts = { ...counts, drafts: -1 };
    res.end(JSON.stringify(body));
  });
  const read = createStockSummary(bridge, { allowLoopback: true });
  assert.equal((await read()).status, 'fresh');
  for (mode of ['scope', 'counts', 'revoked']) {
    const result = await read();
    assert.equal(result.status, mode === 'counts' ? 'unavailable' : 'unauthorized');
    assert.equal(result.data, null);
    assert.equal(result.complete, false);
  }
  mode = 'healthy';
  assert.equal((await read()).status, 'fresh');
});

test('captures configuration so a later mutation cannot relabel an in-flight response', async (t) => {
  let release;
  const entered = new Promise((resolve) => { release = resolve; });
  let respond;
  const bridge = await fixture(t, (req, res) => {
    assert.equal(req.headers.authorization, `Bearer ${secret}`);
    respond = () => res.end(JSON.stringify(payload()));
    release();
  });
  const read = createStockSummary(bridge, { allowLoopback: true });
  const pending = read();
  await entered;
  bridge.sellerId = 'other';
  bridge.token = 'different-secret-0000000000000000';
  respond();
  const result = await pending;
  assert.equal(result.status, 'fresh');
  assert.equal(result.sellerId, 'shared');
});

test('rejects invalid schema and every malformed count without fabricating zeros', async (t) => {
  let body = payload();
  const bridge = await fixture(t, (_req, res) => res.end(JSON.stringify(body)));
  const read = createStockSummary(bridge, { allowLoopback: true });
  for (const key of Object.keys(counts)) {
    for (const value of [null, -1, 0.5, '1', Number.MAX_SAFE_INTEGER + 1]) {
      body = { ...payload(), counts: { ...counts, [key]: value } };
      assert.deepEqual(await read(), { schemaVersion: 1, status: 'unavailable', complete: false, sellerId: 'shared', data: null });
    }
  }
  for (body of [{ ...payload(), schemaVersion: 2 }, { ...payload(), generatedAt: 'invalid' }, { ...payload(), counts: {} }]) {
    assert.equal((await read()).status, 'unavailable');
  }
  body = { ...payload(), counts: Object.fromEntries(Object.keys(counts).map((key) => [key, 0])) };
  assert.equal((await read()).status, 'fresh');
});
test('stalled bodies time out and later refresh recovers without retries', async (t) => {
  let stalled = true, calls = 0;
  const bridge = await fixture(t, (_req, res) => {
    calls++;
    if (stalled) { res.writeHead(200); res.write('{'); }
    else res.end(JSON.stringify(payload()));
  });
  const read = createStockSummary(bridge, { allowLoopback: true, timeoutMs: 100 });
  assert.equal((await read()).status, 'unavailable');
  assert.equal(calls, 1);
  stalled = false;
  assert.equal((await read()).status, 'fresh');
});
test('redirects, oversized responses and invalid JSON fail without leaking upstream content', async (t) => {
  let mode = 'redirect';
  const bridge = await fixture(t, (_req, res) => {
    if (mode === 'redirect') res.writeHead(302, { Location: 'https://other.invalid' }).end();
    else res.end(mode === 'oversize' ? 'x'.repeat(17000) : 'broken secret body');
  });
  const read = createStockSummary(bridge, { allowLoopback: true });
  for (mode of ['redirect', 'oversize', 'json']) {
    const result = await read();
    assert.equal(result.status, 'unavailable');
    assert.equal(JSON.stringify(result).includes('secret'), false);
  }
});

test('the actual Fitsin route retains shared-code authentication and defaults to disabled', async (t) => {
  const { fork } = await import('node:child_process');
  const { mkdtemp, rm } = await import('node:fs/promises');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const { fileURLToPath } = await import('node:url');
  const directory = await mkdtemp(join(tmpdir(), 'fitsin-stock-route-'));
  const probe = createServer();
  probe.listen(0, '127.0.0.1');
  await once(probe, 'listening');
  const port = probe.address().port;
  await new Promise((resolve) => probe.close(resolve));
  const child = fork(fileURLToPath(new URL('./server.js', import.meta.url)), [], {
    cwd: directory,
    env: { PATH: process.env.PATH, NODE_ENV: 'test', PORT: String(port), DATA_DIR: directory, APP_SHARED_CODE: 'synthetic-app-code' },
    stdio: ['ignore', 'pipe', 'pipe', 'ipc'],
  });
  t.after(async () => {
    if (child.exitCode === null) { const exited = once(child, 'exit'); child.kill(); await exited; }
    await rm(directory, { recursive: true, force: true });
  });
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('fixture startup timeout')), 5000);
    child.once('exit', () => { clearTimeout(timer); reject(new Error('fixture exited')); });
    child.stdout.on('data', (data) => {
      if (String(data).includes('backend listening')) { clearTimeout(timer); resolve(); }
    });
  });
  const url = `http://127.0.0.1:${port}/v1/stock-summary`;
  assert.equal((await fetch(url)).status, 401);
  const response = await fetch(url, { headers: { 'X-APP-CODE': 'synthetic-app-code' } });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.deepEqual(await response.json(), { schemaVersion: 1, status: 'disabled', complete: false, data: null });
});
