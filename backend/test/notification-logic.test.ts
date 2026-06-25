import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  Notification,
  NotificationPriority,
  NotificationType,
} from '@prisma/client';
import { AuthenticatedUser } from '../src/auth/authenticated-user.interface';
import { NotificationsService } from '../src/notifications/notifications.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { PermissionService } from '../src/sharing/permission.service';

const user = { id: 'user-1' } as AuthenticatedUser;

function createHarness() {
  const records = new Map<string, Notification>();
  let sequence = 0;
  const notification = {
    findUnique: async ({ where }: { where: { dedupeKey?: string } }) =>
      [...records.values()].find(
        (item) => item.dedupeKey === where.dedupeKey,
      ) ?? null,
    create: async ({ data }: { data: Record<string, unknown> }) => {
      const now = new Date();
      const item: Notification = {
        id: `notification-${++sequence}`,
        userId: data.userId as string,
        weddingPlanId: (data.weddingPlanId as string | null) ?? null,
        type: data.type as NotificationType,
        priority:
          (data.priority as NotificationPriority) ??
          NotificationPriority.NORMAL,
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
    findFirst: async ({
      where,
    }: {
      where: { id: string; userId: string };
    }) => {
      const item = records.get(where.id);
      return item?.userId === where.userId ? item : null;
    },
    update: async ({
      where,
      data,
    }: {
      where: { id: string };
      data: Partial<Notification>;
    }) => {
      const item = { ...records.get(where.id)!, ...data, updatedAt: new Date() };
      records.set(item.id, item);
      return item;
    },
  };
  const prisma = { notification } as unknown as PrismaService;
  const permissions = {} as PermissionService;
  return {
    service: new NotificationsService(prisma, permissions),
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
