import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { fetchWithRetry, withUpstreamDeadline } from './utils/http.js';

async function fixture(t, handler) {
  const server = createServer(handler);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  return `http://127.0.0.1:${server.address().port}`;
}

test('GET retries transient 5xx and stops at its cap', async (t) => {
  let calls = 0;
  const url = await fixture(t, (_req, res) => { calls++; res.writeHead(503).end(); });
  assert.equal((await fetchWithRetry(url, {}, 1)).status, 503);
  assert.equal(calls, 2);
});

test('POST/PATCH do not retry unless a read is explicitly declared safe', async (t) => {
  let calls = 0;
  const url = await fixture(t, (_req, res) => { calls++; res.writeHead(503).end(); });
  await fetchWithRetry(url, { method: 'POST' });
  await fetchWithRetry(url, { method: 'PATCH' });
  assert.equal(calls, 2);
  await fetchWithRetry(url, { method: 'POST', retrySafe: true }, 1);
  assert.equal(calls, 4);
});

test('unauthorized responses are not retried', async (t) => {
  let calls = 0;
  const url = await fixture(t, (_req, res) => { calls++; res.writeHead(401).end(); });
  assert.equal((await fetchWithRetry(url)).status, 401);
  assert.equal(calls, 1);
});

test('deadline aborts a stalled body and clears retry backoff', async (t) => {
  const url = await fixture(t, (_req, res) => { res.writeHead(200); res.write('{'); });
  await assert.rejects(withUpstreamDeadline(async () => (await fetchWithRetry(url)).json(), 80));
  let calls = 0;
  const failing = await fixture(t, (_req, res) => { calls++; res.writeHead(503).end(); });
  await assert.rejects(withUpstreamDeadline(() => fetchWithRetry(failing), 80));
  assert.equal(calls, 1);
});

test('parallel and sequential pages share one end-to-end budget', async (t) => {
  let calls = 0;
  const signals = [];
  // Start the parallel pages deterministically. Real socket/body cancellation
  // is covered above; a 60ms scheduling window made this case flaky under load.
  t.mock.method(globalThis, 'fetch', async (_url, { signal }) => {
    calls++;
    signals.push(signal);
    if (calls === 1) return new Response('{}');
    return new Promise((_resolve, reject) => {
      signal.addEventListener('abort', () => reject(signal.reason), { once: true });
    });
  });
  const url = 'https://synthetic.invalid';
  await assert.rejects(withUpstreamDeadline(async () => {
    await (await fetchWithRetry(url)).json();
    await Promise.all([fetchWithRetry(url), fetchWithRetry(url)]);
  }, 80));
  assert.equal(calls, 3);
  assert.ok(signals.every((signal) => signal.aborted));
});

test('caller cancellation is preserved', async (t) => {
  let calls = 0;
  const url = await fixture(t, (_req, res) => { calls++; res.end('{}'); });
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(fetchWithRetry(url, { signal: controller.signal }));
  assert.equal(calls, 0);
});
