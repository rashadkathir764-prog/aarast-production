import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  BookingStatus,
  FundingSourceKind,
  FundingSourceStatus,
  Prisma,
  SharedMemberRole,
  WeddingPlanStatus,
} from '@prisma/client';
import { bookingToday } from '../src/marketplace/booking-policy';
import { dashboardService } from './support/owner-ports';

// REFINEMENT_SPEC 2.1 and 2.4 through the dashboard summary itself: the
// bookings it reads for «حجز لم يؤكَّد», and the «محجوز» a reader who may
// not see the money receives.

const DAY = 86_400_000;

type Fixture = {
  weddingInDays: number;
  reader: 'OWNER' | 'PARTNER';
  canViewMoney: boolean;
  canManageProviders?: boolean;
  /** The money picture's agreements (no dates) and the owner's loans. */
  money?: {
    costs: Array<{ id: string; budgetCategoryId: string; totalAmount: string }>;
    loans: Array<{ id: string; amount: string }>;
  };
  /**
   * The providers a confirmed booking of the reader's own requests served
   * (its day passed), and the ones of them the reader already rated.
   */
  served?: string[];
  rated?: string[];
};

async function summaryOf(fixture: Fixture) {
  const plan = {
    id: 'plan-1',
    ownerUserId: 'owner-1',
    title: 'Plan',
    weddingDate: new Date(Date.now() + fixture.weddingInDays * DAY),
    city: 'صنعاء',
    location: null,
    estimatedBudget: new Prisma.Decimal('5000000'),
    currency: 'YER',
    status: WeddingPlanStatus.PLANNING,
    persona: 'GROOM',
    importMigrationId: null,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
  };
  const pictureCosts = (fixture.money?.costs ?? []).map((cost) => ({
    ...cost,
    totalAmount: new Prisma.Decimal(cost.totalAmount),
    title: 'القاعة',
    payer: null,
    payerName: null,
  }));
  const fundingSources = (fixture.money?.loans ?? []).map((loan) => ({
    id: loan.id,
    kind: FundingSourceKind.LOAN,
    status: FundingSourceStatus.RECEIVED,
    amount: new Prisma.Decimal(loan.amount),
    weddingPlanId: plan.id,
    sourceName: 'سلفة من خالي',
    expectedAt: null,
    repayments: [],
  }));
  const bookingCalls: Array<{ where: Record<string, unknown> }> = [];
  const costCalls: Array<{ where?: Record<string, unknown> }> = [];
  const emptyModel = new Proxy(
    {},
    {
      get: (_target, property) => async () =>
        property === 'count'
          ? 0
          : property === 'findFirst' || property === 'findUnique'
            ? null
            : [],
    },
  );
  const tables: Record<string, unknown> = {
    booking: {
      findMany: async (args: { where: Record<string, unknown> }) => {
        bookingCalls.push(args);
        // «قيّم المزوّدين»: the confirmed bookings whose day has passed.
        if ((args.where.eventDate as { lt?: Date } | undefined)?.lt) {
          return (fixture.served ?? []).map((providerId) => ({ providerId }));
        }
        if (args.where.status === BookingStatus.CONFIRMED) {
          return [
            {
              quoteRequestId: 'q-hall',
              quoteOfferId: 'o-hall',
              provider: { primaryCategoryId: null },
            },
          ];
        }
        return [
          {
            quoteRequestId: 'q-photo',
            eventDate: new Date(plan.weddingDate),
            provider: { businessName: 'استوديو الضوء' },
          },
        ];
      },
    },
    weddingCost: {
      findMany: async (args: { where?: Record<string, unknown> }) => {
        costCalls.push(args);
        const where = args?.where ?? {};
        // The hall's booked offer was filed under the hall's money item.
        if ((where.quoteOfferId as { in?: string[] } | undefined)?.in) {
          return [
            {
              id: 'c-hall',
              quoteOfferId: 'o-hall',
              budgetCategoryId: 'item-hall',
              totalAmount: new Prisma.Decimal(800000),
              paidAmount: new Prisma.Decimal(0),
              status: 'ACTIVE',
              payments: [],
            },
          ];
        }
        // The band was agreed with a party outside اعّرست.
        if ('partyName' in where) {
          return [{ budgetCategoryId: 'item-band', partyName: 'فرقة الأفراح' }];
        }
        // Only the money picture's read selects the amounts.
        return (args as { select?: { totalAmount?: boolean } })?.select
          ?.totalAmount
          ? pictureCosts
          : [];
      },
      count: async () => 0,
      findFirst: async () => null,
    },
    budgetCategory: {
      findMany: async () =>
        (fixture.money?.costs ?? []).map((cost) => ({
          id: cost.budgetCategoryId,
          name: 'القاعة',
          kind: 'WEDDING',
          weddingPlanId: plan.id,
          allocatedAmount: null,
          suggestion: null,
          suggestionUntil: null,
          createdAt: plan.createdAt,
        })),
    },
    fundingSource: { findMany: async () => fundingSources },
    providerReview: {
      findMany: async () =>
        (fixture.rated ?? []).map((providerId) => ({ providerId })),
    },
  };
  const tx = new Proxy(tables, {
    get: (target, property: string) => target[property] ?? emptyModel,
  });
  const prisma = new Proxy(
    {
      $transaction: async (operation: (client: unknown) => Promise<unknown>) =>
        operation(tx),
    } as Record<string, unknown>,
    { get: (target, property: string) => target[property] ?? emptyModel },
  );
  const partner = fixture.reader === 'PARTNER';
  const service = dashboardService(
    prisma,
    {
      assertPlanReadableInTransaction: async () => ({
        plan,
        isOwner: !partner,
        sharedMember: partner
          ? { id: 'member-1', role: SharedMemberRole.BRIDE, authorityVersion: 1 }
          : null,
      }),
      canViewMoney: () => fixture.canViewMoney,
      canManageMoney: () => fixture.canViewMoney,
      canManageTasks: () => true,
      canManageGuests: () => true,
      canManageProviders: () => fixture.canManageProviders ?? true,
      canManageMembers: () => true,
      canManagePlan: () => true,
    },
    { visibilityWhereForUser: async () => null },
    undefined,
    { summary: async () => null },
  );
  const summary = await service.getWeddingPlanDashboardSummary(
    { id: partner ? 'partner-1' : 'owner-1' } as never,
    plan.id,
  );
  return { summary, bookingCalls, costCalls };
}

const unconfirmedReads = (calls: Array<{ where: Record<string, unknown> }>) =>
  calls.filter((call) => call.where.status === BookingStatus.REQUESTED);

test('2.1 (2): in the wedding\'s last week an unconfirmed booking is the next step', async () => {
  const { summary, bookingCalls } = await summaryOf({
    weddingInDays: 5,
    reader: 'OWNER',
    canViewMoney: true,
  });
  const [first] = summary.importantItems;
  assert.equal(first.type, 'BOOKING_UNCONFIRMED');
  assert.equal(first.title, 'لم يؤكد استوديو الضوء الحجز بعد');
  assert.equal(
    first.routeTarget,
    '/wedding-plans/plan-1/providers/requests?quote=q-photo',
  );
  // Read for this plan, only open requests whose day has not passed.
  const [read] = unconfirmedReads(bookingCalls);
  assert.deepEqual(read.where.quoteRequest, { weddingPlanId: 'plan-1' });
  // From Yemen's today on: a request whose day passed is over (RA-MO-263).
  // `instanceof Date` alone held for any date at all.
  const from = (read.where.eventDate as { gte: Date }).gte;
  const todayInYemen = bookingToday(new Date());
  assert.ok(
    Math.abs(from.getTime() - todayInYemen.getTime()) <= DAY,
    `the read starts at Yemen's today, got ${from.toISOString()}`,
  );
  assert.equal(from.getUTCHours(), 0, 'a calendar day, not an instant');
});

test('2.1 (2): before the last week, or for a reader who does not follow the providers, no unconfirmed booking is read', async () => {
  const early = await summaryOf({
    weddingInDays: 20,
    reader: 'OWNER',
    canViewMoney: true,
  });
  assert.equal(unconfirmedReads(early.bookingCalls).length, 0);
  assert.equal(
    early.summary.importantItems.some(
      (item) => item.type === 'BOOKING_UNCONFIRMED',
    ),
    false,
  );
  const viewer = await summaryOf({
    weddingInDays: 5,
    reader: 'PARTNER',
    canViewMoney: true,
    canManageProviders: false,
  });
  assert.equal(unconfirmedReads(viewer.bookingCalls).length, 0);
});

test('2.1 after the wedding: the owner\'s debt with no day, then his loan, from finance\'s one money read', async () => {
  const { summary } = await summaryOf({
    weddingInDays: -10,
    reader: 'OWNER',
    canViewMoney: true,
    money: {
      costs: [{ id: 'c-hall', budgetCategoryId: 'item-hall', totalAmount: '800000' }],
      loans: [{ id: 'loan-1', amount: '300000' }],
    },
  });
  assert.deepEqual(
    summary.importantItems.map((item) => item.type),
    ['DEBT_UNDATED', 'LOAN_OUTSTANDING'],
  );
  const [debt, loan] = summary.importantItems;
  assert.ok(new Prisma.Decimal(debt.amount ?? '0').equals(800000));
  assert.ok(new Prisma.Decimal(loan.amount ?? '0').equals(300000));
  // No repayment planned: the funding page, and the reason to plan one.
  assert.equal(loan.routeTarget, '/wedding-plans/plan-1/money/funding');
  assert.equal(loan.subtitle, 'حدد متى ستسددها.');
});

test('2.1 after the wedding: a partner sees the owner\'s debt but never the owner\'s loan', async () => {
  const { summary } = await summaryOf({
    weddingInDays: -10,
    reader: 'PARTNER',
    canViewMoney: true,
    money: {
      costs: [{ id: 'c-hall', budgetCategoryId: 'item-hall', totalAmount: '800000' }],
      loans: [{ id: 'loan-1', amount: '300000' }],
    },
  });
  assert.deepEqual(
    summary.importantItems.map((item) => item.type),
    ['DEBT_UNDATED'],
  );
});

// «قيّم المزوّدين» was asked of every reader whose plan held a provider: of
// one whose booking was never confirmed (the server then refused the
// review), and for ever after every review was written.
test('2.1 after the wedding: «قيّم المزوّدين» only while the reader has a provider to rate', async () => {
  const types = async (fixture: Partial<Fixture>) =>
    (
      await summaryOf({
        weddingInDays: -10,
        reader: 'OWNER',
        canViewMoney: false,
        ...fixture,
      })
    ).summary.importantItems.map((item) => item.type);

  assert.deepEqual(await types({}), [], 'no booking served: nothing to rate');
  assert.deepEqual(await types({ served: ['hall', 'photo'], rated: ['hall'] }), [
    'RATE_PROVIDERS',
  ]);
  assert.deepEqual(
    await types({ served: ['hall', 'photo'], rated: ['hall', 'photo'] }),
    [],
    'every provider rated: the step is gone',
  );

  // The read is the reader's own requests of this plan, their day passed.
  const { bookingCalls } = await summaryOf({
    weddingInDays: -10,
    reader: 'PARTNER',
    canViewMoney: false,
    served: ['hall'],
  });
  const read = bookingCalls.find(
    (call) => (call.where.eventDate as { lt?: Date } | undefined)?.lt,
  );
  assert.deepEqual(read?.where.quoteRequest, {
    weddingPlanId: 'plan-1',
    userId: 'partner-1',
  });

  // Before the wedding nothing is read: no booking's day has passed.
  const before = await summaryOf({
    weddingInDays: 30,
    reader: 'OWNER',
    canViewMoney: false,
    served: ['hall'],
  });
  assert.equal(
    before.bookingCalls.some(
      (call) => (call.where.eventDate as { lt?: Date } | undefined)?.lt,
    ),
    false,
  );
});

test('2.4: a reader who sees the money reads «محجوز» with its agreements', async () => {
  const { summary } = await summaryOf({
    weddingInDays: 60,
    reader: 'OWNER',
    canViewMoney: true,
  });
  assert.deepEqual(summary.bookedServices, {
    count: 2,
    budgetCategoryIds: ['item-band', 'item-hall'],
    quoteRequestIds: [],
  });
});

test('2.4: a reader who may not see the money reads «محجوز» from the confirmed bookings alone', async () => {
  const { summary, costCalls } = await summaryOf({
    weddingInDays: 60,
    reader: 'PARTNER',
    canViewMoney: false,
  });
  // No money item an agreement booked, and no item a booking's cost was
  // filed under: each confirmed booking counts once by its request.
  assert.deepEqual(summary.bookedServices, {
    count: 1,
    budgetCategoryIds: [],
    quoteRequestIds: ['q-hall'],
  });
  // No agreement is read for him at all.
  assert.equal(
    costCalls.some((call) => {
      const where = call?.where ?? {};
      return 'partyName' in where || 'quoteOfferId' in where;
    }),
    false,
  );
});
