import { DateTime } from 'luxon';
import { config } from '../config.js';
import { sendDailySummary, sendRotaReminders } from './pushJobs.js';

// Fixed local (Europe/London) trigger times, in "HH:mm".
const DAILY_SUMMARY_AT = '18:00';
const ROTA_REMINDER_AT = '19:00';

// Remembers the yyyy-LL-dd on which each job last fired so a job runs at most
// once per day even though the tick fires every minute.
const lastRun = new Map();

async function runOnce(jobKey, fn) {
  const today = DateTime.now().setZone(config.timezone).toFormat('yyyy-LL-dd');
  if (lastRun.get(jobKey) === today) return;
  lastRun.set(jobKey, today);
  try {
    await fn();
  } catch (error) {
    // Un-set so a transient failure can retry on the next tick.
    lastRun.delete(jobKey);
    console.error(`[scheduler] ${jobKey} failed:`, error.message);
  }
}

async function tick() {
  const now = DateTime.now().setZone(config.timezone);
  const hhmm = now.toFormat('HH:mm');

  if (hhmm === DAILY_SUMMARY_AT) {
    await runOnce('daily_summary', sendDailySummary);
  }
  if (hhmm === ROTA_REMINDER_AT) {
    await runOnce('rota_reminder', sendRotaReminders);
  }
}

let timer = null;

export function startScheduler() {
  if (timer) return;
  // Tick every minute; luxon handles DST for the local-time comparison.
  timer = setInterval(() => {
    tick().catch((e) => console.error('[scheduler] tick error:', e.message));
  }, 60 * 1000);
  if (timer.unref) timer.unref();
  console.log(
    `[scheduler] started — daily summary ${DAILY_SUMMARY_AT}, rota reminder ${ROTA_REMINDER_AT} (${config.timezone})`
  );
}

export function stopScheduler() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}
