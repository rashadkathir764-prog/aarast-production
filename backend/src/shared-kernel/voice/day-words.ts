/**
 * How the app writes a day in Arabic (B-38), the one place the server words
 * a date: «30 أكتوبر», «الجمعة 30 أكتوبر», «غدًا», «بعد 5 أيام». The phone
 * writes days the same way (`arabic_date_formatter.dart`); a notice never
 * carries a numeric or ISO date.
 *
 * A day is read in Sana'a (UTC+3, no daylight saving, the same offset as the
 * business day): a `@db.Date` value (UTC midnight) and a timestamp at the
 * local midnight both land on their own calendar day.
 */

import { countedWords } from './count-words';

const LOCAL_OFFSET_MS = 3 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

const MONTHS = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
] as const;

// Indexed by `getUTCDay()`: Sunday first.
const WEEKDAYS = [
  'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
] as const;

/** A calendar day: an instant (read in Sana'a) or a `YYYY-MM-DD` day. */
export type CalendarDay = Date | string;

function localMidnight(day: CalendarDay): Date {
  if (typeof day === 'string') {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) {
      throw new Error(`Not a calendar day: ${day}`);
    }
    return new Date(`${day}T00:00:00.000Z`);
  }
  const local = new Date(day.getTime() + LOCAL_OFFSET_MS);
  return new Date(
    Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()),
  );
}

/** «30 أكتوبر». */
export function dayMonthWords(day: CalendarDay): string {
  const date = localMidnight(day);
  return `${date.getUTCDate()} ${MONTHS[date.getUTCMonth()]}`;
}

/** «الجمعة 30 أكتوبر», the way the journey names a day. */
export function weekdayDayMonthWords(day: CalendarDay): string {
  const date = localMidnight(day);
  return `${WEEKDAYS[date.getUTCDay()]} ${dayMonthWords(date.toISOString().slice(0, 10))}`;
}

/** Whole calendar days from `today` to `day` (negative once it passed). */
export function daysBetween(today: CalendarDay, day: CalendarDay): number {
  return Math.round(
    (localMidnight(day).getTime() - localMidnight(today).getTime()) / DAY_MS,
  );
}

/**
 * «يوم واحد», «يومين», «5 أيام», «11 يومًا», «100 يوم», «103 أيام» (D129:
 * the count's own rule, `countedWords`; «يومين» is the form these lines use,
 * after «بعد» and «منذ»).
 */
export function dayCountWords(days: number): string {
  return countedWords(days, {
    one: 'يوم واحد',
    two: 'يومين',
    few: 'أيام',
    many: 'يومًا',
    other: 'يوم',
  });
}

/** When a day `days` away is: «اليوم», «غدًا», «بعد يومين», «بعد 5 أيام». */
export function whenWords(days: number): string {
  if (days <= 0) return 'اليوم';
  if (days === 1) return 'غدًا';
  return `بعد ${dayCountWords(days)}`;
}

/**
 * `whenWords` for a reminder, where a week away is «بعد أسبوع» (the day a
 * reminder is sent a week ahead): «اليوم», «غدًا», «بعد أسبوع», «بعد 5 أيام».
 */
export function reminderWhenWords(days: number): string {
  return days === 7 ? 'بعد أسبوع' : whenWords(days);
}
