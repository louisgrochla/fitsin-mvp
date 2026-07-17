import crypto from 'node:crypto';
import { DateTime } from 'luxon';
import { config } from '../config.js';
import { readJsonFile, writeJsonFile } from '../utils/storage.js';

async function readStore() {
  const parsed = await readJsonFile(config.rotaFile, null);
  return {
    entries: Array.isArray(parsed?.entries) ? parsed.entries : [],
    schedules: Array.isArray(parsed?.schedules) ? parsed.schedules : []
  };
}

async function writeStore(store) {
  await writeJsonFile(config.rotaFile, {
    entries: store.entries,
    schedules: store.schedules,
    updated_at: new Date().toISOString()
  });
}

function parseDate(dateStr, timezone) {
  if (!dateStr) throw new Error('Date is required. Expected YYYY-MM-DD.');
  const parsed = DateTime.fromFormat(String(dateStr), 'yyyy-LL-dd', { zone: timezone });
  if (!parsed.isValid) throw new Error('Invalid date. Expected YYYY-MM-DD.');
  return parsed.toFormat('yyyy-LL-dd');
}

// Day-of-week: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat (ISO weekday)
const VALID_DAYS = new Set([1, 2, 3, 4, 5, 6]);

function generateScheduledEntries(schedules, fromDate, toDate, existingEntries) {
  const generated = [];
  const from = DateTime.fromFormat(fromDate, 'yyyy-LL-dd');
  const to = DateTime.fromFormat(toDate, 'yyyy-LL-dd');

  for (const schedule of schedules) {
    let cursor = from;
    while (cursor <= to) {
      const isoWeekday = cursor.weekday; // 1=Mon ... 7=Sun
      if (schedule.days.includes(isoWeekday)) {
        const dateKey = cursor.toFormat('yyyy-LL-dd');
        const alreadyExists = existingEntries.some(
          (e) => e.date === dateKey && e.name.toLowerCase() === schedule.name.toLowerCase()
        ) || generated.some(
          (e) => e.date === dateKey && e.name.toLowerCase() === schedule.name.toLowerCase()
        );
        if (!alreadyExists) {
          generated.push({
            id: `sched-${schedule.id}-${dateKey}`,
            date: dateKey,
            name: schedule.name,
            created_at: schedule.created_at,
            recurring: true
          });
        }
      }
      cursor = cursor.plus({ days: 1 });
    }
  }
  return generated;
}

export async function getRotaEntries(fromDate, toDate, timezone) {
  const from = fromDate ? parseDate(fromDate, timezone) : null;
  const to = toDate ? parseDate(toDate, timezone) : null;
  const store = await readStore();

  const manual = store.entries.filter(
    (e) => (!from || e.date >= from) && (!to || e.date <= to)
  );

  if (from && to) {
    const scheduled = generateScheduledEntries(store.schedules, from, to, manual);
    return [...manual, ...scheduled].sort(
      (a, b) => a.date.localeCompare(b.date) || a.name.localeCompare(b.name)
    );
  }

  return manual;
}

export async function addRotaEntry(input, timezone) {
  const date = parseDate(input?.date, timezone);
  const name = String(input?.name || '').trim();

  if (!name) throw new Error('Name is required.');

  const store = await readStore();

  // Check against both manual entries and would-be scheduled entries
  const duplicate = store.entries.find(
    (e) => e.date === date && e.name.toLowerCase() === name.toLowerCase()
  );
  if (duplicate) throw new Error('Already signed up for this day.');

  const entry = {
    id: crypto.randomUUID(),
    date,
    name,
    created_at: new Date().toISOString()
  };

  store.entries.push(entry);
  store.entries.sort((a, b) => a.date.localeCompare(b.date) || a.created_at.localeCompare(b.created_at));
  await writeStore(store);
  return entry;
}

export async function removeRotaEntry(entryId) {
  const id = String(entryId || '').trim();
  if (!id) throw new Error('Entry id is required.');

  const store = await readStore();
  const deleted = store.entries.find((e) => e.id === id);
  if (!deleted) throw new Error('Rota entry not found.');

  store.entries = store.entries.filter((e) => e.id !== id);
  await writeStore(store);
  return deleted;
}

// MARK: - Schedules

export async function getSchedules() {
  const store = await readStore();
  return store.schedules;
}

export async function setSchedule(input) {
  const name = String(input?.name || '').trim();
  const days = input?.days;

  if (!name) throw new Error('Name is required.');
  if (!Array.isArray(days)) throw new Error('Days must be an array of weekday numbers (1=Mon to 6=Sat).');

  const validDays = days.filter((d) => VALID_DAYS.has(Number(d))).map(Number);

  const store = await readStore();

  // Remove existing schedule for this person
  store.schedules = store.schedules.filter(
    (s) => s.name.toLowerCase() !== name.toLowerCase()
  );

  // Only add if there are days selected
  if (validDays.length > 0) {
    store.schedules.push({
      id: crypto.randomUUID(),
      name,
      days: validDays.sort(),
      created_at: new Date().toISOString()
    });
  }

  await writeStore(store);
  return store.schedules;
}

export async function getScheduleForUser(name) {
  const store = await readStore();
  const schedule = store.schedules.find(
    (s) => s.name.toLowerCase() === String(name || '').trim().toLowerCase()
  );
  return schedule || null;
}
