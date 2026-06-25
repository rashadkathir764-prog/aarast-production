const RIYADH_OFFSET_MS = 3 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

export function startOfRiyadhDay(now = new Date()): Date {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Riyadh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find((part) => part.type === type)?.value ?? '0');
  return new Date(
    Date.UTC(value('year'), value('month') - 1, value('day')) -
      RIYADH_OFFSET_MS,
  );
}

export function endOfRiyadhDay(start: Date): Date {
  return new Date(start.getTime() + DAY_MS - 1);
}
