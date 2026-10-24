// Shared helpers for the local demo seed: the safety guard, stable ids, the
// calendar and the dev-only password. Nothing here talks to the network.
import { createHash, randomInt } from 'node:crypto';
import { existsSync } from 'node:fs';

/** Hosts a demo seed may write to. Anything else is a real database. */
const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]', '::1']);

/**
 * Refuses to run anywhere but a local development database. Loads
 * `backend/.env` the same way the other dev tools do and never prints it.
 */
export function assertLocalDevelopmentDatabase(): void {
  if (!process.env.DATABASE_URL && existsSync('.env')) {
    process.loadEnvFile('.env');
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error('demo-seed refuses to run when NODE_ENV=production.');
  }
  const raw = process.env.DATABASE_URL;
  if (!raw) {
    throw new Error('demo-seed needs DATABASE_URL (set it or add backend/.env).');
  }
  let host: string;
  try {
    host = new URL(raw).hostname.toLowerCase();
  } catch {
    throw new Error('demo-seed cannot read DATABASE_URL.');
  }
  if (!LOCAL_HOSTS.has(host)) {
    throw new Error(
      'demo-seed refuses to run: DATABASE_URL does not point at localhost or 127.0.0.1.',
    );
  }
}

/** Id for a table whose key is a free-form string (users, plans, tasks, guests...). */
export function demoId(kind: string, key: string): string {
  return `demo_${kind}_${key}`;
}

/**
 * Id for a marketplace table: the API only accepts UUIDs there. Version 5 style,
 * derived from the key, so a re-run always lands on the same row.
 */
export function demoUuid(key: string): string {
  const bytes = createHash('sha1').update(`aarast-demo:${key}`).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32),
  ].join('-');
}

const DAY_MS = 24 * 60 * 60 * 1000;

/** A calendar day (UTC midnight), as the app stores a date without a time. */
export function day(isoDate: string): Date {
  const value = new Date(`${isoDate}T00:00:00.000Z`);
  if (Number.isNaN(value.getTime())) throw new Error(`Bad demo date ${isoDate}`);
  return value;
}

/**
 * "Today" in Sanaa (UTC+3) as a calendar day. `DEMO_SEED_TODAY=2026-10-17`
 * pins it, which reproduces the dates the designs were drawn on.
 */
export function today(): Date {
  const pinned = process.env.DEMO_SEED_TODAY?.trim();
  if (pinned) return day(pinned);
  const sanaaNow = new Date(Date.now() + 3 * 60 * 60 * 1000);
  return new Date(
    Date.UTC(sanaaNow.getUTCFullYear(), sanaaNow.getUTCMonth(), sanaaNow.getUTCDate()),
  );
}

/** The calendar day that many days from today (negative for the past). */
export function inDays(offset: number): Date {
  return new Date(today().getTime() + offset * DAY_MS);
}

/** A moment that many hours before the start of today's morning (for message times). */
export function hoursAgo(hours: number): Date {
  return new Date(today().getTime() + 9 * 60 * 60 * 1000 - hours * 60 * 60 * 1000);
}

/** The password every demo account shares. Chosen per run unless DEMO_PASSWORD is set. */
export function resolveDemoPassword(): { password: string; generated: boolean } {
  const fromEnv = process.env.DEMO_PASSWORD;
  if (fromEnv !== undefined && fromEnv !== '') {
    if (fromEnv.length < 12) {
      throw new Error('DEMO_PASSWORD must have at least 12 characters.');
    }
    return { password: fromEnv, generated: false };
  }
  const alphabet = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let value = '';
  for (let i = 0; i < 14; i += 1) value += alphabet[randomInt(alphabet.length)];
  return { password: `${value}9a`, generated: true };
}

/** Same hash the contribution history uses to refer to an actor. */
export function actorReference(userId: string): string {
  return createHash('sha256').update(userId).digest('hex');
}

/** Normalised form of a guest name, as the guests API stores it. */
export function normalizeGuestName(name: string): string {
  return name.trim().replace(/\s+/g, ' ');
}

/** Normalised form of a budget category name, as the budget API stores it. */
export function normalizeCategoryName(name: string): string {
  return name.trim().replace(/\s+/gu, ' ').toLocaleLowerCase('ar');
}
