import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, mkdir, writeFile, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DateTime } from 'luxon';

process.env.NODE_ENV = 'test';
const { config } = await import('./config.js');
const { writeJsonFile } = await import('./utils/storage.js');
const { createManualEntry, deleteManualEntry, listManualEntries, dailyManualSalesMap } = await import('./services/manualEntries.js');
const zone = 'Europe/London';

test('manual sales storage and aggregation', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'fitsin-manual-test-'));
  const original = { dataDir: config.dataDir, manualEntriesFile: config.manualEntriesFile };
  config.dataDir = directory;
  config.manualEntriesFile = 'entries.json';
  t.after(async () => { Object.assign(config, original); await rm(directory, { recursive: true, force: true }); });

  await t.test('aggregates every matching entry while keeping the public list bounded', async () => {
    const entries = Array.from({ length: 5001 }, (_, i) => ({ id: String(i), date: '2026-11-02', amount: 0.25 }));
    entries.push({ id: 'before', date: '2026-10-31', amount: 9000 }, { id: 'after', date: '2026-12-01', amount: 9000 });
    await writeJsonFile(config.manualEntriesFile, { entries });
    const map = await dailyManualSalesMap(DateTime.fromISO('2026-11-01', { zone }), DateTime.fromISO('2026-12-01', { zone }), zone);
    assert.deepEqual([...map], [['2026-11-02', 1250.25]]);
    assert.equal((await listManualEntries({ limit: 99999 }, zone)).length, 1000);
  });

  await t.test('parallel confirmed creates all survive', async () => {
    await writeJsonFile(config.manualEntriesFile, { entries: [] });
    const created = await Promise.all(Array.from({ length: 20 }, () => createManualEntry({ amount: 10, source: 'cash', date: '2026-11-02' }, zone)));
    const stored = await listManualEntries({}, zone);
    assert.deepEqual(stored.map((e) => e.id).sort(), created.map((e) => e.id).sort());
  });

  await t.test('parallel delete and create preserve both operations', async () => {
    const [existing] = await listManualEntries({}, zone);
    const before = (await listManualEntries({}, zone)).length;
    const [, added] = await Promise.all([
      deleteManualEntry(existing.id),
      createManualEntry({ amount: 15, source: 'cash', date: '2026-11-02' }, zone)
    ]);
    const stored = await listManualEntries({}, zone);
    assert.equal(stored.length, before);
    assert.ok(!stored.some((e) => e.id === existing.id));
    assert.ok(stored.some((e) => e.id === added.id));
  });

  await t.test('a failed write does not block subsequent writes', async () => {
    await mkdir(join(directory, 'blocked'));
    config.manualEntriesFile = 'blocked';
    await assert.rejects(createManualEntry({ amount: 1, source: 'cash' }, zone));
    config.manualEntriesFile = 'entries.json';
    const added = await createManualEntry({ amount: 1, source: 'cash' }, zone);
    assert.ok((await listManualEntries({}, zone)).some((e) => e.id === added.id));
  });

  await t.test('an unreadable or corrupt store fails without replacing existing data', async () => {
    const file = join(directory, config.manualEntriesFile);
    for (const contents of ['{broken', 'null', '{}', '{"entries":{}}']) {
      await writeFile(file, contents);
      await assert.rejects(createManualEntry({ amount: 1, source: 'cash' }, zone));
      await assert.rejects(deleteManualEntry('existing'));
      await assert.rejects(listManualEntries({}, zone));
      await assert.rejects(dailyManualSalesMap(DateTime.fromISO('2026-11-01', { zone }), DateTime.fromISO('2026-12-01', { zone }), zone));
      assert.equal(await readFile(file, 'utf8'), contents);
    }
    config.manualEntriesFile = 'blocked'; // existing directory, not a missing file
    await assert.rejects(listManualEntries({}, zone), { code: 'EISDIR' });
    config.manualEntriesFile = 'entries.json';
    await writeJsonFile(config.manualEntriesFile, { entries: [] });
    const recovered = await createManualEntry({ amount: 1, source: 'cash' }, zone);
    assert.equal((await listManualEntries({}, zone))[0].id, recovered.id);
  });

  await t.test('a genuinely missing store can still be created', async () => {
    config.manualEntriesFile = 'new.json';
    assert.deepEqual(await listManualEntries({}, zone), []);
    const created = await createManualEntry({ amount: 1, source: 'cash' }, zone);
    assert.equal((await listManualEntries({}, zone))[0].id, created.id);
  });
});
