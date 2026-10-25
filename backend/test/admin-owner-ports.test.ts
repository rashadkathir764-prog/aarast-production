import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import {
  ConversationReportStatus,
  ProviderStatus,
  ReviewStatus,
  UserStatus,
} from '@prisma/client';
import { CatalogAdminService } from '../src/modules/catalog/infrastructure/catalog-admin.service';
import {
  CATALOG_ADMIN_IMPLEMENTATION,
  CatalogAdminInternalModule,
} from '../src/modules/catalog/internal/catalog-admin.internal.module';
import { CatalogAdminPublicModule } from '../src/modules/catalog/public/catalog-admin-public.module';
import { CATALOG_ADMIN_PORT } from '../src/modules/catalog/public/catalog-admin.port';
import { PermissionService } from '../src/modules/collaboration/internal/permission.service';
import { IdentityAdminService } from '../src/modules/identity/infrastructure/identity-admin.service';
import {
  IDENTITY_ADMIN_IMPLEMENTATION,
  IdentityUserInternalModule,
} from '../src/modules/identity/internal/identity-user.internal.module';
import { IdentityAdminPublicModule } from '../src/modules/identity/public/identity-admin-public.module';
import { IDENTITY_ADMIN_PORT } from '../src/modules/identity/public/identity-admin.port';
import { MarketplaceAdminService } from '../src/modules/marketplace/internal/marketplace-admin.service';
import {
  MARKETPLACE_ADMIN_IMPLEMENTATION,
  MarketplaceAdminInternalModule,
} from '../src/modules/marketplace/internal/marketplace-admin.internal.module';
import { MarketplaceAdminPublicModule } from '../src/modules/marketplace/public/marketplace-admin-public.module';
import { MARKETPLACE_ADMIN_PORT } from '../src/modules/marketplace/public/marketplace-admin.port';
import { MessagingAdminService } from '../src/modules/messaging/infrastructure/messaging-admin.service';
import {
  MESSAGING_ADMIN_IMPLEMENTATION,
  MessagingPortsInternalModule,
} from '../src/modules/messaging/internal/messaging-ports.internal.module';
import { MessagingAdminPublicModule } from '../src/modules/messaging/public/messaging-admin-public.module';
import { MESSAGING_ADMIN_PORT } from '../src/modules/messaging/public/messaging-admin.port';
import { NotificationsAdminService } from '../src/modules/notifications/infrastructure/notifications-admin.service';
import {
  NOTIFICATIONS_ADMIN_IMPLEMENTATION,
  NotificationsAdminInternalModule,
} from '../src/modules/notifications/internal/notifications-admin.internal.module';
import { NotificationsAdminPublicModule } from '../src/modules/notifications/public/notifications-admin-public.module';
import { NOTIFICATIONS_ADMIN_PORT } from '../src/modules/notifications/public/notifications-admin.port';
import { PlanReadService } from '../src/modules/planning/infrastructure/plan-read.service';

// The back office used to read and write every owner's tables itself. Each
// owner now performs the administrative statements on its own rows, on the
// client the back office passes, and the back office attaches the other
// owners' rows. These tests pin the statements each owner runs.

type Call = [string, unknown];

function sqlText(query: any): string {
  return query.strings?.join('?') ?? String(query);
}

/** A client whose delegates record every call and answer from `answers`. */
function recordingClient(answers: Record<string, unknown> = {}) {
  const calls: Call[] = [];
  const client: any = new Proxy(
    {},
    {
      get(_target, model: string) {
        if (model === '$queryRaw') {
          return async (query: any) => {
            calls.push(['$queryRaw', { sql: sqlText(query), values: query.values }]);
            const answer = answers.$queryRaw;
            return typeof answer === 'function' ? answer(query) : (answer ?? []);
          };
        }
        return new Proxy(
          {},
          {
            get(_delegate, operation: string) {
              return async (args: unknown) => {
                const name = `${model}.${operation}`;
                calls.push([name, args]);
                const answer = answers[name];
                return typeof answer === 'function' ? answer(args) : answer;
              };
            },
          },
        );
      },
    },
  );
  return { client, calls };
}

test('every admin port is bound to its owner implementation through a public module', () => {
  for (const [publicModule, internalModule, port, implementation, service] of [
    [IdentityAdminPublicModule, IdentityUserInternalModule, IDENTITY_ADMIN_PORT, IDENTITY_ADMIN_IMPLEMENTATION, IdentityAdminService],
    [CatalogAdminPublicModule, CatalogAdminInternalModule, CATALOG_ADMIN_PORT, CATALOG_ADMIN_IMPLEMENTATION, CatalogAdminService],
    [MarketplaceAdminPublicModule, MarketplaceAdminInternalModule, MARKETPLACE_ADMIN_PORT, MARKETPLACE_ADMIN_IMPLEMENTATION, MarketplaceAdminService],
    [MessagingAdminPublicModule, MessagingPortsInternalModule, MESSAGING_ADMIN_PORT, MESSAGING_ADMIN_IMPLEMENTATION, MessagingAdminService],
    [NotificationsAdminPublicModule, NotificationsAdminInternalModule, NOTIFICATIONS_ADMIN_PORT, NOTIFICATIONS_ADMIN_IMPLEMENTATION, NotificationsAdminService],
  ] as const) {
    assert.deepEqual(Reflect.getMetadata(MODULE_METADATA.IMPORTS, publicModule), [internalModule]);
    assert.deepEqual(Reflect.getMetadata(MODULE_METADATA.PROVIDERS, publicModule), [
      { provide: port, useExisting: implementation },
    ]);
    assert.deepEqual(Reflect.getMetadata(MODULE_METADATA.EXPORTS, publicModule), [port]);
    const providers = Reflect.getMetadata(MODULE_METADATA.PROVIDERS, internalModule);
    assert.ok(providers.includes(service));
    assert.ok(
      providers.some(
        (provider: any) => provider.provide === implementation && provider.useExisting === service,
      ),
    );
  }
});

test('identity locks the accounts in id order, once each, and skips an empty lock', async () => {
  const { client, calls } = recordingClient({ $queryRaw: [{ id: 'a' }] });
  const service = new IdentityAdminService();

  assert.deepEqual(await service.lockAccountsForUpdateInTransaction(client, []), []);
  assert.deepEqual(calls, []);

  await service.lockAccountsForUpdateInTransaction(client, ['z-user', 'a-user', 'z-user']);
  assert.equal(calls.length, 1);
  const [, lock] = calls[0] as [string, { sql: string; values: unknown[] }];
  assert.match(lock.sql, /FROM "User"/);
  assert.match(lock.sql, /ORDER BY "id" ASC\s+FOR UPDATE/);
  assert.deepEqual(lock.values, ['a-user', 'z-user']);
});

test('identity lists accounts without credentials and searches the requested fields', async () => {
  const { client, calls } = recordingClient({
    'user.count': 1,
    'user.findMany': (args: any) => (args.select.id && Object.keys(args.select).length === 1 ? [{ id: 'u1' }] : []),
  });
  const service = new IdentityAdminService();

  await service.listAccounts(client, 'sara', { skip: 20, take: 10 });
  const text = { contains: 'sara', mode: 'insensitive' };
  const where = { OR: [{ name: text }, { phone: text }, { email: text }] };
  assert.deepEqual(calls[0], ['user.count', { where }]);
  const [, list] = calls[1] as [string, any];
  assert.deepEqual(list.where, where);
  assert.deepEqual(Object.keys(list.select).sort(), [
    'avatarUrl', 'createdAt', 'email', 'id', 'name', 'phone', 'role', 'status', 'updatedAt',
  ]);
  assert.deepEqual([list.orderBy, list.skip, list.take], [{ createdAt: 'desc' }, 20, 10]);

  calls.length = 0;
  assert.deepEqual(await service.searchAccountIds(client, 'sara', ['name', 'phone']), ['u1']);
  assert.deepEqual(calls[0], [
    'user.findMany',
    { where: { OR: [{ name: text }, { phone: text }] }, select: { id: true } },
  ]);
  calls.length = 0;
  assert.deepEqual(await service.searchAccountIds(client, 'sara', []), []);
  assert.deepEqual(calls, []);
});

test('identity disables an account and revokes only its live refresh tokens', async () => {
  const { client, calls } = recordingClient({ 'user.update': { id: 'u1' } });
  const service = new IdentityAdminService();
  const now = new Date('2026-09-23T00:00:00.000Z');

  await service.setAccountStatusInTransaction(client, 'u1', UserStatus.DISABLED);
  await service.revokeRefreshTokensInTransaction(client, 'u1', now);

  assert.deepEqual(calls[0]?.[0], 'user.update');
  assert.deepEqual((calls[0]?.[1] as any).where, { id: 'u1' });
  assert.deepEqual((calls[0]?.[1] as any).data, { status: UserStatus.DISABLED });
  assert.deepEqual(calls[1], [
    'refreshToken.updateMany',
    { where: { userId: 'u1', revokedAt: null }, data: { revokedAt: now } },
  ]);
});

test('catalog locks a category before reading it and never reads a missing one', async () => {
  const service = new CatalogAdminService();
  const found = recordingClient({
    $queryRaw: [{ id: 'category-1' }],
    'providerCategory.findUnique': { id: 'category-1' },
  });
  assert.deepEqual(await service.lockCategoryForUpdateInTransaction(found.client, 'category-1'), { id: 'category-1' });
  assert.deepEqual(found.calls.map(([name]) => name), ['$queryRaw', 'providerCategory.findUnique']);
  assert.match((found.calls[0]?.[1] as any).sql, /FROM "ProviderCategory"[\s\S]*FOR UPDATE/);

  const missing = recordingClient({ $queryRaw: [] });
  assert.equal(await service.lockCategoryForUpdateInTransaction(missing.client, 'gone'), null);
  assert.deepEqual(missing.calls.map(([name]) => name), ['$queryRaw']);

  const share = recordingClient({ $queryRaw: [{ id: 'city-1' }] });
  assert.equal(await service.lockCityForShareInTransaction(share.client, 'city-1'), true);
  assert.match((share.calls[0]?.[1] as any).sql, /FROM "City"[\s\S]*FOR SHARE/);
});

test('marketplace filters providers by its own columns and the accounts identity matched', async () => {
  const { client, calls } = recordingClient({ 'provider.count': 0, 'provider.findMany': [] });
  const service = new MarketplaceAdminService();

  await service.listProviders(
    client,
    {
      statuses: [ProviderStatus.PENDING, ProviderStatus.NEEDS_CHANGES],
      cityId: 'city-1',
      categoryId: 'category-1',
      search: { text: 'hall', userIds: ['u1'] },
      resubmitted: true,
    },
    { skip: 0, take: 20 },
  );

  const text = { contains: 'hall', mode: 'insensitive' };
  const where = {
    AND: [
      { status: { in: [ProviderStatus.PENDING, ProviderStatus.NEEDS_CHANGES] } },
      // B-01: the «أُعيد إرسالها» queue narrows the profiles waiting for
      // review, whatever statuses the page asked for.
      { status: { in: [ProviderStatus.PENDING] } },
      { resubmittedAt: { not: null } },
      { cityId: 'city-1' },
      { OR: [{ primaryCategoryId: 'category-1' }, { services: { some: { categoryId: 'category-1' } } }] },
      { OR: [{ businessName: text }, { ownerName: text }, { phone: text }, { email: text }, { userId: { in: ['u1'] } }] },
    ],
  };
  assert.deepEqual(calls[0], ['provider.count', { where }]);
  const [, list] = calls[1] as [string, any];
  assert.deepEqual(list.where, where);
  // The counts, and the latest decision whose notes the row shows (B-01).
  assert.deepEqual(Object.keys(list.include), ['_count', 'reviewEvents']);
});

test('marketplace locks a review only under its provider and sets its moderation status', async () => {
  const { client, calls } = recordingClient({
    'providerReview.findUnique': { providerId: 'provider-1' },
    $queryRaw: [{ id: 'review-1' }],
    'providerReview.update': { id: 'review-1' },
  });
  const service = new MarketplaceAdminService();

  assert.equal(await service.findReviewProviderId(client, 'review-1'), 'provider-1');
  assert.equal(await service.lockReviewForUpdateInTransaction(client, 'review-1', 'provider-1'), true);
  await service.setReviewStatusInTransaction(client, 'review-1', ReviewStatus.HIDDEN);

  assert.deepEqual(calls.map(([name]) => name), [
    'providerReview.findUnique',
    '$queryRaw',
    'providerReview.update',
  ]);
  const lock = calls[1]?.[1] as any;
  assert.match(lock.sql, /FROM "ProviderReview"[\s\S]*"providerId" = \?[\s\S]*FOR UPDATE/);
  assert.deepEqual(lock.values, ['review-1', 'provider-1']);
  assert.deepEqual(calls[2]?.[1], {
    where: { id: 'review-1' },
    data: { status: ReviewStatus.HIDDEN },
    include: { provider: true },
  });

  const missing = recordingClient({ 'providerReview.findUnique': null, $queryRaw: [] });
  assert.equal(await service.findReviewProviderId(missing.client, 'gone'), null);
  assert.equal(await service.lockReviewForUpdateInTransaction(missing.client, 'gone', 'provider-1'), false);
});

test('marketplace counts catalog usage per entry, zero for an unused one', async () => {
  const { client, calls } = recordingClient({
    'provider.groupBy': [{ primaryCategoryId: 'category-1', _count: { _all: 2 } }],
    'providerService.groupBy': [{ categoryId: 'category-1', _count: { _all: 5 } }],
  });
  const service = new MarketplaceAdminService();

  assert.deepEqual(await service.countCategoryUsage(client, ['category-1', 'category-2']), [
    { id: 'category-1', providers: 2, services: 5 },
    { id: 'category-2', providers: 0, services: 0 },
  ]);
  assert.deepEqual(calls[0], [
    'provider.groupBy',
    { by: ['primaryCategoryId'], where: { primaryCategoryId: { in: ['category-1', 'category-2'] } }, _count: { _all: true } },
  ]);
  calls.length = 0;
  assert.deepEqual(await service.countCityUsage(client, []), []);
  assert.deepEqual(calls, []);
});

test('marketplace hands a provider decision the provider row lock before the status read', async () => {
  const service = new MarketplaceAdminService();
  const locked = recordingClient({
    $queryRaw: [{ id: 'provider-1' }],
    'provider.findUnique': { userId: 'owner-1', status: ProviderStatus.PENDING },
  });
  assert.deepEqual(await service.lockProviderForUpdateInTransaction(locked.client, 'provider-1'), {
    userId: 'owner-1',
    status: ProviderStatus.PENDING,
  });
  assert.deepEqual(locked.calls.map(([name]) => name), ['$queryRaw', 'provider.findUnique']);

  const missing = recordingClient({ $queryRaw: [] });
  assert.equal(await service.lockProviderForUpdateInTransaction(missing.client, 'gone'), null);
  assert.deepEqual(missing.calls.map(([name]) => name), ['$queryRaw']);
});

test('marketplace reads the providers a page of accounts owns in one statement', async () => {
  const { client, calls } = recordingClient({ 'provider.findMany': [] });
  const service = new MarketplaceAdminService();

  assert.deepEqual(await service.getAccountProviders(client, []), []);
  assert.deepEqual(calls, []);
  await service.getAccountProviders(client, ['u1', 'u2']);
  assert.deepEqual(calls, [['provider.findMany', { where: { userId: { in: ['u1', 'u2'] } } }]]);
});

test('messaging locks a report before its status is set', async () => {
  const service = new MessagingAdminService();
  const missing = recordingClient({ $queryRaw: [] });
  assert.equal(await service.lockConversationReportForUpdateInTransaction(missing.client, 'gone'), false);
  assert.deepEqual(missing.calls.map(([name]) => name), ['$queryRaw']);

  const found = recordingClient({
    $queryRaw: [{ id: 'report-1' }],
    'conversationReport.update': { id: 'report-1' },
    'conversation.findMany': [{ id: 'c1' }, { id: 'c2' }],
  });
  assert.equal(await service.lockConversationReportForUpdateInTransaction(found.client, 'report-1'), true);
  await service.setConversationReportStatusInTransaction(found.client, 'report-1', ConversationReportStatus.REVIEWED);
  assert.match((found.calls[0]?.[1] as any).sql, /FROM "ConversationReport"[\s\S]*FOR UPDATE/);
  assert.deepEqual((found.calls[1]?.[1] as any).data, { status: ConversationReportStatus.REVIEWED });

  assert.deepEqual(await service.listProviderConversationIds(found.client, 'provider-1'), ['c1', 'c2']);
  assert.deepEqual(found.calls[2], [
    'conversation.findMany',
    { where: { providerId: 'provider-1' }, orderBy: { id: 'asc' }, select: { id: true } },
  ]);
});

test('notifications archive keeps the first read time and deletes only a locked row', async () => {
  const service = new NotificationsAdminService();
  const readAt = new Date('2026-09-01T00:00:00.000Z');
  const { client, calls } = recordingClient({
    $queryRaw: [{ id: 'n1', readAt }],
    'notification.update': (args: unknown) => args,
  });

  const archived: any = await service.archiveNotificationInTransaction(client, 'n1');
  assert.equal(archived.data.readAt, readAt);
  assert.ok(archived.data.archivedAt instanceof Date);
  assert.match((calls[0]?.[1] as any).sql, /FROM "Notification"[\s\S]*FOR UPDATE/);

  const missing = recordingClient({ $queryRaw: [] });
  assert.equal(await service.deleteNotificationInTransaction(missing.client, 'gone'), false);
  assert.deepEqual(missing.calls.map(([name]) => name), ['$queryRaw']);
});

test('planning counts plans and collaboration revokes the live invites a user issued', async () => {
  const { client, calls } = recordingClient({ 'weddingPlan.count': 3, 'planInvite.updateMany': { count: 1 } });
  const range = { gte: new Date('2026-01-01T00:00:00.000Z') };

  assert.equal(await new PlanReadService().countPlans(client), 3);
  assert.equal(await new PlanReadService().countPlans(client, range), 3);
  const revokedAt = new Date('2026-09-23T00:00:00.000Z');
  await new PermissionService({} as any, {} as any).revokeLiveInvitesIssuedByUserInTransaction(client, 'u1', revokedAt);

  assert.deepEqual(calls, [
    ['weddingPlan.count', undefined],
    ['weddingPlan.count', { where: { createdAt: range } }],
    [
      'planInvite.updateMany',
      {
        where: { inviterUserId: 'u1', acceptedAt: null, declinedAt: null, revokedAt: null, expiresAt: { gt: revokedAt } },
        data: { revokedAt },
      },
    ],
  ]);
});
