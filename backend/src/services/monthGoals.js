import { DateTime } from 'luxon';
import { config } from '../config.js';
import { readJsonFile, writeJsonFile } from '../utils/storage.js';

function isValidMonthKey(month) {
  return /^\d{4}-\d{2}$/.test(month);
}

async function readGoals() {
  const parsed = await readJsonFile(config.shopify.monthGoalsFile, null);
  return parsed?.goals && typeof parsed.goals === 'object' ? parsed.goals : {};
}

async function writeGoals(goals) {
  await writeJsonFile(config.shopify.monthGoalsFile, {
    goals,
    updated_at: new Date().toISOString()
  });
}

export function currentMonthKey(timezone) {
  return DateTime.now().setZone(timezone).toFormat('yyyy-LL');
}

export async function getMonthGoal(month) {
  if (!isValidMonthKey(month)) {
    throw new Error('Invalid month format. Expected YYYY-MM.');
  }
  const goals = await readGoals();
  const value = Number(goals[month]);
  if (!Number.isFinite(value) || value <= 0) return null;
  return value;
}

export async function setMonthGoal(month, goal) {
  if (!isValidMonthKey(month)) {
    throw new Error('Invalid month format. Expected YYYY-MM.');
  }

  const goals = await readGoals();
  if (goal === null) {
    delete goals[month];
  } else {
    const amount = Number(goal);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new Error('Goal must be a positive number.');
    }
    goals[month] = amount;
  }

  await writeGoals(goals);
  return getMonthGoal(month);
}
