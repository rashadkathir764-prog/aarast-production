// Arabic dates and durations as the admin designs write them: Latin digits,
// Sana'a days («18 أكتوبر», «اليوم 10:02», «أمس»), and counted units with
// the Arabic dual («يومين», «ساعتين», «3 أيام»).

const MONTHS = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

const TIME_ZONE = 'Asia/Aden';

type DayParts = { year: number; month: number; day: number; hour: number; minute: number };

function partsOf(value: Date): DayParts {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: TIME_ZONE,
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    hourCycle: 'h23',
  }).formatToParts(value);
  const read = (type: string) => Number(parts.find((part) => part.type === type)?.value ?? 0);
  return { year: read('year'), month: read('month'), day: read('day'), hour: read('hour'), minute: read('minute') };
}

function dayNumber(parts: DayParts) {
  return Date.UTC(parts.year, parts.month - 1, parts.day) / 86_400_000;
}

/** «18 أكتوبر», with the year only when it is not this year. */
export function dayMonth(value: string | Date, now: Date = new Date()): string {
  const date = partsOf(new Date(value));
  const today = partsOf(now);
  const base = `${date.day} ${MONTHS[date.month - 1]}`;
  return date.year === today.year ? base : `${base} ${date.year}`;
}

/** «مارس» (or «مارس 2025» outside this year). */
export function monthName(value: string | Date, now: Date = new Date()): string {
  const date = partsOf(new Date(value));
  const today = partsOf(now);
  const base = MONTHS[date.month - 1];
  return date.year === today.year ? base : `${base} ${date.year}`;
}

/** «10:02» in Sana'a time. */
export function clock(value: string | Date): string {
  const date = partsOf(new Date(value));
  return `${date.hour}:${String(date.minute).padStart(2, '0')}`;
}

/** «اليوم 10:02», «أمس», or «18 أكتوبر». */
export function whenShort(value: string | Date, now: Date = new Date()): string {
  const date = partsOf(new Date(value));
  const days = dayNumber(partsOf(now)) - dayNumber(date);
  if (days === 0) return `اليوم ${clock(value)}`;
  if (days === 1) return 'أمس';
  return dayMonth(value, now);
}

/** Audit style: «10:41» today, «أمس», then «18 أكتوبر». */
export function whenClock(value: string | Date, now: Date = new Date()): string {
  const date = partsOf(new Date(value));
  const days = dayNumber(partsOf(now)) - dayNumber(date);
  if (days === 0) return clock(value);
  if (days === 1) return 'أمس';
  return dayMonth(value, now);
}

type Unit = 'minute' | 'hour' | 'day';

const UNIT_WORDS: Record<Unit, { one: string; two: string; few: string; many: string }> = {
  minute: { one: 'دقيقة', two: 'دقيقتين', few: 'دقايق', many: 'دقيقة' },
  hour: { one: 'ساعة', two: 'ساعتين', few: 'ساعات', many: 'ساعة' },
  day: { one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم' },
};

/** «يوم», «يومين», «3 أيام», «11 يوم». */
export function countUnit(count: number, unit: Unit): string {
  const words = UNIT_WORDS[unit];
  if (count === 1) return words.one;
  if (count === 2) return words.two;
  if (count >= 3 && count <= 10) return `${count} ${words.few}`;
  return `${count} ${words.many}`;
}

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

/** A span rounded down to its largest unit: «5 ساعات», «يومين», «40 دقيقة». */
export function spanWords(ms: number): string {
  const span = Math.max(ms, 0);
  if (span >= DAY) return countUnit(Math.floor(span / DAY), 'day');
  if (span >= HOUR) return countUnit(Math.floor(span / HOUR), 'hour');
  return countUnit(Math.max(1, Math.floor(span / MINUTE)), 'minute');
}

/** «قبل 40 دقيقة». */
export function agoWords(value: string | Date, now: Date = new Date()): string {
  return `قبل ${spanWords(now.getTime() - new Date(value).getTime())}`;
}

export type Deadline = { label: string; late: boolean; overdue: boolean; remainingMs: number };

/**
 * Time left on a promise: «باقي يوم», or «تعدّى بيوم» once it passed. It is
 * late (drawn in coral) once overdue or within its last hour.
 */
export function deadline(start: string | Date, promiseMs: number, now: Date = new Date()): Deadline {
  const remainingMs = new Date(start).getTime() + promiseMs - now.getTime();
  if (remainingMs <= 0) {
    const words = spanWords(-remainingMs);
    const by = /^\d/.test(words) ? 'بـ' : 'ب';
    return { label: `تعدّى ${by}${words}`, late: true, overdue: true, remainingMs };
  }
  return { label: `باقي ${spanWords(remainingMs)}`, late: remainingMs <= HOUR, overdue: false, remainingMs };
}

export const PROMISE = { HOUR, DAY } as const;
