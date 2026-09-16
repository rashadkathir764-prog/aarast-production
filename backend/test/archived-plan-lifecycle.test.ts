import type { ConversationLifecyclePort } from "../src/modules/messaging/public/conversation-lifecycle.port";

const lifecycle: ConversationLifecyclePort = {
  ensureConversationContext: async () => { throw new Error("Unexpected ensureConversationContext"); },
  recordConversationEvent: async () => { throw new Error("Unexpected recordConversationEvent"); },
};
import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ConflictException } from '@nestjs/common';
import {
  AppRole,
  ConversationScope,
  PlanInviteDeliveryStatus,
  ProviderStatus,
  QuoteRequestStatus,
  SharedMemberRole,
  UserRole,
  UserStatus,
  WeddingPlanStatus,
} from '@prisma/client';
import { ConversationsService } from '../src/conversations/conversations.service';
import { MarketplaceService } from '../src/marketplace/marketplace.service';
import { FinancePortService } from '../src/modules/finance/internal/finance-port.service';
import { ProviderDashboardService } from '../src/provider-dashboard/provider-dashboard.service';
import { SharingService } from '../src/modules/collaboration/internal/sharing.service';
import { WeddingPlansService } from '../src/wedding-plans/wedding-plans.service';
import { collaborationHistory, collaborationPermissions, planningOwnerPorts } from './support/owner-ports';

const now = new Date('2026-07-26T00:00:00.000Z');
const weddingPlanId = '11111111-1111-4111-8111-111111111111';
const providerId = '22222222-2222-4222-8222-222222222222';
const providerUserId = '33333333-3333-4333-8333-333333333333';
const requesterId = '44444444-4444-4444-8444-444444444444';
const quoteRequestId = '55555555-5555-4555-8555-555555555555';
const conversationId = '66666666-6666-4666-8666-666666666666';

const archivedPlan = {
  id: weddingPlanId,
  ownerUserId: requesterId,
  title: 'Archived plan',
  city: 'Sanaa',
  weddingDate: null,
  estimatedBudget: null,
  currency: 'YER',
  status: WeddingPlanStatus.ARCHIVED,
  priorities: [],
  location: null,
  onboardingPath: null,
  persona: null,
  onboardingCompletedAt: now,
  createdAt: now,
  updatedAt: now,
};

const requester = {
  id: requesterId,
  name: 'Requester',
  appName: null,
  phone: '+967700000001',
  email: null,
  role: UserRole.USER,
  adminRole: null,
  appRole: AppRole.WEDDING_USER,
  status: UserStatus.ACTIVE,
  phoneVerifiedAt: now,
  lastLoginAt: now,
  avatarUrl: null,
  appAvatarUrl: null,
  locale: 'ar',
  activeWeddingPlanId: weddingPlanId,
  onboardingPath: null,
  persona: null,
  onboardingCompletedAt: now,
  createdAt: now,
  updatedAt: now,
} as any;

const providerUser = {
  ...requester,
  id: providerUserId,
  name: 'Provider Owner',
  phone: '+967700000002',
  role: UserRole.PROVIDER,
  appRole: AppRole.PROVIDER,
  activeWeddingPlanId: null,
} as any;

function assertArchivedReadOnly(error: unknown) {
  assert.ok(error instanceof ConflictException);
  const response = error.getResponse();
  assert.equal(typeof response, 'object');
  assert.equal(
    (response as { code?: unknown }).code,
    'PLAN_ARCHIVED_READ_ONLY',
  );
  return true;
}

test('archiving a plan revokes every live pending invitation in the same transaction', async () => {
  const planningPlan = {
    ...archivedPlan,
    status: WeddingPlanStatus.PLANNING,
  };
  const operations: string[] = [];
  let inviteMutation:
    | {
        where: Record<string, any>;
        data: Record<string, any>;
      }
    | undefined;
  const tx = {
    weddingPlan: {
      update: async ({ where, data }: any) => {
        operations.push('plan:archived');
        assert.deepEqual(where, { id: weddingPlanId });
        assert.deepEqual(data, { status: WeddingPlanStatus.ARCHIVED });
        return archivedPlan;
      },
    },
    planInvite: {
      updateMany: async (mutation: {
        where: Record<string, any>;
        data: Record<string, any>;
      }) => {
        operations.push('invites:revoked');
        inviteMutation = mutation;
        return { count: 2 };
      },
    },
    contributorHistoryScope: {
      upsert: async () => {
        operations.push('history-scope:archived');
        return {};
      },
    },
  };
  let transactionCalls = 0;
  const service = new WeddingPlansService(
    {
      $transaction: async (operation: (client: any) => Promise<unknown>) => {
        transactionCalls += 1;
        operations.push('transaction:start');
        const result = await operation(tx);
        operations.push('transaction:end');
        return result;
      },
    } as any,
    collaborationPermissions({
      assertPlanManageableForUpdateInTransaction: async (
        client: unknown,
        id: string,
        actor: unknown,
      ) => {
        operations.push('plan:locked');
        assert.equal(client, tx);
        assert.equal(id, weddingPlanId);
        assert.equal(actor, requester);
        return {
          plan: planningPlan,
          isOwner: true,
          sharedMember: null,
        };
      },
      canViewMoney: () => true,
    }) as any,
    collaborationHistory({
      recordForContextInTransaction: async () => null,
    }) as any,
    ...planningOwnerPorts,
  );

  const result = await service.archive(requester, weddingPlanId);

  assert.equal(result.status, WeddingPlanStatus.ARCHIVED);
  assert.equal(transactionCalls, 1);
  assert.deepEqual(operations, [
    'transaction:start',
    'plan:locked',
    'plan:archived',
    'invites:revoked',
    'history-scope:archived',
    'transaction:end',
  ]);
  assert.ok(inviteMutation);
  assert.deepEqual(inviteMutation.where, {
    weddingPlanId,
    acceptedAt: null,
    declinedAt: null,
    revokedAt: null,
    expiresAt: { gt: inviteMutation.data.revokedAt },
  });
  assert.ok(inviteMutation.data.revokedAt instanceof Date);
});

test('an archived plan cannot be selected as active under the stable lifecycle contract', async () => {
  let activePlanWrites = 0;
  const tx = {
    $queryRaw: async () => [{ id: requester.id }],
    user: {
      update: async () => {
        activePlanWrites += 1;
      },
    },
  };
  const service = new WeddingPlansService(
    {
      $transaction: async (operation: (client: any) => Promise<unknown>) =>
        operation(tx),
    } as any,
    collaborationPermissions({
      assertPlanReadableForUserUpdateInTransaction: async () => ({
        plan: archivedPlan,
        isOwner: true,
        sharedMember: null,
      }),
    }) as any,
    collaborationHistory({}) as any,
    ...planningOwnerPorts,
  );

  await assert.rejects(
    () => service.setActive(requester, weddingPlanId),
    assertArchivedReadOnly,
  );
  assert.equal(activePlanWrites, 0);
});

test('accepting an invitation cannot create membership on an archived plan', async () => {
  let membershipWrites = 0;
  const invite = {
    id: '77777777-7777-4777-8777-777777777777',
    weddingPlanId,
    inviterUserId: '88888888-8888-4888-8888-888888888888',
    inviteeUserId: requesterId,
    name: requester.name,
    phone: requester.phone,
    normalizedPhone: requester.phone,
    email: null,
    role: SharedMemberRole.VIEWER,
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
    receiveNotifications: true,
    tokenHash: 'token-hash',
    acceptedAt: null,
    declinedAt: null,
    revokedAt: null,
    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    deliveryStatus: PlanInviteDeliveryStatus.DELIVERED,
    deliveryChannel: 'WHATSAPP',
    deliveryAttemptedAt: now,
    deliveryError: null,
    createdAt: now,
    updatedAt: now,
    weddingPlan: archivedPlan,
    inviter: {
      id: '88888888-8888-4888-8888-888888888888',
      name: 'Inviter',
      phone: '+967700000003',
    },
    invitee: {
      id: requesterId,
      name: requester.name,
      phone: requester.phone,
    },
  };
  let lockCount = 0;
  const tx = {
    $queryRaw: async () => {
      lockCount += 1;
      return lockCount === 1
        ? [
            { id: requesterId, status: UserStatus.ACTIVE },
            { id: invite.inviterUserId, status: UserStatus.ACTIVE },
          ]
        : [{ id: weddingPlanId }];
    },
    weddingPlan: {
      findUnique: async () => ({
        ownerUserId: requesterId,
        status: WeddingPlanStatus.ARCHIVED,
      }),
    },
    planInvite: {
      updateMany: async () => ({ count: 1 }),
      findUnique: async () => ({ ...invite, acceptedAt: now }),
    },
    sharedMember: {
      upsert: async () => {
        membershipWrites += 1;
        return {
          id: '99999999-9999-4999-8999-999999999999',
          weddingPlanId,
          userId: requesterId,
          role: SharedMemberRole.VIEWER,
          canViewMoney: false,
          canEditPlan: false,
          canManageTasks: false,
          canManageGuests: false,
          canManageProviders: false,
          canInviteMembers: false,
          canManageMoney: false,
          receiveNotifications: true,
          createdAt: now,
          updatedAt: now,
          user: {
            id: requesterId,
            name: requester.name,
            phone: requester.phone,
          },
        };
      },
    },
  };
  const service = new SharingService(
    {
      planInvite: {
        findUnique: async () => invite,
      },
      $transaction: async (operation: (client: any) => Promise<unknown>) =>
        operation(tx),
    } as any,
    {} as any,
    {
      createNotificationInTransaction: async () => undefined,
    } as any,
    {} as any,
    {
      ensureTenureInTransaction: async () => undefined,
      recordInTransaction: async () => undefined,
      recordForContextInTransaction: async () => undefined,
      closeTenureInTransaction: async () => undefined,
    } as any,
  );

  await assert.rejects(
    () => service.acceptInvite(requester, invite.id),
    assertArchivedReadOnly,
  );
  assert.equal(membershipWrites, 0);
});

test('a requester cannot cancel a quote linked to an archived plan', async () => {
  let quoteWrites = 0;
  const existing = {
    id: quoteRequestId,
    conversationId,
    userId: requesterId,
    providerId,
    weddingPlanId,
    weddingPlan: {
      id: weddingPlanId,
      ownerUserId: requesterId,
      status: WeddingPlanStatus.ARCHIVED,
    },
    provider: { userId: providerUserId },
    status: QuoteRequestStatus.SENT,
  };
  let lockCount = 0;
  const tx = {
    $queryRaw: async () => {
      lockCount += 1;
      return lockCount === 1
        ? [
            { id: requesterId, status: UserStatus.ACTIVE },
            { id: providerUserId, status: UserStatus.ACTIVE },
          ]
        : [{ id: weddingPlanId }];
    },
    weddingPlan: { findUnique: async () => archivedPlan },
    quoteRequest: {
      findFirst: async () => existing,
      updateMany: async () => {
        quoteWrites += 1;
        return { count: 1 };
      },
    },
  };
  const service = new MarketplaceService(
    {
      $transaction: async (operation: (client: any) => Promise<unknown>) =>
        operation(tx),
    } as any,
    {
      assertPlanReadableInTransaction: async () => ({
        plan: archivedPlan,
        isOwner: true,
        sharedMember: null,
      }),
      canManageProviders: () => true,
    } as any,
    {} as any, lifecycle, new FinancePortService(),
  );

  await assert.rejects(
    () => service.cancelMyQuoteRequest(requester, quoteRequestId),
    assertArchivedReadOnly,
  );
  assert.equal(quoteWrites, 0);
});

test('an active provider cannot transition a quote linked to an archived plan', async () => {
  let quoteWrites = 0;
  const provider = {
    id: providerId,
    userId: providerUserId,
    businessName: 'Provider',
    status: ProviderStatus.ACTIVE,
  };
  const tx = {
    $queryRaw: async (query: any) => {
      const text = query.strings?.join('') ?? String(query);
      if (text.includes('FROM "User"')) {
        return [
          { id: providerUserId, status: UserStatus.ACTIVE },
          { id: requesterId, status: UserStatus.ACTIVE },
        ].sort((left, right) => left.id.localeCompare(right.id));
      }
      if (text.includes('FROM "WeddingPlan"')) return [{ id: weddingPlanId }];
      if (text.includes('FROM "Provider"')) return [{ id: providerId }];
      if (text.includes('FROM "Conversation"')) return [{ id: conversationId }];
      if (text.includes('FROM "QuoteRequest"')) return [{ id: quoteRequestId }];
      throw new Error(`Unexpected provider quote lock: ${text}`);
    },
    provider: {
      findUnique: async () => provider,
    },
    weddingPlan: {
      findUnique: async () => ({ status: WeddingPlanStatus.ARCHIVED }),
    },
    quoteRequest: {
      findUnique: async () => ({
        providerId,
        userId: requesterId,
        weddingPlanId,
        conversationId,
      }),
      findFirst: async () => ({
        id: quoteRequestId,
        conversationId,
        userId: requesterId,
        providerId,
        weddingPlanId,
        weddingPlan: {
          id: weddingPlanId,
          status: WeddingPlanStatus.ARCHIVED,
        },
        status: QuoteRequestStatus.SENT,
      }),
      updateMany: async () => {
        quoteWrites += 1;
        return { count: 1 };
      },
    },
  };
  const service = new ProviderDashboardService(
    {
      provider: {
        findUnique: async () => provider,
      },
      $transaction: async (operation: (client: any) => Promise<unknown>) =>
        operation(tx),
    } as any,
    {} as any,
    {} as any, lifecycle,
  );

  await assert.rejects(
    () =>
      service.updateQuoteRequestStatus(providerUser, quoteRequestId, {
        status: QuoteRequestStatus.VIEWED,
      }),
    assertArchivedReadOnly,
  );
  assert.equal(quoteWrites, 0);
});

test('an active provider cannot create or update an offer for an archived plan', async () => {
  const provider = {
    id: providerId,
    userId: providerUserId,
    businessName: 'Provider',
    status: ProviderStatus.ACTIVE,
  };
  const archivedQuote = {
    id: quoteRequestId,
    conversationId,
    userId: requesterId,
    providerId,
    weddingPlanId,
    weddingPlan: {
      id: weddingPlanId,
      status: WeddingPlanStatus.ARCHIVED,
    },
    status: QuoteRequestStatus.SENT,
  };
  let offerWrites = 0;
  const tx = {
    $queryRaw: async (query: any) => {
      const text = query.strings?.join('') ?? String(query);
      if (text.includes('FROM "User"')) {
        return [
          { id: providerUserId, status: UserStatus.ACTIVE },
          { id: requesterId, status: UserStatus.ACTIVE },
        ].sort((left, right) => left.id.localeCompare(right.id));
      }
      if (text.includes('FROM "WeddingPlan"')) return [{ id: weddingPlanId }];
      if (text.includes('FROM "Provider"')) return [{ id: providerId }];
      if (text.includes('FROM "Conversation"')) return [{ id: conversationId }];
      if (text.includes('FROM "QuoteRequest"')) return [{ id: quoteRequestId }];
      if (text.includes('FROM "QuoteOffer"')) {
        return [{ id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' }];
      }
      throw new Error(`Unexpected provider offer lock: ${text}`);
    },
    provider: {
      findUnique: async () => provider,
    },
    weddingPlan: {
      findUnique: async () => ({ status: WeddingPlanStatus.ARCHIVED }),
    },
    quoteRequest: {
      findUnique: async () => ({
        providerId,
        userId: requesterId,
        weddingPlanId,
        conversationId,
      }),
      findFirst: async () => archivedQuote,
    },
    quoteOffer: {
      findUnique: async () => ({
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        providerId,
        quoteRequest: {
          userId: requesterId,
          weddingPlanId,
          conversationId,
        },
      }),
      findFirst: async ({ where }: any) => {
        if (where.quoteRequestId) return null;
        return {
          id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          providerId,
          quoteRequestId,
          status: 'PENDING',
          quoteRequest: {
            status: QuoteRequestStatus.RESPONDED,
            weddingPlan: archivedQuote.weddingPlan,
          },
        };
      },
      create: async () => {
        offerWrites += 1;
        throw new Error('offer creation should not be reached');
      },
      updateMany: async () => {
        offerWrites += 1;
        throw new Error('offer update should not be reached');
      },
    },
  };
  const service = new ProviderDashboardService(
    {
      provider: {
        findUnique: async () => provider,
      },
      $transaction: async (operation: (client: any) => Promise<unknown>) =>
        operation(tx),
    } as any,
    {} as any,
    {} as any, lifecycle,
  );

  await assert.rejects(
    () =>
      service.createQuoteOffer(providerUser, quoteRequestId, {
        message: 'Offer',
        amount: '100',
        currency: 'YER',
      }),
    assertArchivedReadOnly,
  );
  await assert.rejects(
    () =>
      service.updateQuoteOffer(
        providerUser,
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        { message: 'Updated offer' },
      ),
    assertArchivedReadOnly,
  );
  assert.equal(offerWrites, 0);
});

test('an archived plan conversation remains readable but rejects new messages', async () => {
  const conversation = {
    id: conversationId,
    scope: ConversationScope.PLAN,
    weddingPlanId,
    accountRequesterUserId: null,
    providerId,
    provider: {
      id: providerId,
      userId: providerUserId,
      status: ProviderStatus.ACTIVE,
      businessName: 'Provider',
      logoUrl: null,
      user: {
        id: providerUserId,
        name: providerUser.name,
        appName: null,
        role: UserRole.PROVIDER,
        appRole: AppRole.PROVIDER,
        avatarUrl: null,
        appAvatarUrl: null,
      },
    },
    weddingPlan: {
      id: weddingPlanId,
      title: archivedPlan.title,
      ownerUserId: requesterId,
      status: WeddingPlanStatus.ARCHIVED,
      sharedMembers: [],
    },
    accountRequester: null,
    participants: [
      {
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        conversationId,
        userId: providerUserId,
        lastReadAt: null,
        mutedAt: null,
        revokedAt: null,
        createdAt: now,
        updatedAt: now,
        user: {
          id: providerUserId,
          name: providerUser.name,
          appName: null,
          role: UserRole.PROVIDER,
          appRole: AppRole.PROVIDER,
          avatarUrl: null,
          appAvatarUrl: null,
        },
      },
    ],
    quoteRequests: [],
    messages: [],
    _count: { quoteRequests: 0 },
    lastActivityAt: now,
    customerSideBlockedAt: null,
    customerSideBlockedById: null,
    providerSideBlockedAt: null,
    closedAt: null,
    createdAt: now,
    updatedAt: now,
  };
  let transactionStarts = 0;
  const service = new ConversationsService(
    {
      conversation: {
        findUnique: async () => conversation,
        findUniqueOrThrow: async () => conversation,
      },
      conversationParticipant: {
        createMany: async () => ({ count: 1 }),
        updateMany: async () => ({ count: 1 }),
      },
      $queryRaw: async () => [],
      $transaction: async () => {
        transactionStarts += 1;
        throw new Error('message transaction should not start');
      },
    } as any,
    {} as any,
    {
      revokeConversationAccess: () => undefined,
    } as any,
    {} as any,
    {} as any,
  );

  const historical = await service.get(providerUser, conversationId);
  assert.equal(historical.id, conversationId);
  assert.equal(historical.canSend, false);
  await assert.rejects(
    () =>
      service.send(providerUser, conversationId, {
        body: 'New message',
      }),
    assertArchivedReadOnly,
  );
  assert.equal(transactionStarts, 0);
});
