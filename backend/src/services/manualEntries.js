import crypto from 'node:crypto';
import { DateTime } from 'luxon';
import { config } from '../config.js';
import { readJsonFile, writeJsonFile } from '../utils/storage.js';

const VALID_SOURCES = new Set(['vinted', 'website', 'cash', 'other']);

// Serialise the complete read-modify-write operation in this process. Atomic
// rename alone prevents partial JSON, but cannot prevent lost updates. Multiple
// backend processes still require a transactional shared store.
let pendingMutation = Promise.resolve();
function mutateEntries(operation) {
  const result = pendingMutation.then(operation);
  pendingMutation = result.catch(() => {});
  return result;
}

function round2(v) {
  return Math.round(v * 100) / 100;
}

async function readAll() {
  const parsed = await readJsonFile(config.manualEntriesFile, () => ({ entries: [] }), { strict: true });
  if (!Array.isArray(parsed?.entries)) throw new Error('Invalid manual entries store.');
  return parsed.entries;
}

async function writeAll(entries) {
  await writeJsonFile(config.manualEntriesFile, {
    entries,
    updated_at: new Date().toISOString()
  });
}

function parseDateOrToday(dateStr, timezone) {
  if (!dateStr) return DateTime.now().setZone(timezone).toFormat('yyyy-LL-dd');
  const parsed = DateTime.fromFormat(String(dateStr), 'yyyy-LL-dd', { zone: timezone });
  if (!parsed.isValid) throw new Error('Invalid date. Expected YYYY-MM-DD.');
  return parsed.toFormat('yyyy-LL-dd');
}

export async function createManualEntry(input, timezone) {
  const amount = Number(input?.amount);
  const source = String(input?.source || '').toLowerCase();
  const description = String(input?.description || '').trim();
  const note = String(input?.note || '').trim();

  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error('Amount must be a positive number.');
  }
  if (!VALID_SOURCES.has(source)) {
    throw new Error('Source must be one of: vinted, website, cash, other.');
  }
  if (source === 'other' && !description) {
    throw new Error('Description is required when source is other.');
  }

  const date = parseDateOrToday(input?.date, timezone);

  const entry = {
    id: crypto.randomUUID(),
    date,
    amount: round2(amount),
    source,
    description: description || null,
    note: note || null,
    created_at: new Date().toISOString()
  };

  return mutateEntries(async () => {
    const entries = await readAll();
    entries.push(entry);
    entries.sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
    await writeAll(entries);
    return entry;
  });
}

export async function listManualEntries({ from, to, limit = 200 } = {}, timezone) {
  const entries = await readAll();
  const fromKey = from ? parseDateOrToday(from, timezone) : null;
  const toKey = to ? parseDateOrToday(to, timezone) : null;

  return entries
    .filter((entry) => (!fromKey || entry.date >= fromKey) && (!toKey || entry.date <= toKey))
    .slice(0, Math.max(1, Math.min(Number(limit) || 200, 1000)));
}

export async function deleteManualEntry(entryId) {
  const id = String(entryId || '').trim();
  if (!id) throw new Error('Entry id is required.');

  return mutateEntries(async () => {
    const entries = await readAll();
    const deleted = entries.find((entry) => entry.id === id);
    if (!deleted) {
      throw new Error('Manual entry not found.');
    }

    const next = entries.filter((entry) => entry.id !== id);
    await writeAll(next);
    return deleted;
  });
}

export async function dailyManualSalesMap(startDate, endDateExclusive, timezone) {
  const from = startDate.toFormat('yyyy-LL-dd');
  const to = endDateExclusive.minus({ days: 1 }).toFormat('yyyy-LL-dd');
  // Metrics must cover the entire period, independently of the public list's
  // response-size cap. readAll already materialises this JSON-backed store.
  const entries = await readAll();
  const map = new Map();

  for (const entry of entries) {
    if (entry.date < from || entry.date > to) continue;
    map.set(entry.date, round2((map.get(entry.date) || 0) + Number(entry.amount || 0)));
  }
  return map;
}
