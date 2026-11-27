import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  BookingStatus,
  GuestAttendanceStatus,
  NotificationPriority,
  PaymentScheduleStatus,
  PlanProviderLinkStatus,
  Prisma,
  ProviderStatus,
  QuoteRequestStatus,
  WeddingCostStatus,
  WeddingTaskStatus,
} from '@prisma/client';
import { PermissionService } from '../src/modules/collaboration/internal/permission.service';
import { FinancePortService } from '../src/modules/finance/infrastructure/finance-port.service';
import { GuestsPortService } from '../src/modules/guests/infrastructure/guests-port.service';
import { ProviderReadService } from '../src/modules/marketplace/infrastructure/provider-read.service';
import { QuoteReadService } from '../src/modules/marketplace/infrastructure/quote-read.service';
import { PlanReadService } from '../src/modules/planning/infrastructure/plan-read.service';
import { TasksPortService } from '../src/modules/tasks/infrastructure/tasks-port.service';
import { notificationsService, catalogWithoutMoneyLinks } from './support/owner-ports';

// The dashboard and timeline (insights owns no tables) used to count and
// list the plans, tasks, guests, costs, schedules, quotes, provider links,
// members, invitations and notifications themselves. Each owner now serves
// those reads on the caller's client with the statement insights ran; a
// contributor's scope narrows by the ids collaboration's history qualified.

function recorder(results: Record<string, unknown> = {}) {
  const calls: Array<[string, unknown]> = [];
  const handler = (table: string): ProxyHandler<object> => ({
    get: (_target, method: string) => async (args: unknown) => {
      calls.push([`${table}.${method}`, args]);
      const key = `${table}.${method}`;
      if (key in results) return results[key];
      return method === 'count' ? 0 : method.startsWith('findMany') ? [] : null;
    },
  });
  const client = new Proxy({}, {
    get: (_target, table: string) => new Proxy({}, handler(table)),
  }) as unknown as Prisma.TransactionClient;
  return { client, calls };
}

const open = { notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED] };
const byDue = [{ dueDate: 'asc' }, { createdAt: 'asc' }];

test('finance serves a plan\'s money picture and pending schedules, narrowed to a contributor\'s costs', async () => {
  const { client, calls } = recorder();
  const finance = new FinancePortService(catalogWithoutMoneyLinks);
  const query = {
    weddingPlanId: 'plan-1',
    persona: 'GROOM',
    totalBudget: null,
    readerUserId: 'reader-1',
    fundingVisible: false,
  };
  await finance.readMoneyPicture(client, { ...query, scope: null });
  await finance.readMoneyPicture(client, {
    ...query,
    scope: { costIds: ['cost-1'], categoryIds: ['category-1'] },
  });
  const pictureCalls = calls.splice(0);
  await finance.listPendingPaymentSchedules(client, 'plan-1', null);
  await finance.listPendingPaymentSchedules(client, 'plan-1', ['cost-1']);
  const costWhere = (ids?: string[]) => ({
    weddingPlanId: 'plan-1',
    ...(ids ? { id: { in: ids } } : {}),
    status: { not: WeddingCostStatus.CANCELLED },
  });
  // D59: one read of finance's own rows; the costs and items narrow to a
  // contributor's, another account's private costs are found to be left
  // out, and the owner's funding is read only when it may be shown.
  const costReads = pictureCalls.filter(
    ([name, args]) =>
      name === 'weddingCost.findMany' &&
      !(args as { where: Record<string, unknown> }).where.privateToUserId,
  );
  assert.deepEqual(
    costReads.map(([, args]) => (args as { where: unknown }).where),
    [costWhere(), costWhere(['cost-1'])],
  );
  assert.deepEqual(
    pictureCalls
      .filter(([name]) => name === 'budgetCategory.findMany')
      .map(([, args]) => (args as { where: unknown }).where),
    [{ weddingPlanId: 'plan-1' }, { weddingPlanId: 'plan-1', id: { in: ['category-1'] } }],
  );
  assert.equal(
    pictureCalls.filter(
      ([name, args]) =>
        name === 'weddingCost.findMany' &&
        JSON.stringify((args as { where: unknown }).where).includes('reader-1'),
    ).length,
    2,
  );
  assert.equal(pictureCalls.some(([name]) => name.startsWith('fundingSource.')), false);
  // RA-BE-53: a pending schedule leaves finance asking for what its cost still
  // owes, so the read takes the cost's total and paid with its title.
  const scheduleInclude = {
    weddingCost: { select: { title: true, totalAmount: true, paidAmount: true } },
  };
  // A total order: two dates of one day made together read the same way
  // every time.
  const byDueThenId = [...byDue, { id: 'asc' }];
  assert.deepEqual(calls, [
    ['paymentSchedule.findMany', {
      where: { status: PaymentScheduleStatus.PENDING, weddingCost: costWhere() },
      include: scheduleInclude,
      orderBy: byDueThenId,
    }],
    ['paymentSchedule.findMany', {
      where: { status: PaymentScheduleStatus.PENDING, weddingCost: costWhere(['cost-1']) },
      include: scheduleInclude,
      orderBy: byDueThenId,
    }],
  ]);
});

// The home named two payments of 300 thousand where the money tab named
// one: each pending date took the agreement's whole rest on its own.
test('finance: the pending dates of one agreement share what it still owes', async () => {
  const decimal = (value: string) => new Prisma.Decimal(value);
  const hall = { title: 'القاعة', totalAmount: decimal('1000000'), paidAmount: decimal('700000') };
  const photo = { title: 'التصوير', totalAmount: decimal('400000'), paidAmount: decimal('0') };
  const schedule = (id: string, weddingCostId: string, amount: string, weddingCost: typeof hall) => ({
    id,
    weddingCostId,
    amount: decimal(amount),
    dueDate: new Date('2026-12-01T00:00:00.000Z'),
    weddingCost,
  });
  const { client } = recorder({
    // In the read's own order: the earliest date first.
    'paymentSchedule.findMany': [
      schedule('hall-1', 'cost-hall', '500000', hall),
      schedule('photo-1', 'cost-photo', '250000', photo),
      schedule('hall-2', 'cost-hall', '500000', hall),
    ],
  });
  const pending = await new FinancePortService(catalogWithoutMoneyLinks)
    .listPendingPaymentSchedules(client, 'plan-1', null);
  // 300 thousand is left on the hall: its first date asks for it, and the
  // second, left with nothing, is no payment to make.
  assert.deepEqual(
    pending.map((item) => [item.id, item.amount.toString(), item.weddingCost.title]),
    [
      ['hall-1', '300000', 'القاعة'],
      ['photo-1', '250000', 'التصوير'],
    ],
  );
});

test('tasks serves the upcoming tasks, the plan dashboard counters and the dated open tasks in the reader\'s scope', async () => {
  const { client, calls } = recorder({ 'weddingTask.count': 3 });
  const tasks = new TasksPortService();
  const today = new Date('2026-09-23T00:00:00.000Z');
  const endOfToday = new Date('2026-09-23T23:59:59.999Z');
  await tasks.listUpcomingTasks(client, 'plan-1', 5, 'owner-1');
  const lateFrom = new Date('2026-09-16T00:00:00.000Z');
  const dashboard = await tasks.getPlanTaskDashboard(client, {
    weddingPlanId: 'plan-1',
    scope: { kind: 'contributor', assigneeUserId: 'user-1', taskIds: ['task-1'] },
    today,
    endOfToday,
    lateFrom,
  });
  assert.equal(dashboard.totalTasks, 3);
  await tasks.listDatedOpenTasks(client, 'plan-1', { kind: 'none' });
  await tasks.listDatedOpenTasks(client, 'plan-1', { kind: 'all', readerUserId: 'owner-1' });

  // V1 checklist 4.10: every read the reader can see narrows out the tasks
  // private to another account.
  const visibleTo = (userId: string) => ({
    OR: [{ privateToUserId: null }, { privateToUserId: userId }],
  });
  const scoped = {
    weddingPlanId: 'plan-1',
    AND: [
      visibleTo('user-1'),
      { OR: [{ assigneeUserId: 'user-1' }, { id: { in: ['task-1'] } }] },
    ],
  };
  assert.deepEqual(calls, [
    ['weddingTask.findMany', { where: { weddingPlanId: 'plan-1', status: open, ...visibleTo('owner-1') }, orderBy: byDue, take: 5 }],
    // REFINEMENT_SPEC 2.1: the home acts on today's tasks, then the ones
    // late by up to seven days, the nearest first (it read the two oldest),
    // and its «المهمة القادمة» is the nearest one after today.
    // Both end on the id: tasks made together share their second, and the
    // first step must not change from one read to the next.
    ['weddingTask.findMany', { where: { ...scoped, dueDate: { gte: lateFrom, lte: endOfToday }, status: open }, orderBy: [{ dueDate: 'desc' }, { createdAt: 'asc' }, { id: 'asc' }], take: 3 }],
    ['weddingTask.findFirst', { where: { ...scoped, dueDate: { gt: endOfToday }, status: open }, orderBy: [...byDue, { id: 'asc' }] }],
    ['weddingTask.findFirst', { where: { ...scoped, status: open }, orderBy: byDue }],
    // RA-BE-93: a cancelled task is not one of the plan's tasks in the total.
    ['weddingTask.count', { where: { ...scoped, status: { not: WeddingTaskStatus.CANCELLED } } }],
    ['weddingTask.count', { where: { ...scoped, status: WeddingTaskStatus.DONE } }],
    ['weddingTask.count', { where: { ...scoped, status: { in: [WeddingTaskStatus.TODO, WeddingTaskStatus.IN_PROGRESS] } } }],
    ['weddingTask.count', { where: { ...scoped, dueDate: { lt: today }, status: open } }],
    ['weddingTask.count', { where: { ...scoped, dueDate: { gte: today, lte: endOfToday }, status: open } }],
    ['weddingTask.findMany', { where: { weddingPlanId: 'plan-1', dueDate: { not: null }, status: open, id: { in: [] } }, orderBy: byDue }],
    ['weddingTask.findMany', { where: { weddingPlanId: 'plan-1', dueDate: { not: null }, status: open, ...visibleTo('owner-1') }, orderBy: byDue }],
  ]);
});

test('guests serves the plan dashboard counters, narrowed to a contributor\'s guests', async () => {
  const { client, calls } = recorder({ 'guest.count': 2 });
  const counters = await new GuestsPortService().getPlanGuestCounters(client, 'plan-1', ['guest-1']);
  assert.deepEqual(counters, { total: 2, confirmed: 2, pending: 2, declined: 2, incomplete: 2 });
  const base = { weddingPlanId: 'plan-1', id: { in: ['guest-1'] } };
  assert.deepEqual(calls, [
    ['guest.count', { where: base }],
    // RA-BE-94: the home counts the guest's reply (`attendanceStatus`), the
    // column the guest list, its summary and the reply page read.
    ['guest.count', { where: { ...base, attendanceStatus: GuestAttendanceStatus.CONFIRMED } }],
    ['guest.count', { where: { ...base, attendanceStatus: GuestAttendanceStatus.PENDING } }],
    ['guest.count', { where: { ...base, attendanceStatus: GuestAttendanceStatus.DECLINED } }],
    ['guest.count', { where: { ...base, OR: [{ phone: null }, { phone: '' }, { name: '' }] } }],
  ]);
});

// «قيّم المزوّدين» was asked of every reader whose plan held a provider:
// the count is of what `createReview` would accept (F10) and has not been
// written yet.
test('marketplace counts the providers the reader may rate and has not rated', async () => {
  const now = new Date('2026-10-25T09:00:00.000Z');
  const { client, calls } = recorder({
    'booking.findMany': [{ providerId: 'hall' }, { providerId: 'photo' }],
    'providerReview.findMany': [{ providerId: 'hall' }],
  });
  const providers = new ProviderReadService();
  assert.equal(
    await providers.countPlanProvidersToRate(client, 'plan-1', 'user-1', now),
    1,
  );
  const [[bookingQuery, bookingArgs], [reviewQuery, reviewArgs]] = calls as Array<
    [string, { where: Record<string, unknown>; distinct: string[] }]
  >;
  assert.equal(bookingQuery, 'booking.findMany');
  assert.equal(bookingArgs.where.status, BookingStatus.CONFIRMED);
  // A day before Yemen's today (`bookingToday`): the booking's day passed.
  assert.deepEqual(bookingArgs.where.eventDate, {
    lt: new Date('2026-10-25T00:00:00.000Z'),
  });
  // On a request the reader sent, for this plan.
  assert.deepEqual(bookingArgs.where.quoteRequest, {
    weddingPlanId: 'plan-1',
    userId: 'user-1',
  });
  assert.deepEqual(bookingArgs.distinct, ['providerId']);
  assert.equal(reviewQuery, 'providerReview.findMany');
  assert.deepEqual(reviewArgs.where, {
    userId: 'user-1',
    providerId: { in: ['hall', 'photo'] },
  });

  // Nothing served: no review is read, and nothing is asked.
  const none = recorder();
  assert.equal(
    await providers.countPlanProvidersToRate(none.client, 'plan-1', 'user-1', now),
    0,
  );
  assert.equal(none.calls.length, 1);
});

test('marketplace serves the home counters, the active plan provider links and the plan quote counters', async () => {
  const { client, calls } = recorder();
  const providers = new ProviderReadService();
  const quotes = new QuoteReadService();
  const now = new Date('2026-10-25T09:00:00.000Z');
  await providers.countFeaturedActiveProviders(client, now);
  await providers.countUserFavorites(client, 'user-1');
  await providers.countActivePlanProviderLinks(client, 'plan-1');
  await providers.listActivePlanProviderLinks(client, 'plan-1', ['quote-1'], 3);
  await quotes.countUserQuoteRequests(client, 'user-1');
  await quotes.getPlanQuoteCounters(client, 'plan-1', null);

  const links = (ids?: string[]) => ({
    weddingPlanId: 'plan-1',
    ...(ids ? { quoteRequestId: { in: ids } } : {}),
    status: PlanProviderLinkStatus.ACTIVE,
    provider: { status: ProviderStatus.ACTIVE },
  });
  const planQuotes = { weddingPlanId: 'plan-1' };
  assert.deepEqual(calls, [
    // B-43: the home counter counts by the placement rule, as the list ranks:
    // listed (active, with an active service), claimed, and a period now.
    ['provider.count', {
      where: {
        AND: [
          { status: ProviderStatus.ACTIVE },
          { services: { some: { isActive: true } } },
          // RA-BE-26: a provider whose owner is leaving is not listed.
          { ownerLeavingAt: null },
          { userId: { not: null } },
          { featuredPeriods: { some: { startsAt: { lte: now }, endsAt: { gt: now }, endedAt: null } } },
        ],
      },
    }],
    ['favoriteProvider.count', { where: { userId: 'user-1' } }],
    ['planProviderLink.count', { where: links() }],
    ['planProviderLink.findMany', {
      where: links(['quote-1']),
      include: {
        provider: {
          include: {
            services: {
              where: { isActive: true },
              orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
              take: 1,
              select: {
                id: true,
                title: true,
                images: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }], take: 1, select: { imageUrl: true } },
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 3,
    }],
    ['quoteRequest.count', { where: { userId: 'user-1' } }],
    ['quoteRequest.count', { where: planQuotes }],
    ['quoteRequest.count', { where: { ...planQuotes, status: { in: [QuoteRequestStatus.SENT, QuoteRequestStatus.VIEWED] } } }],
    ['quoteRequest.count', { where: { ...planQuotes, status: QuoteRequestStatus.RESPONDED } }],
    ['quoteRequest.count', { where: { ...planQuotes, status: QuoteRequestStatus.ACCEPTED } }],
    // B-04: a request that ended without an answer is closed too.
    ['quoteRequest.count', { where: { ...planQuotes, status: { in: [QuoteRequestStatus.REJECTED, QuoteRequestStatus.CANCELLED, QuoteRequestStatus.EXPIRED] } } }],
  ]);
});

test('collaboration counts a plan\'s members and live invitations in the reader\'s scope', async () => {
  const { client, calls } = recorder();
  const permissions = new PermissionService({} as any, new PlanReadService());
  const now = new Date('2026-09-23T10:00:00.000Z');
  await permissions.countPlanMembers(client, 'plan-1');
  await permissions.countPlanMembers(client, 'plan-1', { userId: 'user-1', memberIds: ['member-2'] });
  await permissions.countLivePlanInvites(client, 'plan-1', now, ['invite-1']);
  assert.deepEqual(calls, [
    ['sharedMember.count', { where: { weddingPlanId: 'plan-1' } }],
    ['sharedMember.count', { where: { weddingPlanId: 'plan-1', OR: [{ userId: 'user-1' }, { id: { in: ['member-2'] } }] } }],
    ['planInvite.count', {
      where: {
        weddingPlanId: 'plan-1',
        id: { in: ['invite-1'] },
        acceptedAt: null,
        declinedAt: null,
        revokedAt: null,
        expiresAt: { gt: now },
      },
    }],
  ]);
});

test('notifications serves the plan dashboard preview under the reader\'s visibility', async () => {
  const where: unknown[] = [];
  const client = {
    provider: { findUnique: async () => null },
    weddingPlan: { findMany: async () => [] },
    sharedMember: { findMany: async () => [] },
    notification: {
      count: async (args: { where: unknown }) => { where.push(args); return 1; },
      findMany: async (args: { where: unknown }) => { where.push(args); return [{ id: 'n-1' }]; },
      findFirst: async (args: { where: unknown }) => { where.push(args); return { id: 'n-1' }; },
    },
  };
  const service = notificationsService(client as any, {} as any, {} as any);
  const preview = await service.getPlanNotificationDashboard(client as any, 'user-1', 'plan-1');
  assert.deepEqual(preview, { unreadCount: 1, highPriorityCount: 1, latest: [{ id: 'n-1' }], latestImportant: { id: 'n-1' } });
  const important = { in: [NotificationPriority.HIGH, NotificationPriority.URGENT] };
  const [unread, high, latest, latestImportant] = where as Array<{ where: Record<string, unknown> } & Record<string, unknown>>;
  assert.equal(unread.where.userId, 'user-1');
  assert.equal(unread.where.weddingPlanId, 'plan-1');
  assert.equal(unread.where.archivedAt, null);
  assert.equal(unread.where.readAt, null);
  assert.ok(unread.where.AND, 'the visibility filter applies');
  assert.deepEqual(high.where.priority, important);
  assert.deepEqual(latest.orderBy, { createdAt: 'desc' });
  assert.equal(latest.take, 3);
  assert.deepEqual(latestImportant.where.priority, important);
  assert.deepEqual(latestImportant.orderBy, [{ priority: 'desc' }, { createdAt: 'desc' }]);
});

// C24: the home's «القاعة» step is done by a confirmed booking with a venue
// provider, or by a cost in a venue budget category. Each owner answers for
// its own rows.
test('finance answers whether a venue agreement is recorded, narrowed to a contributor\'s costs', async () => {
  const { client, calls } = recorder({
    'weddingCost.findMany': [
      { budgetCategory: { name: 'تصوير' } },
      { budgetCategory: { name: 'قاعة أو مخدرة الرجال' } },
    ],
  });
  const finance = new FinancePortService(catalogWithoutMoneyLinks);
  assert.equal(await finance.hasVenueCost(client, 'plan-1', ['cost-1']), true);
  assert.deepEqual(calls, [
    ['weddingCost.findMany', {
      where: {
        weddingPlanId: 'plan-1',
        id: { in: ['cost-1'] },
        status: { not: WeddingCostStatus.CANCELLED },
      },
      select: { budgetCategory: { select: { name: true } } },
    }],
  ]);

  const none = recorder({
    'weddingCost.findMany': [{ budgetCategory: { name: 'الذهب' } }],
  });
  assert.equal(await finance.hasVenueCost(none.client, 'plan-1'), false);
});

test('marketplace lists the categories of a plan\'s confirmed bookings, once each', async () => {
  const { client, calls } = recorder({
    'booking.findMany': [
      { provider: { primaryCategoryId: 'cat-halls' } },
      { provider: { primaryCategoryId: 'cat-halls' } },
      { provider: { primaryCategoryId: null } },
    ],
  });
  const quotes = new QuoteReadService();
  assert.deepEqual(
    await quotes.listConfirmedBookingCategoryIds(client, 'plan-1', ['quote-1']),
    ['cat-halls'],
  );
  assert.deepEqual(calls, [
    ['booking.findMany', {
      where: {
        status: BookingStatus.CONFIRMED,
        quoteRequest: { weddingPlanId: 'plan-1', id: { in: ['quote-1'] } },
      },
      select: { provider: { select: { primaryCategoryId: true } } },
    }],
  ]);
});
