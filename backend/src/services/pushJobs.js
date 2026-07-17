import { DateTime } from 'luxon';
import { config } from '../config.js';
import { computeTodayMetrics } from './metrics.js';
import { getRotaEntries } from './rota.js';
import { sendPushToPreference, sendPushToDevice } from './push.js';

const gbp = (v) => `£${Number(v).toFixed(2)}`;

export async function sendDailySummary() {
  const metrics = await computeTodayMetrics();
  const pct = metrics.pct > 0 ? `${Math.round(metrics.pct)}%` : '0%';

  await sendPushToPreference('daily_summary', {
    title: 'Daily Summary',
    body: `Today: ${gbp(metrics.actual_today)} / ${gbp(metrics.target_today)} (${pct})`,
    data: { type: 'daily_summary' }
  });

  return { sent: true };
}

export async function sendRotaReminders() {
  const tomorrow = DateTime.now().setZone(config.timezone).plus({ days: 1 });
  const tomorrowKey = tomorrow.toFormat('yyyy-LL-dd');

  // Store is closed Sundays — no opening reminder.
  if (tomorrow.weekday === 7) {
    return { skipped: 'sunday' };
  }

  const entries = await getRotaEntries(tomorrowKey, tomorrowKey, config.timezone);
  const dayLabel = tomorrow.toFormat('EEEE');

  for (const entry of entries) {
    await sendPushToDevice(entry.name, {
      title: 'Opening Reminder',
      body: `You're opening the store tomorrow (${dayLabel}) at 12`,
      data: { type: 'rota_reminder', date: tomorrowKey }
    });
  }

  return { reminded: entries.length };
}
