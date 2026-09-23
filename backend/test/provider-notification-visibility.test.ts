import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { HttpException } from '@nestjs/common';
import {
  NotificationPriority,
  NotificationType,
  Prisma,
  ProviderStatus,
  UserStatus,
  WeddingPlanStatus,
} from '@prisma/client';
import { dashboardService, notificationsService } from './support/owner-ports';

const userId = '11111111-1111-4111-8111-111111111111';
const providerId = '22222222-2222-4222-8222-222222222222';
const otherProviderId = '33333333-3333-4333-8333-333333333333';
const providerConversationId = '44444444-4444-4444-8444-444444444444';
const customerConversationId = '55555555-5555-4555-8555-555555555555';
const privateRequesterName = 'Private Requester Name';
const now = new Date('2026-07-26T00:00:00.000Z');

type Row = {
  id: string;
  userId: string;
  weddingPlanId: string | null;
  type: NotificationType;
  priority: NotificationPriority;
  title: string;
  body: string;
  entityType: string | null;
  entityId: string | null;
  routeTarget: string | null;
  data: Record<string, unknown> | null;
  dedupeKey: string | null;
  readAt: Date | null;
  archivedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

function row(
  id: string,
  overrides: Partial<Row> = {},
): Row {
  return {
    id,
    userId,
    weddingPlanId: null,
    type: NotificationType.GENERAL,
    priority: NotificationPriority.NORMAL,
    title: 'Notification',
    body: 'Safe notification body',
    entityType: null,
    entityId: null,
    routeTarget: null,
    data: null,
    dedupeKey: null,
    readAt: null,
    archivedAt: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function baseRows(): Row[] {
  return [
    row('provider-quote-legacy', {
      type: NotificationType.QUOTE_REQUEST_SUBMITTED,
      body: `New quote from ${privateRequesterName}`,
      entityType: 'quote_request',
      entityId: 'provider-quote',
      routeTarget: '/provider/dashboard',
      data: { providerId, quoteRequestId: 'provider-quote' },
    }),
    row('provider-chat-legacy', {
      type: NotificationType.CHAT_MESSAGE_RECEIVED,
      body: `New message from ${privateRequesterName}`,
      entityType: 'conversation',
      entityId: providerConversationId,
      routeTarget: `/conversations/${providerConversationId}`,
      data: { providerId, conversationId: providerConversationId },
    }),
    row('provider-explicit', {
      type: NotificationType.GENERAL,
      body: `Provider-only ${privateRequesterName}`,
      data: { providerId, recipientAudience: 'PROVIDER' },
    }),
    row('provider-plan-chat', {
      weddingPlanId: 'customer-plan-1',
      type: NotificationType.CHAT_MESSAGE_RECEIVED,
      body: `Provider plan chat ${privateRequesterName}`,
      entityType: 'conversation',
      entityId: providerConversationId,
      routeTarget: `/conversations/${providerConversationId}`,
      data: {
        providerId,
        conversationId: providerConversationId,
        recipientAudience: 'PROVIDER',
      },
    }),
    row('wedding-task', {
      weddingPlanId: 'wedding-plan-1',
      type: NotificationType.TASK_DUE_SOON,
      title: 'Wedding task',
      body: 'Wedding task remains visible',
      entityType: 'task',
      entityId: 'task-1',
      routeTarget: '/wedding-plans/wedding-plan-1/tasks',
      data: {
        weddingPlanId: 'wedding-plan-1',
        recipientAudience: 'CUSTOMER',
      },
    }),
    row('customer-quote', {
      type: NotificationType.QUOTE_OFFER_RECEIVED,
      title: 'Customer quote',
      body: 'Customer-side quote remains visible',
      entityType: 'quote_request',
      entityId: 'customer-quote',
      routeTarget: '/providers?quoteId=customer-quote',
      data: {
        providerId: otherProviderId,
        quoteRequestId: 'customer-quote',
        recipientAudience: 'CUSTOMER',
      },
    }),
    row('customer-chat', {
      type: NotificationType.CHAT_MESSAGE_RECEIVED,
      title: 'Customer chat',
      body: 'Customer-side chat remains visible',
      entityType: 'conversation',
      entityId: customerConversationId,
      routeTarget: `/conversations/${customerConversationId}`,
      data: {
        providerId: otherProviderId,
        conversationId: customerConversationId,
        recipientAudience: 'CUSTOMER',
      },
    }),
  ];
}

function jsonPathValue(
  data: Record<string, unknown> | null,
  path: unknown,
): unknown {
  if (!Array.isArray(path)) return undefined;
  let value: unknown = data;
  for (const segment of path) {
    if (
      typeof segment !== 'string' ||
      typeof value !== 'object' ||
      value === null ||
      Array.isArray(value)
    ) {
      return undefined;
    }
    value = (value as Record<string, unknown>)[segment];
  }
  return value;
}

function matchesValue(actual: unknown, expected: unknown): boolean {
  if (expected === Prisma.DbNull || expected === Prisma.JsonNull) {
    return actual === null;
  }
  if (expected === Prisma.AnyNull) {
    return actual === null || actual === undefined;
  }
  if (
    typeof expected !== 'object' ||
    expected === null ||
    Array.isArray(expected)
  ) {
    return actual === expected;
  }
  const condition = expected as Record<string, unknown>;
  if (Array.isArray(condition.in)) {
    return condition.in.includes(actual);
  }
  if (Array.isArray(condition.notIn)) {
    return !condition.notIn.includes(actual);
  }
  if (Object.prototype.hasOwnProperty.call(condition, 'not')) {
    return !matchesValue(actual, condition.not);
  }
  return true;
}

function matchesWhere(item: Row, input: unknown): boolean {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return true;
  const where = input as Record<string, unknown>;
  const and = where.AND;
  if (and) {
    const conditions = Array.isArray(and) ? and : [and];
    if (!conditions.every((condition) => matchesWhere(item, condition))) {
      return false;
    }
  }
  const or = where.OR;
  if (or) {
    const conditions = Array.isArray(or) ? or : [or];
    if (!conditions.some((condition) => matchesWhere(item, condition))) {
      return false;
    }
  }
  const not = where.NOT;
  if (not) {
    const conditions = Array.isArray(not) ? not : [not];
    if (conditions.some((condition) => matchesWhere(item, condition))) {
      return false;
    }
  }

  for (const [key, expected] of Object.entries(where)) {
    if (key === 'AND' || key === 'OR' || key === 'NOT') continue;
    if (key === 'data') {
      if (
        typeof expected !== 'object' ||
        expected === null ||
        Array.isArray(expected)
      ) {
        return false;
      }
      const filter = expected as Record<string, unknown>;
      const actual = Array.isArray(filter.path)
        ? jsonPathValue(item.data, filter.path)
        : item.data;
      if (
        Object.prototype.hasOwnProperty.call(filter, 'equals') &&
        !matchesValue(actual, filter.equals)
      ) {
        return false;
      }
      if (
        Object.prototype.hasOwnProperty.call(filter, 'not') &&
        matchesValue(actual, filter.not)
      ) {
        return false;
      }
      continue;
    }
    if (key === 'weddingPlan') {
      if (item.weddingPlanId !== 'wedding-plan-1') return false;
      continue;
    }
    if (!matchesValue(item[key as keyof Row], expected)) {
      return false;
    }
  }
  return true;
}

function createHarness(
  initialStatus: ProviderStatus | null,
  initialRows = baseRows(),
) {
  let status = initialStatus;
  const rows = new Map(initialRows.map((item) => [item.id, { ...item }]));
  let responseWrites = 0;

  const notification = {
    count: async ({ where }: { where: unknown }) =>
      [...rows.values()].filter((item) => matchesWhere(item, where)).length,
    findMany: async ({
      where,
      skip = 0,
      take = 50,
    }: {
      where: unknown;
      skip?: number;
      take?: number;
    }) =>
      [...rows.values()]
        .filter((item) => matchesWhere(item, where))
        .sort(
          (left, right) =>
            right.createdAt.getTime() - left.createdAt.getTime() ||
            right.id.localeCompare(left.id),
        )
        .slice(skip, skip + take),
    findFirst: async ({ where }: { where: unknown }) =>
      [...rows.values()].find((item) => matchesWhere(item, where)) ?? null,
    update: async ({
      where,
      data,
    }: {
      where: { id: string };
      data: Partial<Row>;
    }) => {
      responseWrites += 1;
      const updated = { ...rows.get(where.id)!, ...data, updatedAt: new Date() };
      rows.set(updated.id, updated);
      return updated;
    },
    updateMany: async ({
      where,
      data,
    }: {
      where: unknown;
      data: Partial<Row>;
    }) => {
      let count = 0;
      for (const item of rows.values()) {
        if (!matchesWhere(item, where)) continue;
        rows.set(item.id, { ...item, ...data, updatedAt: new Date() });
        count += 1;
      }
      return { count };
    },
    delete: async ({ where }: { where: { id: string } }) => {
      responseWrites += 1;
      rows.delete(where.id);
      return {};
    },
  };

  const prisma = {
    provider: {
      findUnique: async () =>
        status === null ? null : { id: providerId, status },
    },
    conversation: {
      findUnique: async ({ where }: { where: { id: string } }) =>
        where.id === providerConversationId
          ? {
              provider: {
                id: providerId,
                userId,
                status: status ?? ProviderStatus.REJECTED,
              },
            }
          : {
              provider: {
                id: otherProviderId,
                userId: 'other-provider-user',
                status: ProviderStatus.ACTIVE,
              },
            },
    },
    sharedMember: { findMany: async () => [] },
    weddingTask: { findMany: async () => [] },
    contributionEvent: { findMany: async () => [] },
    paymentSchedule: { findMany: async () => [] },
    notification,
    weddingPlan: {
      findMany: async () => [
        {
          id: 'wedding-plan-1',
          ownerUserId: userId,
          sharedMembers: [],
        },
      ],
    },
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(' ')
        : String(query);
      if (sql.includes('FROM "User"')) {
        return [{ id: userId, status: UserStatus.ACTIVE }];
      }
      return [];
    },
    $transaction: async (operation: unknown) =>
      Array.isArray(operation)
        ? Promise.all(operation)
        : (
            operation as (tx: any) => unknown
          )(prisma),
  };

  return {
    service: notificationsService(
      prisma as any,
      {
        assertPlanReadable: async (planId: string) => {
          if (planId !== 'wedding-plan-1') {
            throw new Error('simulated inaccessible customer plan');
          }
          return {
            plan: {
              id: 'wedding-plan-1',
              ownerUserId: userId,
            },
            isOwner: true,
            sharedMember: null,
          };
        },
        assertPlanReadableInTransaction: async (
          _tx: unknown,
          planId: string,
        ) => {
          if (planId !== 'wedding-plan-1') {
            throw new Error('simulated inaccessible customer plan');
          }
          return {
            plan: {
              id: 'wedding-plan-1',
              ownerUserId: userId,
            },
            isOwner: true,
            sharedMember: null,
          };
        },
        canViewMoney: () => true,
      } as any,
      {} as any,
    ),
    rows,
    setStatus(next: ProviderStatus | null) {
      status = next;
    },
    responseWrites() {
      return responseWrites;
    },
  };
}

function errorCode(error: unknown): unknown {
  if (!(error instanceof HttpException)) return undefined;
  const response = error.getResponse();
  return typeof response === 'object' && response !== null
    ? (response as { code?: unknown }).code
    : undefined;
}

function isProviderNotActive(error: unknown): boolean {
  assert.equal(errorCode(error), 'PROVIDER_NOT_ACTIVE');
  return true;
}

test('inactive provider states hide only provider-audience notifications', async () => {
  for (const status of [
    ProviderStatus.PENDING,
    ProviderStatus.NEEDS_CHANGES,
    ProviderStatus.SUSPENDED,
    ProviderStatus.REJECTED,
  ]) {
    const harness = createHarness(status);
    const page = await harness.service.list(
      { id: userId } as any,
      undefined,
      undefined,
      false,
      '1',
      '20',
    );
    const visibleIds = page.items.map((item) => item.id).sort();

    assert.deepEqual(
      visibleIds,
      ['customer-chat', 'customer-quote', 'wedding-task'],
      status,
    );
    assert.equal(page.total, 3, status);
    assert.equal(page.totalPages, 1, status);
    assert.equal(page.hasMore, false, status);
    assert.doesNotMatch(JSON.stringify(page), new RegExp(privateRequesterName));

    const unread = await harness.service.unreadCount({ id: userId } as any);
    assert.equal(unread.count, 3, status);

    for (const id of [
      'provider-quote-legacy',
      'provider-chat-legacy',
      'provider-explicit',
    ]) {
      await assert.rejects(
        () => harness.service.findOne({ id: userId } as any, id),
        isProviderNotActive,
      );
    }

    assert.equal(
      (await harness.service.findOne({ id: userId } as any, 'wedding-task')).id,
      'wedding-task',
    );
    assert.equal(
      (await harness.service.findOne({ id: userId } as any, 'customer-chat')).id,
      'customer-chat',
    );
  }
});

test('provider notifications reappear only when the live provider becomes ACTIVE', async () => {
  const harness = createHarness(ProviderStatus.SUSPENDED);
  const hidden = await harness.service.list(
    { id: userId } as any,
    undefined,
    undefined,
    false,
    '1',
    '20',
  );
  assert.equal(hidden.total, 3);

  harness.setStatus(ProviderStatus.ACTIVE);
  const active = await harness.service.list(
    { id: userId } as any,
    undefined,
    undefined,
    false,
    '1',
    '20',
  );
  assert.equal(active.total, 7);
  assert.equal(
    active.items.some((item) => item.id === 'provider-plan-chat'),
    true,
  );
  assert.equal(
    (
      await harness.service.findOne(
        { id: userId } as any,
        'provider-plan-chat',
      )
    ).id,
    'provider-plan-chat',
  );
  assert.equal(
    (
      await harness.service.markRead(
        { id: userId } as any,
        'provider-plan-chat',
      )
    ).id,
    'provider-plan-chat',
  );
  assert.match(JSON.stringify(active), new RegExp(privateRequesterName));
  assert.equal(
    (
      await harness.service.findOne(
        { id: userId } as any,
        'provider-chat-legacy',
      )
    ).id,
    'provider-chat-legacy',
  );
});

test('provider visibility is applied before pagination and bulk read updates', async () => {
  const providerRows = Array.from({ length: 55 }, (_, index) =>
    row(`provider-${String(index).padStart(2, '0')}`, {
      type: NotificationType.CHAT_MESSAGE_RECEIVED,
      body: `${privateRequesterName} ${index}`,
      data: { providerId, recipientAudience: 'PROVIDER' },
      createdAt: new Date(now.getTime() + 10_000 + index),
    }),
  );
  const visibleRows = Array.from({ length: 5 }, (_, index) =>
    row(`wedding-${index}`, {
      weddingPlanId: 'wedding-plan-1',
      type: NotificationType.TASK_DUE_SOON,
      data: { recipientAudience: 'CUSTOMER' },
      createdAt: new Date(now.getTime() + index),
    }),
  );
  const harness = createHarness(ProviderStatus.SUSPENDED, [
    ...providerRows,
    ...visibleRows,
  ]);

  const first = await harness.service.list(
    { id: userId } as any,
    undefined,
    undefined,
    false,
    '1',
    '3',
  );
  assert.equal(first.items.length, 3);
  assert.equal(first.total, 5);
  assert.equal(first.totalPages, 2);
  assert.equal(first.hasMore, true);
  assert.ok(first.items.every((item) => item.id.startsWith('wedding-')));

  const marked = await harness.service.markAllRead({ id: userId } as any);
  assert.equal(marked.updated, 5);
  assert.equal(
    [...harness.rows.values()].filter(
      (item) => item.id.startsWith('provider-') && item.readAt !== null,
    ).length,
    0,
  );
});

test('direct provider notification mutations never expose stored bodies while inactive', async () => {
  const harness = createHarness(ProviderStatus.REJECTED);

  await assert.rejects(
    () =>
      harness.service.markRead(
        { id: userId } as any,
        'provider-quote-legacy',
      ),
    isProviderNotActive,
  );
  await assert.rejects(
    () =>
      harness.service.archive(
        { id: userId } as any,
        'provider-chat-legacy',
      ),
    isProviderNotActive,
  );
  await assert.rejects(
    () =>
      harness.service.remove(
        { id: userId } as any,
        'provider-explicit',
      ),
    isProviderNotActive,
  );
  assert.equal(harness.responseWrites(), 0);
});

test('stale explicit provider-audience notifications stay hidden without a provider profile', async () => {
  const harness = createHarness(null, [
    ...baseRows(),
    row('legacy-null-data', {
      weddingPlanId: 'wedding-plan-1',
      type: NotificationType.SHARING_UPDATED,
      title: 'Legacy null data',
      data: null,
    }),
    row('legacy-missing-audience', {
      weddingPlanId: 'wedding-plan-1',
      type: NotificationType.TASK_DUE_SOON,
      title: 'Legacy missing audience',
      entityType: 'task',
      data: { taskId: 'legacy-task' },
    }),
    row('legacy-customer-chat-missing-provider', {
      type: NotificationType.CHAT_MESSAGE_RECEIVED,
      title: 'Legacy customer chat',
      entityType: 'conversation',
      entityId: customerConversationId,
      routeTarget: `/conversations/${customerConversationId}`,
      data: { conversationId: customerConversationId },
    }),
  ]);
  const page = await harness.service.list(
    { id: userId } as any,
    undefined,
    undefined,
    false,
    '1',
    '20',
  );

  assert.equal(
    page.items.some((item) => item.id === 'provider-explicit'),
    false,
  );
  assert.equal(
    page.items.some((item) => item.id === 'provider-quote-legacy'),
    false,
  );
  assert.equal(
    page.items.some((item) => item.id === 'wedding-task'),
    true,
  );
  assert.equal(
    page.items.some((item) => item.id === 'legacy-null-data'),
    true,
  );
  assert.equal(
    page.items.some((item) => item.id === 'legacy-missing-audience'),
    true,
  );
  assert.equal(
    page.items.some(
      (item) => item.id === 'legacy-customer-chat-missing-provider',
    ),
    true,
  );
});

test('plan dashboard notification previews reuse the lifecycle visibility predicate', async () => {
  const visibility = {
    NOT: { id: 'provider-scoped-notification' },
  };
  const notificationQueries: Array<Record<string, unknown>> = [];
  const emptyModel = new Proxy(
    {},
    {
      get: (_target, property) => async () =>
        property === 'count' ? 0 : property === 'findFirst' ? null : [],
    },
  );
  const prisma = new Proxy(
    {
      notification: {
        count: async ({ where }: any) => {
          notificationQueries.push(where);
          return 0;
        },
        findMany: async ({ where }: any) => {
          notificationQueries.push(where);
          return [];
        },
        findFirst: async ({ where }: any) => {
          notificationQueries.push(where);
          return null;
        },
      },
    } as Record<string, unknown>,
    {
      get: (target, property: string) => target[property] ?? emptyModel,
    },
  );
  const plan = {
    id: 'wedding-plan-1',
    ownerUserId: userId,
    title: 'Wedding plan',
    weddingDate: new Date('2027-01-01T00:00:00.000Z'),
    city: 'Sanaa',
    location: null,
    estimatedBudget: null,
    currency: 'YER',
    status: WeddingPlanStatus.PLANNING,
    importMigrationId: null,
    createdAt: now,
    updatedAt: now,
  };
  const permissions = {
    assertPlanReadable: async () => ({
      plan,
      isOwner: true,
      sharedMember: null,
    }),
    assertPlanReadableInTransaction: async () => ({
      plan,
      isOwner: true,
      sharedMember: null,
    }),
    canViewMoney: () => false,
    canManageMoney: () => true,
    canManageTasks: () => true,
    canManageGuests: () => true,
    canManageProviders: () => true,
    canManageMembers: () => true,
    canManagePlan: () => true,
  };
  const lifecycleVisibility = {
    visibilityWhereForUser: async (requestedUserId: string) => {
      assert.equal(requestedUserId, userId);
      return visibility;
    },
  };

  (prisma as any).$transaction = async (
    operation: (tx: unknown) => Promise<unknown>,
  ) => operation(prisma as any);

  await dashboardService(
    prisma as any,
    permissions as any,
    lifecycleVisibility as any,
  ).getWeddingPlanDashboardSummary({ id: userId } as any, plan.id);

  assert.equal(notificationQueries.length, 4);
  assert.ok(
    notificationQueries.every(
      (where) =>
        where.userId === userId &&
        where.weddingPlanId === plan.id &&
        where.archivedAt === null &&
        where.AND === visibility,
    ),
  );
});
