import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Notification, NotificationPriority, NotificationType } from '@prisma/client';
import { AuthenticatedUser } from '../src/auth/authenticated-user.interface';
import { NotificationsService } from '../src/notifications/notifications.service';
import { OutboxService } from '../src/outbox/outbox.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { PermissionService } from '../src/sharing/permission.service';
import { SharingService } from '../src/sharing/sharing.service';

const user = { id: 'user-1' } as AuthenticatedUser;

function createHarness() {
  const records = new Map<string, Notification>();
  let sequence = 0;
  const notification = {
    findUnique: async ({ where }: { where: { dedupeKey?: string } }) =>
      [...records.values()].find((item) => item.dedupeKey === where.dedupeKey) ?? null,
    create: async ({ data }: { data: Record<string, unknown> }) => {
      const now = new Date();
      const item: Notification = {
        id: `notification-${++sequence}`,
        userId: data.userId as string,
        weddingPlanId: (data.weddingPlanId as string | null) ?? null,
        type: data.type as NotificationType,
        priority: (data.priority as NotificationPriority) ?? NotificationPriority.NORMAL,
        title: data.title as string,
        body: data.body as string,
        entityType: (data.entityType as string | null) ?? null,
        entityId: (data.entityId as string | null) ?? null,
        routeTarget: (data.routeTarget as string | null) ?? null,
        data: null,
        dedupeKey: (data.dedupeKey as string | null) ?? null,
        readAt: null,
        archivedAt: null,
        createdAt: now,
        updatedAt: now,
      };
      records.set(item.id, item);
      return item;
    },
    findFirst: async ({ where }: { where: { id: string; userId: string } }) => {
      const item = records.get(where.id);
      return item?.userId === where.userId ? item : null;
    },
    update: async ({ where, data }: { where: { id: string }; data: Partial<Notification> }) => {
      const item = {
        ...records.get(where.id)!,
        ...data,
        updatedAt: new Date(),
      };
      records.set(item.id, item);
      return item;
    },
    count: async ({ where }: { where: { userId: string; archivedAt: null } }) =>
      [...records.values()].filter(
        (item) => item.userId === where.userId && item.archivedAt === where.archivedAt,
      ).length,
    findMany: async ({
      where,
      skip,
      take,
    }: {
      where: { userId: string; archivedAt: null };
      skip: number;
      take: number;
    }) =>
      [...records.values()]
        .filter((item) => item.userId === where.userId && item.archivedAt === where.archivedAt)
        .sort(
          (left, right) =>
            right.createdAt.getTime() - left.createdAt.getTime() || right.id.localeCompare(left.id),
        )
        .slice(skip, skip + take),
  };
  const outboxEvent = { create: async () => ({ id: 'outbox-1' }) };
  const prisma = {
    notification,
    outboxEvent,
    $transaction: async (operation: unknown) =>
      Array.isArray(operation)
        ? Promise.all(operation)
        : (
            operation as (tx: {
              notification: typeof notification;
              outboxEvent: typeof outboxEvent;
            }) => unknown
          )({ notification, outboxEvent }),
  } as unknown as PrismaService;
  const permissions = {} as PermissionService;
  return {
    service: new NotificationsService(prisma, permissions, new OutboxService()),
    records,
  };
}

test('notification creation preserves priority, entity, and route metadata', async () => {
  const { service } = createHarness();
  const created = await service.createNotification({
    userId: user.id,
    weddingPlanId: 'plan-1',
    type: NotificationType.QUOTE_OFFER_RECEIVED,
    priority: NotificationPriority.HIGH,
    title: 'Quote received',
    body: 'A real provider offer arrived.',
    entityType: 'quote_request',
    entityId: 'quote-1',
    routeTarget: '/wedding-plans/plan-1/plan-center',
    dedupeKey: 'quote-1-received',
  });

  assert.equal(created.priority, NotificationPriority.HIGH);
  assert.equal(created.entityType, 'quote_request');
  assert.equal(created.entityId, 'quote-1');
  assert.equal(created.routeTarget, '/wedding-plans/plan-1/plan-center');
});

test('transaction-scoped notification creation reuses the caller transaction', async () => {
  let outboxRows = 0;
  const now = new Date();
  const client = {
    notification: {
      create: async ({ data }: { data: Record<string, unknown> }) => ({
        id: 'notification-invite',
        userId: data.userId as string,
        weddingPlanId: null,
        type: data.type as NotificationType,
        priority: NotificationPriority.NORMAL,
        title: data.title as string,
        body: data.body as string,
        entityType: null,
        entityId: null,
        routeTarget: null,
        data: null,
        dedupeKey: (data.dedupeKey as string | null) ?? null,
        readAt: null,
        archivedAt: null,
        createdAt: now,
        updatedAt: now,
      }),
    },
    outboxEvent: {
      create: async () => {
        outboxRows += 1;
        return { id: 'outbox-invite' };
      },
    },
  };
  const prisma = {
    $transaction: async () => {
      throw new Error('nested transaction must not be opened');
    },
  } as unknown as PrismaService;
  const service = new NotificationsService(
    prisma,
    {} as PermissionService,
    new OutboxService(),
  );

  const created = await service.createNotificationInTransaction(client as any, {
    userId: user.id,
    type: NotificationType.SHARING_INVITE_ACCEPTED,
    title: 'Invite accepted',
    body: 'Participant accepted the invitation.',
    dedupeKey: 'invite-accepted',
  });

  assert.equal(created.id, 'notification-invite');
  assert.equal(outboxRows, 1);
});

test('notification dedupe returns the existing event', async () => {
  const { service, records } = createHarness();
  const input = {
    userId: user.id,
    type: NotificationType.TASK_DUE_SOON,
    title: 'Task due',
    body: 'Task is due soon.',
    dedupeKey: 'user-1:task:task-1',
  };

  const first = await service.createNotification(input);
  const second = await service.createNotification(input);
  assert.equal(second.id, first.id);
  assert.equal(records.size, 1);
});

test('archive marks the notification read and removes it from the active inbox', async () => {
  const { service } = createHarness();
  const created = await service.createNotification({
    userId: user.id,
    type: NotificationType.GENERAL,
    title: 'Event',
    body: 'Event body',
  });

  const archived = await service.archive(user, created.id);
  assert.ok(archived.archivedAt);
  assert.ok(archived.readAt);
});

test('notification inbox is paginated and reads never generate reminders', async () => {
  const { service } = createHarness();
  for (let index = 0; index < 25; index++) {
    await service.createNotification({
      userId: user.id,
      type: NotificationType.GENERAL,
      title: `Event ${index}`,
      body: 'Event body',
    });
  }

  const first = await service.list(user, undefined, undefined, false, '1', '10');
  const third = await service.list(user, undefined, undefined, false, '3', '10');

  assert.equal(first.items.length, 10);
  assert.equal(first.total, 25);
  assert.equal(first.totalPages, 3);
  assert.equal(first.hasMore, true);
  assert.equal(third.items.length, 5);
  assert.equal(third.hasMore, false);
});

test('scheduled reminders respect notification and financial permissions', async () => {
  const now = new Date();
  const dueDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const captured: Array<Record<string, unknown>> = [];
  let outboxRows = 0;
  const plan = {
    id: 'plan-1',
    ownerUserId: 'owner-1',
    status: 'PLANNING',
    sharedMembers: [
      {
        userId: 'finance-member',
        receiveNotifications: true,
        canViewMoney: true,
        canManageMoney: false,
      },
      {
        userId: 'task-only-member',
        receiveNotifications: true,
        canViewMoney: false,
        canManageMoney: false,
      },
    ],
  };
  const tx = {
    $queryRaw: async () => [{ locked: true }],
    weddingPlan: { findMany: async () => [plan] },
    weddingTask: {
      findMany: async () => [
        {
          id: 'task-1',
          weddingPlanId: plan.id,
          title: 'Task',
          dueDate,
          status: 'TODO',
        },
      ],
    },
    paymentSchedule: {
      findMany: async () => [
        {
          id: 'schedule-1',
          weddingCostId: 'cost-1',
          amount: { toString: () => '100' },
          dueDate,
          status: 'PENDING',
          weddingCost: {
            weddingPlanId: plan.id,
            title: 'Cost',
            partyName: 'Private',
            provider: null,
          },
        },
      ],
    },
    notification: {
      createManyAndReturn: async ({ data }: { data: Array<Record<string, unknown>> }) => {
        captured.push(...data);
        return data.map((item, index) => ({ ...item, id: `created-${index}` }));
      },
    },
    outboxEvent: {
      create: async () => {
        outboxRows++;
        return { id: `outbox-${outboxRows}` };
      },
    },
  };
  const prisma = {
    $transaction: async (operation: (client: typeof tx) => unknown) => operation(tx),
  } as unknown as PrismaService;
  const permissions = {
    canViewMoney: (context: { sharedMember: { canViewMoney: boolean; canManageMoney: boolean } }) =>
      context.sharedMember.canViewMoney || context.sharedMember.canManageMoney,
  } as unknown as PermissionService;
  const service = new NotificationsService(prisma, permissions, new OutboxService());

  const created = await service.generateDueNotifications();
  assert.equal(created, 5);
  assert.equal(outboxRows, 5);
  assert.equal(captured.filter((row) => row.entityType === 'task').length, 3);
  assert.equal(captured.filter((row) => row.entityType === 'payment_schedule').length, 2);
  assert.equal(
    captured.some(
      (row) => row.entityType === 'payment_schedule' && row.userId === 'task-only-member',
    ),
    false,
  );
  const ownerSchedule = captured.find(
    (row) => row.entityType === 'payment_schedule' && row.userId === 'owner-1',
  );
  const memberSchedule = captured.find(
    (row) => row.entityType === 'payment_schedule' && row.userId === 'finance-member',
  );
  assert.ok(ownerSchedule);
  assert.ok(memberSchedule);
  assert.match(String(ownerSchedule.body), /100/);
  assert.equal(
    ownerSchedule.routeTarget,
    '/wedding-plans/plan-1/money/costs/cost-1/schedules/schedule-1',
  );
  assert.doesNotMatch(String(memberSchedule.body), /100|Cost|Private/);
  assert.equal(Object.prototype.hasOwnProperty.call(memberSchedule.data, 'partyName'), false);
});

test('revoking financial access purges stored financial notifications atomically', async () => {
  const existing = {
    id: 'member-1',
    weddingPlanId: 'plan-1',
    userId: 'member-user-1',
    role: 'VIEWER',
    canViewMoney: true,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
    receiveNotifications: true,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
  let purgedInTransaction = false;
  const tx = {
    sharedMember: {
      update: async ({ data }: { data: Record<string, unknown> }) => ({
        ...existing,
        ...data,
        user: { id: existing.userId, name: 'Member', phone: null },
      }),
    },
  };
  const prisma = {
    sharedMember: {
      findFirst: async () => existing,
    },
    $transaction: async (operation: (client: typeof tx) => unknown) => operation(tx),
  } as unknown as PrismaService;
  const permissions = {
    assertMemberManageable: async () => ({
      plan: { id: 'plan-1', ownerUserId: 'owner-1' },
      isOwner: true,
      sharedMember: null,
    }),
    canViewMoney: (context: { sharedMember: typeof existing | null }) =>
      context.sharedMember?.canViewMoney === true ||
      context.sharedMember?.canManageMoney === true,
  } as unknown as PermissionService;
  const notifications = {
    purgeMoneyForMember: async (client: unknown, userId: string, weddingPlanId: string) => {
      purgedInTransaction =
        client === tx && userId === existing.userId && weddingPlanId === existing.weddingPlanId;
    },
  };
  const sharing = new SharingService(
    prisma,
    permissions,
    notifications as unknown as NotificationsService,
    { deliver: async () => ({ channel: 'WHATSAPP', status: 'DELIVERED' }) } as any,
  );

  await sharing.updateMemberForPlan({ id: 'owner-1' } as AuthenticatedUser, 'plan-1', existing.id, {
    canViewMoney: false,
  });

  assert.equal(purgedInTransaction, true);
});
