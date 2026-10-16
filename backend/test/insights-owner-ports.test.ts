import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  GuestStatus,
  NotificationPriority,
  PaymentScheduleStatus,
  PlanProviderLinkStatus,
  type Prisma,
  ProviderStatus,
  QuoteRequestStatus,
  WeddingCostStatus,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from '@prisma/client';
import { PermissionService } from '../src/modules/collaboration/internal/permission.service';
import { FinancePortService } from '../src/modules/finance/infrastructure/finance-port.service';
import { GuestsPortService } from '../src/modules/guests/infrastructure/guests-port.service';
import { ProviderReadService } from '../src/modules/marketplace/infrastructure/provider-read.service';
import { QuoteReadService } from '../src/modules/marketplace/infrastructure/quote-read.service';
import { PlanReadService } from '../src/modules/planning/infrastructure/plan-read.service';
import { TasksPortService } from '../src/modules/tasks/infrastructure/tasks-port.service';
import { notificationsService } from './support/owner-ports';

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

test('planning finds the owner\'s current planning plan by wedding date', async () => {
  const { client, calls } = recorder({ 'weddingPlan.findFirst': { id: 'plan-1' } });
  assert.deepEqual(await new PlanReadService().findCurrentPlanningPlan(client, 'owner-1'), { id: 'plan-1' });
  assert.deepEqual(calls, [
    ['weddingPlan.findFirst', {
      where: { ownerUserId: 'owner-1', status: WeddingPlanStatus.PLANNING },
      orderBy: [{ weddingDate: 'asc' }, { createdAt: 'desc' }],
    }],
  ]);
});

test('finance serves a plan\'s cost amounts and pending schedules, narrowed to a contributor\'s costs', async () => {
  const { client, calls } = recorder();
  const finance = new FinancePortService();
  await finance.listPlanCostAmounts(client, 'plan-1');
  await finance.listPlanCostAmounts(client, 'plan-1', ['cost-1']);
  await finance.listPendingPaymentSchedules(client, 'plan-1', null);
  await finance.listPendingPaymentSchedules(client, 'plan-1', ['cost-1']);
  const costWhere = (ids?: string[]) => ({
    weddingPlanId: 'plan-1',
    ...(ids ? { id: { in: ids } } : {}),
    status: { not: WeddingCostStatus.CANCELLED },
  });
  assert.deepEqual(calls, [
    ['weddingCost.findMany', { where: costWhere(), select: { id: true, totalAmount: true, paidAmount: true } }],
    ['weddingCost.findMany', { where: costWhere(['cost-1']), select: { id: true, totalAmount: true, paidAmount: true } }],
    ['paymentSchedule.findMany', {
      where: { status: PaymentScheduleStatus.PENDING, weddingCost: costWhere() },
      include: { weddingCost: { select: { title: true } } },
      orderBy: byDue,
    }],
    ['paymentSchedule.findMany', {
      where: { status: PaymentScheduleStatus.PENDING, weddingCost: costWhere(['cost-1']) },
      include: { weddingCost: { select: { title: true } } },
      orderBy: byDue,
    }],
  ]);
});

test('tasks serves the upcoming tasks, the plan dashboard counters and the dated open tasks in the reader\'s scope', async () => {
  const { client, calls } = recorder({ 'weddingTask.count': 3 });
  const tasks = new TasksPortService();
  const today = new Date('2026-09-23T00:00:00.000Z');
  const endOfToday = new Date('2026-09-23T23:59:59.999Z');
  await tasks.listUpcomingTasks(client, 'plan-1', 5, 'owner-1');
  const dashboard = await tasks.getPlanTaskDashboard(client, {
    weddingPlanId: 'plan-1',
    scope: { kind: 'contributor', assigneeUserId: 'user-1', taskIds: ['task-1'] },
    today,
    endOfToday,
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
    ['weddingTask.findMany', { where: { ...scoped, dueDate: { lte: endOfToday }, status: open }, orderBy: byDue, take: 2 }],
    ['weddingTask.findFirst', { where: { ...scoped, status: open }, orderBy: byDue }],
    ['weddingTask.count', { where: scoped }],
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
    ['guest.count', { where: { ...base, status: GuestStatus.CONFIRMED } }],
    ['guest.count', { where: { ...base, status: { in: [GuestStatus.PENDING, GuestStatus.INVITED] } } }],
    ['guest.count', { where: { ...base, status: GuestStatus.DECLINED } }],
    ['guest.count', { where: { ...base, OR: [{ phone: null }, { phone: '' }, { name: '' }] } }],
  ]);
});

test('marketplace serves the home counters, the active plan provider links and the plan quote counters', async () => {
  const { client, calls } = recorder();
  const providers = new ProviderReadService();
  const quotes = new QuoteReadService();
  await providers.countFeaturedActiveProviders(client);
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
    ['provider.count', { where: { status: ProviderStatus.ACTIVE, isFeatured: true } }],
    ['favoriteProvider.count', { where: { userId: 'user-1' } }],
    ['planProviderLink.count', { where: links() }],
    ['planProviderLink.findMany', {
      where: links(['quote-1']),
      include: {
        provider: {
          include: {
            services: {
              where: { isActive: true },
              orderBy: [{ isFeatured: 'desc' }, { createdAt: 'desc' }],
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
    ['quoteRequest.count', { where: { ...planQuotes, status: { in: [QuoteRequestStatus.REJECTED, QuoteRequestStatus.CANCELLED] } } }],
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
