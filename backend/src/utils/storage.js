import { promises as fs } from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { config } from '../config.js';

// Resolve a data file to the persistent data directory (a mounted disk in
// production) so state survives redeploys. Falls back to cwd for local dev.
export function dataPath(fileName) {
  const base = config.dataDir || process.cwd();
  return path.resolve(base, fileName);
}

export async function readJsonFile(fileName, fallback) {
  try {
    const raw = await fs.readFile(dataPath(fileName), 'utf8');
    return JSON.parse(raw);
  } catch {
    return typeof fallback === 'function' ? fallback() : fallback;
  }
}

// Write via a temp file + rename so a crash mid-write can't corrupt the store.
export async function writeJsonFile(fileName, value) {
  const target = dataPath(fileName);
  await fs.mkdir(path.dirname(target), { recursive: true });
  const tmp = `${target}.${crypto.randomBytes(6).toString('hex')}.tmp`;
  await fs.writeFile(tmp, JSON.stringify(value, null, 2), 'utf8');
  await fs.rename(tmp, target);
}
