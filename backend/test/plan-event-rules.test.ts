import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  assertEventFacts,
  eventStartMinutes,
  parseEventDay,
  planDayText,
  PlanEventRuleViolation,
  suggestedEventTypes,
} from '../src/modules/planning/domain/plan-event-rules';

// D65: the wedding's events (b12, b13) and the rules every write keeps.

const facts = (extra: Partial<Parameters<typeof assertEventFacts>[0]> = {}) => ({
  type: 'SAMRA' as const,
  title: null,
  date: null,
  timeSlot: null,
  exactTime: null,
  ...extra,
});

function code(run: () => void): string | null {
  try {
    run();
    return null;
  } catch (error) {
    assert.ok(error instanceof PlanEventRuleViolation);
    return error.code;
  }
}

test('suggestions follow the plan party and skip what the plan has', () => {
  assert.deepEqual(suggestedEventTypes('GROOM', ['WEDDING']), [
    'SAMRA', 'MAQEEL', 'AQD', 'LUNCH', 'DINNER', 'CUSTOM',
  ]);
  // b12: السمرة and المقيل added, so the drawn «عقد القران», «الغداء» and
  // «مناسبة ثانية» remain, with «العشاء» of the day's programme (C8).
  assert.deepEqual(suggestedEventTypes('GROOM', ['WEDDING', 'SAMRA', 'MAQEEL']), [
    'AQD', 'LUNCH', 'DINNER', 'CUSTOM',
  ]);
  assert.deepEqual(suggestedEventTypes('BRIDE', ['HAFLA']), [
    'NASHMA', 'AQD', 'LUNCH', 'DINNER', 'CUSTOM',
  ]);
  assert.deepEqual(suggestedEventTypes(null, []).slice(0, 4), [
    'SAMRA', 'MAQEEL', 'HAFLA', 'NASHMA',
  ]);
  // A custom event never removes «مناسبة ثانية».
  const withCustom = suggestedEventTypes('GROOM', ['CUSTOM']);
  assert.equal(withCustom[withCustom.length - 1], 'CUSTOM');
});

test('a custom event needs a name; the main event keeps no day of its own', () => {
  assert.equal(code(() => assertEventFacts(facts({ type: 'CUSTOM', title: '  ' }))), 'EVENT_CUSTOM_TITLE_REQUIRED');
  assert.equal(code(() => assertEventFacts(facts({ type: 'CUSTOM', title: 'الحناء' }))), null);
  assert.equal(
    code(() => assertEventFacts(facts({ type: 'WEDDING', date: new Date('2027-01-21T00:00:00Z') }))),
    'EVENT_WEDDING_DATE_IS_PLAN_DATE',
  );
  assert.equal(code(() => assertEventFacts(facts({ type: 'WEDDING' }))), null);
});

test('«ساعة محددة» carries its hour, and only it does', () => {
  assert.equal(code(() => assertEventFacts(facts({ timeSlot: 'EXACT' }))), 'EVENT_EXACT_TIME_REQUIRED');
  assert.equal(code(() => assertEventFacts(facts({ timeSlot: 'EXACT', exactTime: '25:00' }))), 'EVENT_EXACT_TIME_INVALID');
  assert.equal(code(() => assertEventFacts(facts({ timeSlot: 'EXACT', exactTime: '16:30' }))), null);
  assert.equal(code(() => assertEventFacts(facts({ timeSlot: 'AFTER_ASR', exactTime: '16:30' }))), 'EVENT_EXACT_TIME_REQUIRED');
});

test('days are calendar days; the plan day is read in Sanaa', () => {
  assert.equal(parseEventDay('2027-01-19').toISOString(), '2027-01-19T00:00:00.000Z');
  assert.equal(code(() => parseEventDay('2027-02-30')), 'EVENT_DATE_INVALID');
  assert.equal(code(() => parseEventDay('19/01/2027')), 'EVENT_DATE_INVALID');
  // Stored as the start of the day in Sanaa (21:00 UTC the day before) or
  // as UTC midnight: both are the 21st.
  assert.equal(planDayText(new Date('2027-01-20T21:00:00.000Z')), '2027-01-21');
  assert.equal(planDayText(new Date('2027-01-21T00:00:00.000Z')), '2027-01-21');
});

test('a day orders by its times: الظهر, بعد العصر, بعد المغرب, بعد العشاء (C8)', () => {
  const order = ['AFTER_ISHA', 'DHUHR', 'AFTER_MAGHRIB', 'AFTER_ASR', 'DUHA', 'AFTER_DHUHR'] as const;
  const sorted = [...order].sort((a, b) => eventStartMinutes(a, null) - eventStartMinutes(b, null));
  assert.deepEqual(sorted, ['DUHA', 'DHUHR', 'AFTER_DHUHR', 'AFTER_ASR', 'AFTER_MAGHRIB', 'AFTER_ISHA']);
  assert.equal(eventStartMinutes('EXACT', '16:30'), 16 * 60 + 30);
  // An event without a time comes last in its day.
  assert.ok(eventStartMinutes(null, null) > eventStartMinutes('AFTER_ISHA', null));
});
