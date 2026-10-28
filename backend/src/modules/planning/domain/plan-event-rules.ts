/**
 * D65: the wedding's events (b12, b13) and the rules every write keeps.
 * Pure: no Nest, no Prisma at run time. The phone owns the labels
 * («السمرة», «المقيل», …); the server keeps the kind and the facts.
 */

export const PLAN_EVENT_TYPES = [
  'WEDDING',
  'SAMRA',
  'MAQEEL',
  'HAFLA',
  'NASHMA',
  'AQD',
  'LUNCH',
  'DINNER',
  'CUSTOM',
] as const;
export type PlanEventKind = (typeof PLAN_EVENT_TYPES)[number];

export const PLAN_EVENT_TIME_SLOTS = [
  'DUHA',
  'DHUHR',
  'AFTER_DHUHR',
  'AFTER_ASR',
  'AFTER_MAGHRIB',
  'AFTER_ISHA',
  'EXACT',
] as const;
export type PlanEventSlot = (typeof PLAN_EVENT_TIME_SLOTS)[number];

export const PLAN_EVENT_TITLE_MAX = 60;
export const PLAN_EVENT_PLACE_MAX = 120;
export const PLAN_EVENT_PERSON_MAX = 60;
export const PLAN_EVENT_NOTE_MAX = 120;

/** A plan holds at most this many events (a wedding has a handful). */
export const PLAN_EVENTS_MAX = 30;

export type PlanEventRuleCode =
  | 'EVENT_TYPE_EXISTS'
  | 'EVENT_CUSTOM_TITLE_REQUIRED'
  | 'EVENT_WEDDING_DATE_IS_PLAN_DATE'
  | 'EVENT_IS_MAIN'
  | 'EVENT_EXACT_TIME_REQUIRED'
  | 'EVENT_EXACT_TIME_INVALID'
  | 'EVENT_DATE_INVALID'
  | 'EVENT_LIMIT_REACHED';

export class PlanEventRuleViolation extends Error {
  constructor(
    readonly code: PlanEventRuleCode,
    message: string,
  ) {
    super(message);
  }
}

/** The plan's party, which decides the customary nights (JOURNEY_PROFILE). */
export type PlanEventParty = 'GROOM' | 'BRIDE' | 'HELPER' | null;

/**
 * b12's «اقتراحات»: the customary kinds the plan has not added yet, in the
 * order they come in the week, then «مناسبة ثانية». The groom's nights are
 * السمرة and المقيل; the bride's الحفلة and النسمة (JOURNEY_PROFILE); a
 * helper's plan offers both sets. «العشاء» joins the drawn «عقد القران» and
 * «الغداء» because the day's programme ends with it (C8).
 */
export function suggestedEventTypes(
  party: PlanEventParty,
  existing: readonly PlanEventKind[],
): PlanEventKind[] {
  const nights: PlanEventKind[] =
    party === 'GROOM'
      ? ['SAMRA', 'MAQEEL']
      : party === 'BRIDE'
        ? ['HAFLA', 'NASHMA']
        : ['SAMRA', 'MAQEEL', 'HAFLA', 'NASHMA'];
  const taken = new Set(existing);
  return [
    ...[...nights, 'AQD', 'LUNCH', 'DINNER'].filter(
      (type) => !taken.has(type as PlanEventKind),
    ),
    'CUSTOM',
  ] as PlanEventKind[];
}

const SLOT_ORDER: Record<PlanEventSlot, number> = {
  DUHA: 9 * 60,
  DHUHR: 12 * 60,
  AFTER_DHUHR: 13 * 60,
  AFTER_ASR: 15 * 60 + 30,
  AFTER_MAGHRIB: 18 * 60,
  AFTER_ISHA: 19 * 60 + 30,
  EXACT: 0,
};

/** Minutes into the day an event starts by, for ordering one day's events. */
export function eventStartMinutes(
  slot: PlanEventSlot | null,
  exactTime: string | null,
): number {
  if (slot === 'EXACT' && exactTime) {
    const [hours, minutes] = exactTime.split(':').map(Number);
    return hours * 60 + minutes;
  }
  return slot ? SLOT_ORDER[slot] : 24 * 60;
}

/** «2027-01-21» from a `YYYY-MM-DD` text; anything else breaks the rule. */
export function parseEventDay(value: string): Date {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new PlanEventRuleViolation('EVENT_DATE_INVALID', 'The day must be YYYY-MM-DD');
  }
  const day = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(day.getTime()) || day.toISOString().slice(0, 10) !== value) {
    throw new PlanEventRuleViolation('EVENT_DATE_INVALID', 'The day does not exist');
  }
  return day;
}

/** The calendar day of a stored `@db.Date` (UTC midnight). */
export function eventDayText(day: Date): string {
  return day.toISOString().slice(0, 10);
}

/**
 * The plan's wedding day as Sana'a reads it (UTC+3). The plan keeps it as
 * the start of that day in Sana'a or as UTC midnight; both land on it.
 */
export function planDayText(weddingDate: Date): string {
  return new Date(weddingDate.getTime() + 3 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}

export interface PlanEventFacts {
  type: PlanEventKind;
  title: string | null;
  date: Date | null;
  timeSlot: PlanEventSlot | null;
  exactTime: string | null;
}

/**
 * What every stored event keeps: a CUSTOM one has a name, the main event
 * keeps no day of its own (it is the plan's wedding date, changed through
 * «أجّل العرس»), and «ساعة محددة» carries its hour and only then.
 */
export function assertEventFacts(facts: PlanEventFacts): void {
  if (facts.type === 'CUSTOM' && !(facts.title ?? '').trim()) {
    throw new PlanEventRuleViolation(
      'EVENT_CUSTOM_TITLE_REQUIRED',
      'A custom event needs its name',
    );
  }
  if (facts.type === 'WEDDING' && facts.date !== null) {
    throw new PlanEventRuleViolation(
      'EVENT_WEDDING_DATE_IS_PLAN_DATE',
      "The main event's day is the plan's wedding date",
    );
  }
  if (facts.timeSlot === 'EXACT') {
    if (!facts.exactTime) {
      throw new PlanEventRuleViolation(
        'EVENT_EXACT_TIME_REQUIRED',
        'An exact time needs its hour',
      );
    }
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(facts.exactTime)) {
      throw new PlanEventRuleViolation(
        'EVENT_EXACT_TIME_INVALID',
        'The hour must be HH:mm',
      );
    }
  } else if (facts.exactTime !== null) {
    throw new PlanEventRuleViolation(
      'EVENT_EXACT_TIME_REQUIRED',
      'An hour is kept only with «ساعة محددة»',
    );
  }
}

/** Trims a free text; an empty one is no value. */
export function cleanEventText(value: string | null | undefined): string | null {
  const text = value?.trim() ?? '';
  return text.length === 0 ? null : text;
}
