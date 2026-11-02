import test from 'node:test';
import assert from 'node:assert/strict';
import { TTLCache } from './utils/cache.js';

const deferred = () => {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
};

test('cold concurrent readers share a producer; warm reads do no work', async () => {
  const cache = new TTLCache();
  let calls = 0;
  const producer = async () => { calls++; return { total: 42 }; };
  const results = await Promise.all(Array.from({ length: 12 }, () => cache.load('today', producer, 1000, 1000)));
  assert.equal(calls, 1);
  assert.ok(results.every((r) => r.payload.total === 42 && !r.stale));
  await cache.load('today', producer, 1000, 1000);
  assert.equal(calls, 1);
});

test('different keys do not share values or failures', async () => {
  const cache = new TTLCache();
  const results = await Promise.allSettled([
    cache.load('seller:a', async () => 1, 1000, 1000),
    cache.load('seller:b', async () => { throw new Error('offline'); }, 1000, 1000)
  ]);
  assert.equal(results[0].value.payload, 1);
  assert.equal(results[1].status, 'rejected');
});

for (const invalidation of ['delete', 'clear']) {
  test(`${invalidation} fences old work and does not erase a newer flight`, async () => {
    const cache = new TTLCache();
    const old = deferred();
    const fresh = deferred();
    const first = cache.load('today', () => old.promise, 1000, 1000);
    cache[invalidation]('today');
    const second = cache.load('today', () => fresh.promise, 1000, 1000);
    old.resolve('old');
    await first;
    assert.equal(cache.get('today'), null);
    const third = cache.load('today', () => assert.fail('new flight was lost'), 1000, 1000);
    fresh.resolve('new');
    assert.equal((await second).payload, 'new');
    assert.equal((await third).payload, 'new');
    assert.equal(cache.get('today'), 'new');
  });
}

test('failure uses bounded stale data, then a later request can recover', async () => {
  const cache = new TTLCache();
  const offline = () => { throw new Error('offline'); };
  cache.set('today', 42, -10);
  assert.deepEqual(await cache.load('today', offline, 1000, 10000), { payload: 42, stale: true });
  assert.deepEqual(await cache.load('today', async () => 43, 1000, 10000), { payload: 43, stale: false });
  cache.set('today', 42, -20000);
  await assert.rejects(cache.load('today', offline, 1000, 10000), /offline/);
  assert.equal((await cache.load('today', async () => 44, 1000, 10000)).payload, 44);
});
