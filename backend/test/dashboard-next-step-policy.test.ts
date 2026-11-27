import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  PaymentScheduleStatus,
  Prisma,
  WeddingTaskPriority,
} from '@prisma/client';
import {
  buildImportantItems,
  type NextStepFacts,
} from '../src/dashboard/dashboard-next-steps';

// REFINEMENT_SPEC 2.1 «ترتيب الخطوة التالية»: the server alone orders the
// home's next steps and the phone shows the first. Each rule of the spec has
// its test here; days are counted from `today` as Sana'a days (D11).

const DAY = 86_400_000;
const today = new Date('2026-11-25T21:00:00.000Z'); // 26 Nov in Sana'a
const day = (offset: number) => new Date(today.getTime() + offset * DAY);

function facts(overrides: Partial<NextStepFacts> = {}): NextStepFacts {
  return {
    weddingPlanId: 'plan-1',
    weddingDate: day(120),
    tasks: [],
    nextTask: null,
    missingEssential: null,
    paymentSchedules: [],
    unconfirmedBookings: [],
    today,
    receivedQuotes: 0,
    hasLocation: true,
    hasBudget: true,
    guestCount: 10,
    quoteRequestsCount: 1,
    acceptedProviders: 0,
    canManagePlan: true,
    canManageMoney: true,
    canManageGuests: true,
    canManageProviders: true,
    form: 'MASCULINE',
    planPersona: 'GROOM',
    mahrRecorded: true,
    weddingCostsCount: 2,
    mahrInsideBudget: false,
    undatedOwnerDebt: null,
    loan: null,
    ...overrides,
  };
}

const payment = (id: string, offset: number, amount = '1000') => ({
  id,
  weddingCostId: `cost-${id}`,
  title: `دفعة ${id}`,
  amount: new Prisma.Decimal(amount),
  dueDate: day(offset),
  status: PaymentScheduleStatus.PENDING,
});

const task = (id: string, offset: number) => ({
  id,
  title: `مهمة ${id}`,
  dueDate: day(offset),
  priority: WeddingTaskPriority.MEDIUM,
});

const ids = (items: { id: string }[]) => items.map((item) => item.id);
const types = (items: { type: string }[]) => items.map((item) => item.type);

test('rule 1: a payment due today or late leads, the oldest first, the larger first on the same day', () => {
  const items = buildImportantItems(
    facts({
      tasks: [task('t-today', 0)],
      paymentSchedules: [
        payment('p-today', 0),
        payment('p-late-small', -3, '500'),
        payment('p-late-large', -3, '9000'),
      ],
    }),
  );
  assert.deepEqual(ids(items), ['p-late-large', 'p-late-small', 'p-today']);
});

test('rule 1: a payment step is a payment readers without money rights only read', () => {
  const [manager] = buildImportantItems(
    facts({ paymentSchedules: [payment('p', -1)] }),
  );
  assert.equal(manager.actionLabel, 'سجّل الدفعة');
  assert.equal(
    manager.routeTarget,
    '/wedding-plans/plan-1/money/costs/cost-p/schedules/p/pay',
  );
  const [reader] = buildImportantItems(
    facts({
      paymentSchedules: [payment('p', -1)],
      canManageMoney: false,
      form: 'FEMININE',
    }),
  );
  assert.equal(reader.actionLabel, 'افتحي الدفعة');
  assert.equal(
    reader.routeTarget,
    '/wedding-plans/plan-1/money/costs/cost-p/schedules/p',
  );
});

test('rule 2: an unconfirmed booking comes after due payments and before tasks, only in the wedding\'s last week', () => {
  const booking = {
    quoteRequestId: 'q-photo',
    providerName: 'استوديو الضوء',
    eventDate: day(5),
  };
  const week = buildImportantItems(
    facts({
      weddingDate: day(5),
      unconfirmedBookings: [booking],
      tasks: [task('t-today', 0)],
      paymentSchedules: [payment('p-late', -1)],
    }),
  );
  assert.deepEqual(types(week), [
    'PAYMENT_SCHEDULE_DUE',
    'BOOKING_UNCONFIRMED',
    'TASK_TODAY',
  ]);
  const step = week[1];
  // LANGUAGE §4.2: the reason from the data only.
  assert.equal(step.title, 'لم يؤكد استوديو الضوء الحجز بعد');
  assert.equal(
    step.subtitle,
    'العرس بعد 5 أيام. تواصل معه ليؤكد، أو ابحث عن بديل.',
  );
  assert.equal(step.actionLabel, 'تابع الحجز');
  assert.equal(
    step.routeTarget,
    '/wedding-plans/plan-1/providers/requests?quote=q-photo',
  );
  assert.equal(step.entityId, 'q-photo');

  // Seven days out is still the last week; the wedding day itself too.
  for (const offset of [7, 0]) {
    assert.deepEqual(
      types(
        buildImportantItems(
          facts({ weddingDate: day(offset), unconfirmedBookings: [booking] }),
        ),
      ),
      ['BOOKING_UNCONFIRMED'],
    );
  }
  // Eight days out, or with no wedding day, it is no step yet.
  for (const weddingDate of [day(8), null]) {
    assert.equal(
      buildImportantItems(
        facts({ weddingDate, unconfirmedBookings: [booking] }),
      ).some((item) => item.type === 'BOOKING_UNCONFIRMED'),
      false,
    );
  }
  // Following a booking up is the providers' manager's step.
  assert.deepEqual(
    buildImportantItems(
      facts({
        weddingDate: day(5),
        unconfirmedBookings: [booking],
        canManageProviders: false,
      }),
    ),
    [],
  );
});

test('rules 3 and 8: today\'s task, then a task late by up to seven days, the nearest first; one later than that is never a step', () => {
  const items = buildImportantItems(
    facts({
      tasks: [task('t-8-late', -8), task('t-7-late', -7), task('t-1-late', -1), task('t-today', 0)],
    }),
  );
  assert.deepEqual(ids(items), ['t-today', 't-1-late', 't-7-late']);
  assert.deepEqual(types(items), ['TASK_TODAY', 'TASK_OVERDUE', 'TASK_OVERDUE']);
  assert.equal(items[2].subtitle, 'متأخرة منذ 7 أيام');

  // Alone, the task late by eight days still asks nothing.
  assert.deepEqual(buildImportantItems(facts({ tasks: [task('t-8-late', -8)] })), []);
});

test('rules 3 to 5: tasks, then a payment due within the week, then offers that arrived', () => {
  const items = buildImportantItems(
    facts({
      receivedQuotes: 2,
      paymentSchedules: [payment('p-in-3', 3), payment('p-in-8', 8)],
      tasks: [task('t-late', -2)],
    }),
  );
  assert.deepEqual(types(items), [
    'TASK_OVERDUE',
    'PAYMENT_SCHEDULE_DUE',
    'QUOTE_RECEIVED',
  ]);
  // A payment eight days away is not yet a step before the wedding.
  assert.equal(items[1].id, 'p-in-3');
  assert.equal(items[1].subtitle, 'دفعة تستحق بعد 3 أيام');
});

test('rule 4: payments within the week go by their day', () => {
  const items = buildImportantItems(
    facts({
      paymentSchedules: [payment('p-in-6', 6), payment('p-in-1', 1), payment('p-in-7', 7)],
    }),
  );
  assert.deepEqual(ids(items), ['p-in-1', 'p-in-6', 'p-in-7']);
});

test('rule 6: the setup chain only while the wedding is more than thirty days away or has no day', () => {
  const missing = {
    hasLocation: false,
    hasBudget: false,
  } satisfies Partial<NextStepFacts>;
  assert.deepEqual(
    types(buildImportantItems(facts({ ...missing, weddingDate: day(31) }))),
    ['SET_LOCATION', 'SET_BUDGET'],
  );
  assert.deepEqual(
    buildImportantItems(facts({ ...missing, weddingDate: day(30) })),
    [],
  );
  // The chain's own order: date, place, budget, mahr, first agreement,
  // guests, first quote.
  const chain = facts({
    weddingDate: null,
    hasLocation: false,
    hasBudget: false,
    mahrRecorded: false,
    weddingCostsCount: 0,
    guestCount: 0,
    quoteRequestsCount: 0,
  });
  assert.deepEqual(types(buildImportantItems(chain)), [
    'SET_DATE',
    'SET_LOCATION',
    'SET_BUDGET',
  ]);
  assert.deepEqual(
    types(
      buildImportantItems({
        ...chain,
        weddingDate: day(60),
        hasLocation: true,
        hasBudget: true,
      }),
    ),
    ['RECORD_MAHR', 'ADD_FIRST_COST', 'ADD_GUESTS'],
  );
  assert.deepEqual(
    types(
      buildImportantItems({
        ...chain,
        weddingDate: day(60),
        hasLocation: true,
        hasBudget: true,
        mahrRecorded: true,
        weddingCostsCount: 1,
      }),
    ),
    ['ADD_GUESTS', 'REQUEST_QUOTE'],
  );
});

test('rule 6: SET_DATE names the step and is asked only of a reader who may change the plan', () => {
  const [step] = buildImportantItems(
    facts({ weddingDate: null, form: 'FEMININE' }),
  );
  assert.equal(step.type, 'SET_DATE');
  assert.equal(step.title, 'حددي موعد العرس');
  assert.equal(step.actionLabel, 'حددي الموعد');
  assert.equal(step.routeTarget, '/wedding-plans/plan-1/plan-center');
  assert.equal(step.id, 'set_date:plan-1');
  assert.deepEqual(
    buildImportantItems(facts({ weddingDate: null, canManagePlan: false })),
    [],
  );
});

test('rules 5 to 7: offers before the setup chain, the chain before the upcoming task and the open essential', () => {
  assert.deepEqual(
    types(
      buildImportantItems(
        facts({
          receivedQuotes: 1,
          hasBudget: false,
          nextTask: task('t-next', 4),
          missingEssential: { key: 'VENUE', budgetCategoryId: 'cat-venue' },
        }),
      ),
    ),
    ['QUOTE_RECEIVED', 'SET_BUDGET', 'TASK_UPCOMING'],
  );
  // Within thirty days the chain is silent: the upcoming task, then the
  // essential still open.
  assert.deepEqual(
    types(
      buildImportantItems(
        facts({
          weddingDate: day(20),
          hasBudget: false,
          nextTask: task('t-next', 4),
          missingEssential: { key: 'VENUE', budgetCategoryId: 'cat-venue' },
        }),
      ),
    ),
    ['TASK_UPCOMING', 'ESSENTIAL_MISSING'],
  );
  // The upcoming task is one after today, never a late one.
  assert.deepEqual(
    buildImportantItems(facts({ nextTask: task('t-late', -20) })),
    [],
  );
});

test('after the wedding: due payments, the nearest one to come, the debt with no day, a loan, then the providers to rate', () => {
  const after = facts({
    weddingDate: day(-10),
    acceptedProviders: 2,
    providersToRate: 2,
    undatedOwnerDebt: '250000.00',
    loan: { outstanding: '300000.00', fundingSourceId: 'src-1', nextDueDate: day(15) },
    paymentSchedules: [payment('p-in-40', 40), payment('p-in-12', 12)],
  });
  assert.deepEqual(types(buildImportantItems(after)), [
    'PAYMENT_SCHEDULE_DUE',
    'DEBT_UNDATED',
    'LOAN_OUTSTANDING',
  ]);
  assert.equal(buildImportantItems(after)[0].id, 'p-in-12');

  assert.deepEqual(
    ids(
      buildImportantItems({
        ...after,
        paymentSchedules: [
          payment('p-in-12', 12),
          payment('p-late', -2),
          payment('p-today', 0),
        ],
      }),
    ),
    ['p-late', 'p-today', 'p-in-12'],
  );

  const withoutPayments = buildImportantItems({ ...after, paymentSchedules: [] });
  assert.deepEqual(types(withoutPayments), [
    'DEBT_UNDATED',
    'LOAN_OUTSTANDING',
    'RATE_PROVIDERS',
  ]);
  const [debt, loan, rate] = withoutPayments;
  assert.equal(debt.amount, '250000.00');
  assert.equal(debt.routeTarget, '/wedding-plans/plan-1/money');
  assert.equal(debt.actionLabel, 'رتّب الدفع');
  assert.equal(loan.amount, '300000.00');
  assert.equal(loan.subtitle, 'أقرب سداد بعد 15 يومًا');
  assert.equal(loan.routeTarget, '/wedding-plans/plan-1/money/funding?source=src-1');
  assert.equal(rate.routeTarget, '/wedding-plans/plan-1/providers/reviews');

  // Nothing of before the wedding is asked after it.
  assert.deepEqual(
    buildImportantItems(
      facts({
        weddingDate: day(-1),
        tasks: [task('t-today', 0)],
        receivedQuotes: 3,
        hasLocation: false,
        guestCount: 0,
      }),
    ),
    [],
  );
});

test('after the wedding: nothing owed and no provider asks nothing; amounts of zero are no step', () => {
  assert.deepEqual(
    buildImportantItems(
      facts({
        weddingDate: day(-3),
        undatedOwnerDebt: '0.00',
        loan: { outstanding: '0.00', fundingSourceId: null, nextDueDate: null },
      }),
    ),
    [],
  );
});

test('after the wedding: actions follow the reader\'s rights', () => {
  const reader = buildImportantItems(
    facts({
      weddingDate: day(-3),
      canManageMoney: false,
      canManageProviders: false,
      acceptedProviders: 2,
      undatedOwnerDebt: '100.00',
      form: 'FEMININE',
    }),
  );
  // No «قيّمي» for a reader with no provider she may rate (she sent no
  // request, or rated them all), however many providers the plan holds.
  assert.deepEqual(types(reader), ['DEBT_UNDATED']);
  assert.equal(reader[0].actionLabel, 'اعرضي المال');
  assert.equal(reader[0].subtitle, 'من اتفاقات لم تُحدد لها دفعات.');

  // The step follows what can be rated, not the plan's providers: the
  // reader who sent the request rates, whatever her other rights.
  const rater = buildImportantItems(
    facts({
      weddingDate: day(-3),
      canManageProviders: false,
      acceptedProviders: 0,
      providersToRate: 1,
      form: 'FEMININE',
    }),
  );
  assert.deepEqual(types(rater), ['RATE_PROVIDERS']);
  assert.deepEqual(
    types(
      buildImportantItems(
        facts({ weddingDate: day(-3), acceptedProviders: 3, providersToRate: 0 }),
      ),
    ),
    [],
    'every provider rated, or none bookable: nothing is asked',
  );

  const [loan] = buildImportantItems(
    facts({
      weddingDate: day(-3),
      loan: { outstanding: '50.00', fundingSourceId: null, nextDueDate: null },
    }),
  );
  assert.equal(loan.subtitle, 'حدد متى ستسددها.');
  assert.equal(loan.routeTarget, '/wedding-plans/plan-1/money/funding');
});

test('ties: on the same day a payment comes before a task, and the cap is three', () => {
  const items = buildImportantItems(
    facts({
      tasks: [task('t-today', 0), task('t-late', -1)],
      paymentSchedules: [payment('p-today', 0), payment('p-late', -1)],
      receivedQuotes: 1,
    }),
  );
  assert.deepEqual(ids(items), ['p-late', 'p-today', 't-today']);
});
