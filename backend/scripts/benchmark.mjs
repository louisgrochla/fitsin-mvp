// Runs the actual Express endpoints in isolated subprocesses, with synthetic upstreams.
import { fork } from 'node:child_process';
import { once } from 'node:events';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';
import assert from 'node:assert/strict';

const root = new URL('../', import.meta.url);
const samples = Number(process.env.SAMPLES || 5);
const result = { node: process.version, samples, upstreamDelayMs: 2, concurrentClients: 8, sizes: [] };
const quantile = (xs, q) => [...xs].sort((a, b) => a - b)[Math.ceil(xs.length * q) - 1];
for (const size of [461, 1400, 5000]) {
  const times = [];
  const counts = [];
  let warmMs, warmCalls, stale, recovered, payloadBytes;
  for (let sample = 0; sample < samples; sample += 1) {
    const directory = await mkdtemp(join(tmpdir(), 'fitsin-benchmark-'));
    const child = fork(fileURLToPath(new URL('src/server.js', root)), [], {
      cwd: directory,
      execArgv: ['--import', fileURLToPath(new URL('scripts/fixtures/upstream.mjs', root))],
      env: {
        PATH: process.env.PATH, NODE_ENV: 'test', PORT: '31987', TZ: 'Europe/London',
        DATA_DIR: directory, APP_SHARED_CODE: 'synthetic-test-code',
        SHOPIFY_STORE_DOMAIN: 'synthetic.invalid', SHOPIFY_ADMIN_TOKEN: 'synthetic-token',
        CACHE_TTL_SECONDS: '1', FIXTURE_SIZE: String(size)
      },
      stdio: ['ignore', 'pipe', 'pipe', 'ipc']
    });
    const control = async (command) => {
      const message = once(child, 'message');
      child.send(command);
      return (await message)[0].calls;
    };
    const get = async (path) => {
      const response = await fetch(`http://127.0.0.1:31987${path}`, {
        headers: { 'X-APP-CODE': 'synthetic-test-code' }, signal: AbortSignal.timeout(20000)
      });
      assert.equal(response.status, 200);
      return response.json();
    };
    try {
      await new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('server startup timeout')), 5000);
        child.once('exit', () => { clearTimeout(timer); reject(new Error('server exited')); });
        child.stdout.on('data', (data) => {
          if (String(data).includes('backend listening')) { clearTimeout(timer); resolve(); }
        });
      });
      const begin = performance.now();
      const payloads = await Promise.all(Array.from({ length: 8 }, (_, i) => get(i % 2 ? '/v1/month' : '/v1/today')));
      times.push(performance.now() - begin);
      counts.push(await control('count'));
      assert.equal(payloads[0].actual_today, Math.floor(size / 2) * 10);
      assert.equal(payloads[1].mtd_actual, size * 10);
      payloadBytes = Buffer.byteLength(JSON.stringify(payloads[1]));
      const warmStart = performance.now();
      await get('/v1/today');
      warmMs = performance.now() - warmStart;
      warmCalls = (await control('count')) - counts.at(-1);
      if (sample === 0) {
        await delay(1100);
        await control('fail');
        const stalePayload = await get('/v1/today');
        stale = stalePayload.data_delayed && stalePayload.actual_today === payloads[0].actual_today;
        assert.equal(stale, true);
        await control('recover');
        recovered = !(await get('/v1/today')).data_delayed;
        assert.equal(recovered, true);
      }
    } finally {
      const exited = once(child, 'exit');
      child.kill();
      await exited;
      await rm(directory, { recursive: true, force: true });
    }
  }
  result.sizes.push({ size, coldMedianMs: quantile(times, .5), coldP95Ms: quantile(times, .95), coldUpstreamCalls: counts,
    warmMs, warmCalls, monthPayloadBytes: payloadBytes, staleFallback: stale, recovered });
}
console.log(JSON.stringify(result, null, 2));
