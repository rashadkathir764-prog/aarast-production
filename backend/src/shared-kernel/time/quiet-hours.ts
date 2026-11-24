/**
 * RA-BE-185: the hours the phone is left alone. A push made from 21:00 to
 * 09:00 in Aden (Sana'a, UTC+3, no daylight saving: the same offset as the
 * business day) waits for 09:00. The day scans open at 09:00 too.
 */

const ADEN_OFFSET_MS = 3 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

export const QUIET_HOURS_START_HOUR = 21;
export const QUIET_HOURS_END_HOUR = 9;

function adenHour(at: Date): number {
  return new Date(at.getTime() + ADEN_OFFSET_MS).getUTCHours();
}

/** Whether `at` falls from 21:00 up to (not including) 09:00 in Aden. */
export function isQuietHour(at: Date): boolean {
  const hour = adenHour(at);
  return hour >= QUIET_HOURS_START_HOUR || hour < QUIET_HOURS_END_HOUR;
}

/** The first 09:00 in Aden after `at`: this morning's before 09:00, else tomorrow's. */
export function quietHoursEnd(at: Date): Date {
  const local = at.getTime() + ADEN_OFFSET_MS;
  const midnight = local - (((local % DAY_MS) + DAY_MS) % DAY_MS);
  let end = midnight + QUIET_HOURS_END_HOUR * HOUR_MS;
  if (end <= local) end += DAY_MS;
  return new Date(end - ADEN_OFFSET_MS);
}
