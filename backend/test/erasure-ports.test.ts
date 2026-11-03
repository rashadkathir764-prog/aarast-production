import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ContributionScopeStatus, type Prisma } from '@prisma/client';
import { CollaborationErasureService } from '../src/modules/collaboration/infrastructure/collaboration-erasure.service';
import { FinancePortService } from '../src/modules/finance/infrastructure/finance-port.service';
import { catalogWithoutMoneyLinks } from './support/owner-ports';
import { GuestsPortService } from '../src/modules/guests/infrastructure/guests-port.service';
import { MarketplaceErasureService } from '../src/modules/marketplace/infrastructure/marketplace-erasure.service';
import { MessagingErasureService } from '../src/modules/messaging/infrastructure/messaging-erasure.service';
import { NotificationsErasureService } from '../src/modules/notifications/infrastructure/notifications-erasure.service';
import { PlanErasureService } from '../src/modules/planning/infrastructure/plan-erasure.service';
import { TasksPortService } from '../src/modules/tasks/infrastructure/tasks-port.service';
import {
  deleteApplicationIdempotencyKeysForUser,
  deleteIdempotencyKeysForUser,
  deleteStaleIdempotencyReservation,
  findIdempotencyReservation,
} from '../src/platform/idempotency/idempotency-keys';
import { purgeOutboxEventsForAggregatesInTransaction } from '../src/platform/outbox/outbox-purge';
import { OutboxEventTypes } from '../src/platform/outbox/outbox.constants';
import { enqueueOutboxEventInTransaction } from '../src/platform/outbox/outbox.service';

// The account-deletion saga used to run these statements itself. Each owner
// now runs them on the saga's transaction; the shapes, options and internal
// order of every step are the ones the saga ran.

function recorder() {
  const calls: Array<[string, unknown]> = [];
  const statements: string[] = [];
  const delegate = (name: string, result: unknown = { count: 0 }) => new Proxy({}, {
    get: (_target, method: string) => async (args: unknown) => {
      calls.push([`${name}.${method}`, args]);
      return result;
    },
  });
  const tx = {
    $queryRaw: async (query: { strings: string[]; values: unknown[] }) => {
      statements.push(query.strings.join('?').replace(/\s+/g, ' ').trim());
      calls.push(['$queryRaw', query.values]);
      return [{ id: 'row-1' }];
    },
    $executeRaw: async (strings: TemplateStringsArray) => {
      statements.push(strings.join('?').replace(/\s+/g, ' ').trim());
      return 1;
    },
    planEvent: delegate('planEvent'),
    weddingPlan: delegate('weddingPlan'),
    provider: delegate('provider', [{ id: 'provider-1' }]),
    providerReview: delegate('providerReview', [{ providerId: 'provider-1' }]),
    quoteRequest: delegate('quoteRequest'),
    planProviderLink: delegate('planProviderLink'),
    favoriteProvider: delegate('favoriteProvider'),
    chatAttachment: delegate('chatAttachment', [{ id: 'attachment-1' }]),
    conversation: delegate('conversation'),
    conversationParticipant: delegate('conversationParticipant'),
    chatMessage: delegate('chatMessage'),
    conversationReport: delegate('conversationReport'),
    conversationEvent: delegate('conversationEvent'),
    notification: delegate('notification', [{ id: 'notification-1' }]),
    notificationPreference: delegate('notificationPreference', { userId: 'user-1' }),
    pushInstallation: delegate('pushInstallation'),
    contributorTenure: delegate('contributorTenure'),
    contributorHistoryScope: delegate('contributorHistoryScope'),
    sharedMember: delegate('sharedMember'),
    planInvite: delegate('planInvite'),
    costPayment: delegate('costPayment'),
    paymentSchedule: delegate('paymentSchedule'),
    weddingCost: delegate('weddingCost'),
    fundingSource: delegate('fundingSource'),
    budgetCategory: delegate('budgetCategory'),
    weddingTask: delegate('weddingTask'),
    guest: delegate('guest'),
    guestGroup: delegate('guestGroup'),
    guestInvitationCard: delegate('guestInvitationCard'),
    outboxEvent: delegate('outboxEvent'),
    idempotencyKey: delegate('idempotencyKey', null),
  } as unknown as Prisma.TransactionClient;
  return { tx, calls, statements };
}

test('planning locks the owned plans first and deletes them last', async () => {
  const { tx, calls, statements } = recorder();
  const service = new PlanErasureService();
  assert.deepEqual(await service.lockOwnedPlanIdsForUpdateInTransaction(tx, 'user-1'), ['row-1']);
  await service.deletePlansInTransaction(tx, ['plan-1']);
  await service.deletePlansInTransaction(tx, []);
  assert.deepEqual(statements, ['SELECT "id" FROM "WeddingPlan" WHERE "ownerUserId" = ? ORDER BY "id" ASC FOR UPDATE']);
  // D65: the plan's own events go before the plan.
  assert.deepEqual(calls.slice(1), [
    ['planEvent.deleteMany', { where: { weddingPlanId: { in: ['plan-1'] } } }],
    ['weddingPlan.deleteMany', { where: { id: { in: ['plan-1'] } } }],
  ]);
});

test('marketplace lists, locks and deletes its rows in the account scope', async () => {
  const { tx, calls, statements } = recorder();
  const service = new MarketplaceErasureService();
  assert.deepEqual(await service.listOwnedProviderIds(tx, 'user-1'), ['provider-1']);
  assert.deepEqual(await service.listReviewedProviderIds(tx, 'user-1'), ['provider-1']);
  await service.deleteUserReviewsInTransaction(tx, 'user-1');
  assert.deepEqual(await service.lockOwnedQuoteRequestIdsForUpdateInTransaction(tx, {
    userId: 'user-1', weddingPlanIds: ['plan-1'], providerIds: [], conversationIds: ['conversation-1'],
  }), ['row-1']);
  await service.deleteQuoteRequestsInTransaction(tx, ['quote-1']);
  await service.deleteQuoteRequestsInTransaction(tx, []);
  await service.deletePlanProviderLinksInTransaction(tx, ['plan-1']);
  await service.deleteProvidersInTransaction(tx, ['provider-1']);
  await service.deleteProvidersInTransaction(tx, []);
  await service.deleteUserFavoritesInTransaction(tx, 'user-1');
  assert.deepEqual(statements, [
    'SELECT "id" FROM "QuoteRequest" WHERE "userId" = ? OR "weddingPlanId" = ANY(?::text[]) OR "providerId" = ANY(?::text[]) OR "conversationId" = ANY(?::text[]) ORDER BY "id" ASC FOR UPDATE',
  ]);
  assert.deepEqual(calls, [
    ['provider.findMany', { where: { userId: 'user-1' }, orderBy: { id: 'asc' }, select: { id: true } }],
    ['providerReview.findMany', { where: { userId: 'user-1' }, distinct: ['providerId'], orderBy: { providerId: 'asc' }, select: { providerId: true } }],
    ['providerReview.deleteMany', { where: { userId: 'user-1' } }],
    ['$queryRaw', ['user-1', ['plan-1'], [], ['conversation-1']]],
    ['quoteRequest.deleteMany', { where: { id: { in: ['quote-1'] } } }],
    ['planProviderLink.deleteMany', { where: { weddingPlanId: { in: ['plan-1'] } } }],
    ['provider.deleteMany', { where: { id: { in: ['provider-1'] } } }],
    ['favoriteProvider.deleteMany', { where: { userId: 'user-1' } }],
  ]);
});

test('messaging locks the owned conversations, lists their attachments, deletes them and erases a retained identity', async () => {
  const { tx, calls, statements } = recorder();
  const service = new MessagingErasureService();
  assert.deepEqual(await service.lockOwnedConversationIdsForUpdateInTransaction(tx, {
    userId: 'user-1', weddingPlanIds: [], providerIds: ['provider-1'],
  }), ['row-1']);
  assert.deepEqual(await service.listAttachmentIdsForConversations(tx, ['conversation-1']), ['attachment-1']);
  assert.deepEqual(await service.listAttachmentIdsForConversations(tx, []), []);
  await service.deleteConversationsInTransaction(tx, ['conversation-1']);
  await service.deleteConversationsInTransaction(tx, []);
  await service.eraseUserParticipationInTransaction(tx, 'user-1');
  assert.deepEqual(statements, [
    'SELECT "id" FROM "Conversation" WHERE "accountRequesterUserId" = ? OR "weddingPlanId" = ANY(?::text[]) OR "providerId" = ANY(?::text[]) ORDER BY "id" ASC FOR UPDATE',
  ]);
  assert.deepEqual(calls.map(([name]) => name), [
    '$queryRaw',
    'chatAttachment.findMany',
    'conversation.deleteMany',
    'conversationParticipant.deleteMany',
    'chatMessage.deleteMany',
    'conversationReport.deleteMany',
    'conversationEvent.updateMany',
    'conversation.updateMany',
    'conversation.updateMany',
  ]);
  assert.deepEqual(calls[1][1], { where: { message: { conversationId: { in: ['conversation-1'] } } }, orderBy: { id: 'asc' }, select: { id: true } });
  assert.deepEqual(calls[7][1], { where: { createdByUserId: 'user-1' }, data: { createdByUserId: null } });
  assert.deepEqual(calls[8][1], { where: { customerSideBlockedById: 'user-1' }, data: { customerSideBlockedById: null } });
});

test('notifications lists the owned notifications, deletes them, and owns the preference row', async () => {
  const { tx, calls } = recorder();
  const service = new NotificationsErasureService();
  assert.deepEqual(await service.listOwnedNotificationIds(tx, { userId: 'user-1', weddingPlanIds: ['plan-1'], quoteRequestIds: [] }), ['notification-1']);
  await service.deleteNotificationsInTransaction(tx, ['notification-1']);
  await service.deleteNotificationsInTransaction(tx, []);
  await service.deleteUserPreferencesAndInstallationsInTransaction(tx, 'user-1');
  await service.ensurePreferenceInTransaction(tx, 'user-1');
  await service.upsertPreferenceInTransaction(tx, 'user-1', { smsEnabled: false, taskRemindersEnabled: true });
  assert.deepEqual(calls, [
    ['notification.findMany', { where: { OR: [{ userId: 'user-1' }, { weddingPlanId: { in: ['plan-1'] } }] }, select: { id: true } }],
    ['notification.deleteMany', { where: { id: { in: ['notification-1'] } } }],
    ['notificationPreference.deleteMany', { where: { userId: 'user-1' } }],
    ['pushInstallation.deleteMany', { where: { userId: 'user-1' } }],
    ['notificationPreference.upsert', { where: { userId: 'user-1' }, update: {}, create: { userId: 'user-1' } }],
    ['notificationPreference.upsert', {
      where: { userId: 'user-1' },
      create: { userId: 'user-1', smsEnabled: false, taskRemindersEnabled: true },
      update: { smsEnabled: false, taskRemindersEnabled: true },
    }],
  ]);
});

test('collaboration closes tenures, marks scopes deleted, removes members then invites, and detaches a retained identity', async () => {
  const { tx, calls } = recorder();
  const at = new Date('2026-09-17T09:00:00.000Z');
  const service = new CollaborationErasureService();
  await service.markPlansDeletedInTransaction(tx, ['plan-1'], at);
  await service.closeActorTenuresInTransaction(tx, 'user-1', at);
  await service.deletePlanMembersAndInvitesInTransaction(tx, ['plan-1']);
  await service.detachUserInTransaction(tx, 'user-1');
  assert.deepEqual(calls, [
    ['contributorTenure.updateMany', {
      where: { endedAt: null, historyScope: { weddingPlanId: { in: ['plan-1'] } } },
      data: { endedAt: at, endReason: 'PLAN_DELETED', sharedMemberId: null },
    }],
    ['contributorHistoryScope.updateMany', {
      where: { weddingPlanId: { in: ['plan-1'] } },
      data: { status: ContributionScopeStatus.DELETED, deletedAt: at },
    }],
    ['contributorTenure.updateMany', {
      where: { actorUserId: 'user-1', endedAt: null },
      data: { endedAt: at, endReason: 'ACCOUNT_DELETED', sharedMemberId: null },
    }],
    ['sharedMember.deleteMany', { where: { weddingPlanId: { in: ['plan-1'] } } }],
    ['planInvite.deleteMany', { where: { weddingPlanId: { in: ['plan-1'] } } }],
    ['contributorTenure.updateMany', { where: { actorUserId: 'user-1' }, data: { actorUserId: null } }],
    ['sharedMember.deleteMany', { where: { userId: 'user-1' } }],
    ['planInvite.deleteMany', { where: { inviterUserId: 'user-1' } }],
    ['planInvite.updateMany', { where: { inviteeUserId: 'user-1' }, data: { inviteeUserId: null } }],
  ]);
});

test('finance locks the plan costs in the money mutation order and purges the ledger payments-first', async () => {
  const { tx, calls, statements } = recorder();
  const service = new FinancePortService(catalogWithoutMoneyLinks);
  await service.lockPlanCostsForUpdateInTransaction(tx, ['plan-1']);
  await service.lockPlanCostsForUpdateInTransaction(tx, []);
  await service.purgePlanLedgerInTransaction(tx, ['plan-1']);
  await service.deletePlanBudgetCategoriesInTransaction(tx, ['plan-1']);
  assert.deepEqual(statements, [
    'SELECT "id" FROM "WeddingCost" WHERE "weddingPlanId" IN (?) ORDER BY "id" ASC FOR UPDATE',
    "SELECT set_config('aarast.allow_ledger_purge', 'on', true)",
  ]);
  assert.deepEqual(calls.slice(1), [
    ['costPayment.deleteMany', { where: { weddingCost: { weddingPlanId: { in: ['plan-1'] } } } }],
    ['paymentSchedule.deleteMany', { where: { weddingCost: { weddingPlanId: { in: ['plan-1'] } } } }],
    ['weddingCost.deleteMany', { where: { weddingPlanId: { in: ['plan-1'] } } }],
    // Funding sources reference the plan; their loan repayments cascade.
    ['fundingSource.deleteMany', { where: { weddingPlanId: { in: ['plan-1'] } } }],
    ['budgetCategory.deleteMany', { where: { weddingPlanId: { in: ['plan-1'] } } }],
  ]);
});

test('tasks and guests delete the plan rows (groups after guests) and tasks unassign a retained identity', async () => {
  const { tx, calls } = recorder();
  await new TasksPortService().deletePlanTasksInTransaction(tx, ['plan-1']);
  await new TasksPortService().unassignUserTasksInTransaction(tx, 'user-1');
  await new GuestsPortService().deletePlanGuestsInTransaction(tx, ['plan-1']);
  assert.deepEqual(calls, [
    ['weddingTask.deleteMany', { where: { weddingPlanId: { in: ['plan-1'] } } }],
    ['weddingTask.updateMany', { where: { assigneeUserId: 'user-1' }, data: { assigneeUserId: null } }],
    ['guest.deleteMany', { where: { weddingPlanId: { in: ['plan-1'] } } }],
    ['guestGroup.deleteMany', { where: { weddingPlanId: { in: ['plan-1'] } } }],
    // D83: the plan's invitation card; the guests' event invites cascade.
    ['guestInvitationCard.deleteMany', { where: { weddingPlanId: { in: ['plan-1'] } } }],
  ]);
});

test('platform purges outbox events by aggregate and owns the idempotency key statements', async () => {
  const { tx, calls } = recorder();
  await enqueueOutboxEventInTransaction(tx, {
    type: OutboxEventTypes.conversationActivityAvailable,
    aggregateType: 'conversation',
    aggregateId: 'conversation-1',
    payload: { conversationId: 'conversation-1' },
  });
  await purgeOutboxEventsForAggregatesInTransaction(tx, { notificationIds: ['n-1'], conversationIds: [] });
  await purgeOutboxEventsForAggregatesInTransaction(tx, { notificationIds: [], conversationIds: [] });
  assert.equal(await findIdempotencyReservation(tx, 'user-1', 'request-1'), null);
  const staleBefore = new Date('2026-09-17T08:00:00.000Z');
  await deleteStaleIdempotencyReservation(tx, 'reservation-1', staleBefore);
  await deleteIdempotencyKeysForUser(tx, 'user-1');
  await deleteApplicationIdempotencyKeysForUser(tx, 'user-1');
  assert.deepEqual(calls, [
    ['outboxEvent.create', {
      data: {
        type: OutboxEventTypes.conversationActivityAvailable,
        aggregateType: 'conversation',
        aggregateId: 'conversation-1',
        payload: { conversationId: 'conversation-1' },
      },
    }],
    ['outboxEvent.deleteMany', { where: { OR: [{ aggregateType: 'notification', aggregateId: { in: ['n-1'] } }] } }],
    ['idempotencyKey.findUnique', {
      where: { userId_key: { userId: 'user-1', key: 'request-1' } },
      select: { id: true, method: true, path: true, completedAt: true, createdAt: true },
    }],
    ['idempotencyKey.deleteMany', { where: { id: 'reservation-1', completedAt: null, createdAt: { lte: staleBefore } } }],
    ['idempotencyKey.deleteMany', { where: { userId: 'user-1' } }],
    ['idempotencyKey.deleteMany', {
      where: {
        userId: 'user-1',
        NOT: {
          OR: [
            { path: '/admin' }, { path: { startsWith: '/admin/' } },
            { path: '/api/v1/admin' }, { path: { startsWith: '/api/v1/admin/' } },
            { path: '/api/v1/auth/admin' }, { path: { startsWith: '/api/v1/auth/admin/' } },
          ],
        },
      },
    }],
  ]);
});
