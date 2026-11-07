import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  ConversationScope,
  Prisma,
  ProviderStatus,
} from '@prisma/client';
import {
  type ConversationRecord,
  ConversationRelationsService,
  conversationOwnInclude,
  type QuoteRequestWithRequester,
} from './conversation-relations';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { runSerializableTransaction } from '../platform/database/serializable-transaction';
import {
  MEDIA_STORAGE_PORT,
  MediaStoragePort,
} from '../modules/media/public/media-storage.port';
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from '../modules/notifications/public/notifications.port';
import { OutboxEventTypes } from '../platform/outbox/outbox.constants';
import { OutboxService } from '../platform/outbox/outbox.service';
import { PrismaService } from '../platform/database/prisma.service';
import {
  assertProviderOperational,
  isProviderOperational,
} from '../modules/marketplace/public/provider-access-policy';
import { chatMessageNotification } from './chat-notifications';
import { quoteOfferVersionView } from '../modules/marketplace/public/quote-offer-versions';
import {
  assertWeddingPlanWritable,
  isWeddingPlanWritable,
} from '../modules/collaboration/public/collaboration-permission.port';
import {
  ApplicationAvatarSource,
  applicationDisplayName,
  toApplicationUserSummary,
} from '../shared-kernel/privacy/application-user-identity';
import {
  isLiveAccount,
  listDeletionPendingUserIds,
  lockUserLifecycleRowsInTransaction,
} from '../modules/identity/public/user-lifecycle-lock';
import {
  hasJoinedProvider,
  isActiveConversationParticipant,
  MESSAGES_PER_MINUTE,
  messageRateLimited,
  normalizeMessageBody,
  normalizeMessagePageSize,
  normalizeReportReason,
} from './conversation-policy';
import { ConversationRealtimePublisher } from './conversation-realtime.publisher';
import { SendMessageDto } from './dto/send-message.dto';
import {
  ConversationsRepository,
  type ConversationAccessFilter,
} from '../modules/messaging/infrastructure/conversations.repository';

// The conversations the user may open: as the account of an active
// provider, as the account requester, or through a plan the user owns or
// still manages providers for. Ownership and membership are planning's and
// collaboration's rows, read through their ports and applied to the
// conversation table by id (the shape is declared so the ownership scan can
// prove it).
type ConversationSide = 'CUSTOMER' | 'PROVIDER';

interface ConversationAccess {
  side: ConversationSide;
  canManageProviders: boolean;
  canViewMoney: boolean;
  canManageMoney: boolean;
  canViewContact: boolean;
}

interface ConversationMutationAccess {
  conversation: ConversationRecord;
  access: ConversationAccess;
  activeLifecycleUserIds: ReadonlySet<string>;
}

interface ConversationMutationLockOptions {
  conversation: 'SHARE' | 'UPDATE';
  participants: 'SHARE' | 'UPDATE';
  lockRecipients?: boolean;
}

interface TimelineCursor {
  occurredAt: string;
  key: string;
}

/**
 * B-14: a customer-side person as the provider side reads them: the name
 * (p16 and p19 draw «محمد الحمدي») with no picture, so the app draws the
 * initial. Messages carry it to both sides, so a customer sender is shown
 * this way to everyone.
 */
function customerSummaryForProvider(user: ApplicationAvatarSource & { id: string }) {
  return {
    id: user.id,
    name: applicationDisplayName(user),
    avatarUrl: null,
  };
}

/**
 * B-14: who the provider talks to in a plan's conversation: the customer's
 * first name and the wedding's day. No phone, no picture, no surname, and
 * not the plan's title (D75, RA-BE-80): `weddingLabel` stays for older
 * phones (D93) and is always null.
 */
function planCustomerForProvider(quote: QuoteRequestWithRequester) {
  const firstName =
    applicationDisplayName(quote.user).trim().split(/\s+/u)[0] || null;
  return {
    firstName,
    weddingLabel: null,
    eventDate: quote.eventDate,
  };
}

@Injectable()
export class ConversationsService {
  private readonly repository = new ConversationsRepository();
  constructor(
    private readonly prisma: PrismaService,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
    private readonly realtime: ConversationRealtimePublisher,
    @Inject(MEDIA_STORAGE_PORT)
    private readonly mediaStorage: MediaStoragePort,
    private readonly outbox: OutboxService,
    private readonly relations: ConversationRelationsService,
  ) {}

  async getForQuote(currentUser: AuthenticatedUser, quoteRequestId: string) {
    const conversationId =
      await this.relations.quotes.getQuoteRequestConversationId(
        this.prisma,
        quoteRequestId,
      );
    if (!conversationId) throw new NotFoundException('Quote request not found');
    return this.findConversation(currentUser, conversationId);
  }

  async authorize(currentUser: AuthenticatedUser, conversationId: string) {
    return runSerializableTransaction(this.prisma, async (tx) => {
      await this.assertActiveAccessInTransaction(
        tx,
        currentUser,
        conversationId,
        {
          conversation: 'SHARE',
          participants: 'SHARE',
        },
      );
      return { conversationId };
    });
  }

  async get(currentUser: AuthenticatedUser, conversationId: string) {
    return this.findConversation(currentUser, conversationId);
  }

  async list(currentUser: AuthenticatedUser, cursor?: string, limitValue?: string) {
    const limit = normalizeMessagePageSize(limitValue);
    const accessWhere = await this.accessWhere(currentUser.id);
    await this.assertConversationCursor(accessWhere, cursor);
    const candidates = await this.repository.listPage(this.prisma, accessWhere, cursor, limit);
    const hasMore = candidates.length > limit;
    const page = candidates.slice(0, limit);
    await this.ensureParticipants(
      page.map((conversation) => ({
        conversationId: conversation.id,
        userId: currentUser.id,
      })),
    );
    const ids = page.map((conversation) => conversation.id);
    const conversations = ids.length
      ? await this.relations.attachConversationRelations(
          this.prisma,
          await this.repository.listByIds(this.prisma, ids),
        )
      : [];
    const unread = await this.unreadCounts(currentUser.id, ids);
    return {
      items: await Promise.all(
        conversations.map((conversation) =>
          this.toConversationResponse(
            currentUser.id,
            conversation,
            unread.get(conversation.id) ?? 0,
          ),
        ),
      ),
      nextCursor: hasMore ? (page[page.length - 1]?.id ?? null) : null,
    };
  }

  async quoteRequests(currentUser: AuthenticatedUser, conversationId: string) {
    const { access } = await this.assertAccess(currentUser, conversationId);
    // The quote requests are marketplace's rows, their requester identity's.
    const quoteRequests = await this.relations.attachQuoteRequesters(
      this.prisma,
      await this.relations.quotes.listConversationQuoteRequests(
        this.prisma,
        conversationId,
      ),
    );
    return {
      items: quoteRequests.map((quote) => this.toQuoteRequestResponse(quote, access)),
    };
  }

  async messages(
    currentUser: AuthenticatedUser,
    conversationId: string,
    cursor?: string,
    limitValue?: string,
  ) {
    const { conversation } = await this.assertAccess(currentUser, conversationId);
    const limit = normalizeMessagePageSize(limitValue);
    await this.assertMessageCursor(conversationId, cursor);
    const messages = await this.relations.attachMessageSenders(
      this.prisma,
      await this.repository.listMessages(this.prisma, conversationId, cursor, limit),
    );
    const hasMore = messages.length > limit;
    const page = messages.slice(0, limit);
    const providerUserId = conversation.provider.userId;
    return {
      items: await Promise.all(
        page.reverse().map((message) => this.toMessageResponse(message, providerUserId)),
      ),
      nextCursor: hasMore ? (page[0]?.id ?? null) : null,
    };
  }

  async timeline(
    currentUser: AuthenticatedUser,
    conversationId: string,
    cursorValue?: string,
    limitValue?: string,
  ) {
    const { conversation } = await this.assertAccess(currentUser, conversationId);
    const providerUserId = conversation.provider.userId;
    const limit = normalizeMessagePageSize(limitValue);
    const cursor = this.decodeTimelineCursor(cursorValue);
    const before = cursor ? new Date(cursor.occurredAt) : undefined;
    const [messages, events, expiredOffers] = await Promise.all([
      this.relations.attachMessageSenders(
        this.prisma,
        await this.repository.listTimelineMessages(this.prisma, conversationId, before, limit),
      ),
      this.repository.listTimelineEvents(this.prisma, conversationId, before, limit),
      // The lapsed pending offers are marketplace's rows.
      this.relations.quotes.listExpiredPendingOffersForConversation(
        this.prisma,
        conversationId,
        before ?? new Date(),
        limit + 1,
      ),
    ]);
    const merged = [
      ...messages.map((message) => ({
        kind: 'MESSAGE' as const,
        key: `M:${message.id}`,
        occurredAt: message.createdAt,
        source: message,
      })),
      ...events.map((event) => ({
        kind: 'EVENT' as const,
        key: `E:${event.id}`,
        occurredAt: event.occurredAt,
        source: event,
      })),
      ...expiredOffers
        .filter((offer) => offer.validUntil !== null)
        .map((offer) => ({
          kind: 'EVENT' as const,
          key: `V:quote-offer-expired:${offer.id}`,
          occurredAt: offer.validUntil!,
          source: {
            id: `quote-offer-expired:${offer.id}`,
            conversationId,
            quoteRequestId: offer.quoteRequestId,
            quoteOfferId: offer.id,
            actorUserId: null,
            type: 'QUOTE_OFFER_EXPIRED' as const,
            occurredAt: offer.validUntil!,
            dedupeKey: `virtual:quote-offer:${offer.id}:expired`,
            data: null,
            createdAt: offer.validUntil!,
          },
        })),
    ]
      .filter((item) => !cursor || this.timelineItemBefore(item, cursor))
      .sort((left, right) => this.compareTimelineItems(left, right));
    const hasMore = merged.length > limit;
    const page = merged.slice(0, limit);
    const items = await Promise.all(
      page
        .map(async (item) =>
          item.kind === 'MESSAGE'
            ? {
                kind: 'MESSAGE',
                occurredAt: item.occurredAt,
                message: await this.toMessageResponse(item.source, providerUserId),
              }
            : {
                kind: 'EVENT',
                occurredAt: item.occurredAt,
                event: item.source,
              },
        )
        .reverse(),
    );
    const oldest = page[page.length - 1];
    return {
      items,
      nextCursor:
        hasMore && oldest
          ? this.encodeTimelineCursor({
              occurredAt: oldest.occurredAt.toISOString(),
              key: oldest.key,
            })
          : null,
    };
  }

  async send(currentUser: AuthenticatedUser, conversationId: string, dto: SendMessageDto) {
    const { conversation, access } = await this.assertAccess(
      currentUser,
      conversationId,
      false,
    );
    this.assertConversationSendable(
      conversation,
      access.side === 'PROVIDER',
    );
    const attachments = dto.attachments ?? [];
    if (attachments.length > 4) {
      throw new BadRequestException('A message can contain up to 4 attachments');
    }
    if (
      new Set(attachments.map((attachment) => attachment.attachmentRef)).size !==
      attachments.length
    ) {
      throw new BadRequestException('A message cannot contain the same attachment more than once');
    }
    const verifiedAttachments = await Promise.all(
      attachments.map((attachment) =>
        this.mediaStorage.verifyUpload(currentUser, attachment.attachmentRef, 'chat-image'),
      ),
    );
    const signedDownloads = new Map(
      await Promise.all(
        verifiedAttachments.map(async (attachment) => [
          attachment.key,
          await this.mediaStorage.createDownloadUrl(attachment.key),
        ] as const),
      ),
    );
    const body = normalizeMessageBody(dto.body);
    const message = await runSerializableTransaction(this.prisma, async (tx) => {
      const {
        conversation: current,
        access,
        activeLifecycleUserIds,
      } =
        await this.assertActiveAccessInTransaction(
          tx,
          currentUser,
          conversationId,
          {
            conversation: 'UPDATE',
            participants: 'UPDATE',
            lockRecipients: true,
          },
        );
      this.assertConversationSendable(current);
      const now = new Date();
      if (
        (await this.repository.countMessagesSentSince(
          tx,
          currentUser.id,
          new Date(now.getTime() - 60_000),
        )) >= MESSAGES_PER_MINUTE
      ) {
        throw messageRateLimited();
      }
      const recipientIds = this.messageRecipientIds(
        current,
        access.side,
        currentUser.id,
      ).filter(
        (recipientId) =>
          activeLifecycleUserIds.has(recipientId) &&
          isActiveConversationParticipant(
            current.participants,
            recipientId,
          ),
      );
      const [created] = await this.relations.attachMessageSenders(tx, [
        await this.repository.createMessage(
          tx, conversationId, currentUser.id, body, verifiedAttachments,
        ),
      ]);
      for (const attachment of verifiedAttachments) {
        const createdAttachment = created.attachments.find(
          (item) => item.storageKey === attachment.key,
        );
        if (!createdAttachment) {
          throw new ConflictException('Verified attachment could not be bound to the message');
        }
        await this.mediaStorage.consumeUpload(
          currentUser,
          attachment.key,
          'chat-image',
          { type: 'CHAT_ATTACHMENT', id: createdAttachment.id },
          tx,
        );
      }
      await this.repository.touchConversation(tx, conversationId, now);
      const senderState = await this.repository.markParticipantRead(
        tx, conversationId, currentUser.id, now,
      );
      if (senderState.count !== 1) {
        throw new NotFoundException('Conversation not found');
      }
      await this.outbox.enqueue(tx, {
        type: OutboxEventTypes.conversationMessageAvailable,
        aggregateType: 'conversation',
        aggregateId: conversationId,
        payload: { conversationId, messageId: created.id },
      });
      await this.outbox.enqueue(tx, {
        type: OutboxEventTypes.conversationActivityAvailable,
        aggregateType: 'conversation',
        aggregateId: conversationId,
        payload: {
          conversationId,
          messageId: created.id,
          activityKind: 'MESSAGE',
        },
      });
      if (recipientIds.length > 0) {
        // Whether a recipient still accepts provider messages is
        // notifications' row, read through its port on this transaction.
        const [preferences, participantStates] = await Promise.all([
          this.notifications.listProviderMessagePreferences(tx, recipientIds),
          this.repository.recipientStates(tx, conversationId, recipientIds),
        ]);
        const preferenceByUser = new Map(
          preferences.map((preference) => [preference.userId, preference]),
        );
        const participantByUser = new Map(
          participantStates.map((participant) => [participant.userId, participant]),
        );
        for (const recipientId of recipientIds) {
          if (preferenceByUser.get(recipientId)?.providerMessagesEnabled === false) continue;
          const participantState = participantByUser.get(recipientId);
          if (!participantState || participantState.mutedAt) continue;
          await this.notifications.createNotificationInTransaction(
            tx,
            chatMessageNotification({
              recipientId,
              weddingPlanId: current.weddingPlanId,
              conversationId,
              providerId: current.providerId,
              recipientIsProvider: current.provider.userId === recipientId,
              messageId: created.id,
            }),
          );
        }
      }
      return created;
    });

    // The room holds both sides: the message carries no customer picture.
    const response = await this.toMessageResponse(
      message,
      conversation.provider.userId,
      signedDownloads,
    );
    this.realtime.message(conversationId, response);
    this.realtime.activityAvailable(conversationId, {
      conversationId,
      messageId: message.id,
      activityKind: 'MESSAGE',
    });
    return response;
  }

  async downloadAttachment(
    currentUser: AuthenticatedUser,
    conversationId: string,
    attachmentId: string,
  ) {
    await this.assertAccess(currentUser, conversationId);
    const attachment = await this.repository.findAttachment(
      this.prisma, conversationId, attachmentId,
    );
    if (!attachment) throw new NotFoundException('Attachment not found');
    const access = await this.mediaStorage.createDownloadUrl(attachment.storageKey);
    return {
      url: access.downloadUrl,
      expiresInSeconds: access.expiresInSeconds,
      expiresAt: access.expiresAt,
    };
  }

  async markRead(currentUser: AuthenticatedUser, conversationId: string) {
    const lastReadAt = new Date();
    await runSerializableTransaction(this.prisma, async (tx) => {
      await this.assertActiveAccessInTransaction(
        tx,
        currentUser,
        conversationId,
        {
          conversation: 'SHARE',
          participants: 'UPDATE',
        },
      );
      const updated = await this.repository.markParticipantRead(
        tx, conversationId, currentUser.id, lastReadAt,
      );
      if (updated.count !== 1) {
        throw new NotFoundException('Conversation not found');
      }
    });
    const receipt = { conversationId, lastReadAt, userId: currentUser.id };
    this.realtime.read(conversationId, receipt);
    return receipt;
  }

  async setMuted(currentUser: AuthenticatedUser, conversationId: string, enabled: boolean) {
    return runSerializableTransaction(this.prisma, async (tx) => {
      await this.assertActiveAccessInTransaction(
        tx,
        currentUser,
        conversationId,
        {
          conversation: 'SHARE',
          participants: 'UPDATE',
        },
      );
      const mutedAt = enabled ? new Date() : null;
      const participant = await this.repository.setParticipantMuted(
        tx, conversationId, currentUser.id, mutedAt,
      );
      if (participant.count !== 1) {
        throw new NotFoundException('Conversation not found');
      }
      return { conversationId, muted: mutedAt !== null };
    });
  }

  async setBlocked(currentUser: AuthenticatedUser, conversationId: string, enabled: boolean) {
    return runSerializableTransaction(this.prisma, async (tx) => {
      const { access } = await this.assertActiveAccessInTransaction(
        tx,
        currentUser,
        conversationId,
        {
          conversation: 'UPDATE',
          participants: 'SHARE',
        },
      );
      const conversation = await this.repository.setConversationBlocked(
        tx, conversationId, currentUser.id, access.side === 'PROVIDER', enabled,
      );
      return {
        conversationId,
        blocked:
          conversation.customerSideBlockedAt !== null ||
          conversation.providerSideBlockedAt !== null,
        blockedByMe:
          access.side === 'PROVIDER'
            ? conversation.providerSideBlockedAt !== null
            : conversation.customerSideBlockedById === currentUser.id,
      };
    });
  }

  async report(currentUser: AuthenticatedUser, conversationId: string, reasonValue: string) {
    const reason = normalizeReportReason(reasonValue);
    return runSerializableTransaction(this.prisma, async (tx) => {
      await this.assertActiveAccessInTransaction(
        tx,
        currentUser,
        conversationId,
        {
          conversation: 'SHARE',
          participants: 'SHARE',
        },
      );
      return this.repository.reportConversation(tx, conversationId, currentUser.id, reason);
    });
  }

  private async findConversation(currentUser: AuthenticatedUser, conversationId: string) {
    const { conversation } = await this.assertAccess(currentUser, conversationId);
    const unread = await this.unreadCounts(currentUser.id, [conversationId]);
    return this.toConversationResponse(
      currentUser.id,
      conversation,
      unread.get(conversationId) ?? 0,
    );
  }

  private async assertAccess(
    currentUser: AuthenticatedUser,
    conversationId: string,
    ensureCurrentParticipant = true,
  ) {
    let conversation = await this.findConversationRecord(
      this.prisma,
      conversationId,
    );
    if (!conversation) throw new NotFoundException('Conversation not found');
    let access = this.accessFor(conversation, currentUser.id);
    if (!access) {
      await this.repository.revokeParticipant(
        this.prisma, conversationId, currentUser.id, new Date(),
      );
      this.realtime.revokeConversationAccess(currentUser.id, [conversationId]);
      throw new NotFoundException('Conversation not found');
    }
    if (ensureCurrentParticipant) {
      await this.ensureParticipants([
        { conversationId, userId: currentUser.id },
      ]);
      const refreshed = await this.findConversationRecord(
        this.prisma,
        conversationId,
      );
      if (!refreshed) {
        throw new NotFoundException('Conversation not found');
      }
      conversation = refreshed;
      access = this.accessFor(conversation, currentUser.id);
      if (
        !access ||
        !isActiveConversationParticipant(
          conversation.participants,
          currentUser.id,
        )
      ) {
        await this.repository.revokeParticipant(
          this.prisma, conversationId, currentUser.id, new Date(),
        );
        this.realtime.revokeConversationAccess(currentUser.id, [
          conversationId,
        ]);
        throw new NotFoundException('Conversation not found');
      }
    }
    if (
      conversation.scope === ConversationScope.PLAN &&
      conversation.weddingPlan &&
      (await this.plansOpenTo(currentUser.id, [conversation.weddingPlan])).length === 0
    ) {
      throw new NotFoundException('Conversation not found');
    }
    return { conversation, access };
  }

  /**
   * D63 (w06, RA-BE-76): the plans this account may enter: a plan whose owner
   * waits out the account's deletion is closed to everyone but the owner, its
   * conversations as every other section of it (`permission.service.ts`).
   */
  private async plansOpenTo<T extends { id: string; ownerUserId: string }>(
    currentUserId: string,
    plans: readonly T[],
  ): Promise<T[]> {
    const others = plans.filter((plan) => plan.ownerUserId !== currentUserId);
    if (others.length === 0) return [...plans];
    const waiting = await listDeletionPendingUserIds(
      this.prisma,
      others.map((plan) => plan.ownerUserId),
    );
    return plans.filter(
      (plan) => plan.ownerUserId === currentUserId || !waiting.has(plan.ownerUserId),
    );
  }

  private async assertActiveAccessInTransaction(
    tx: Prisma.TransactionClient,
    currentUser: AuthenticatedUser,
    conversationId: string,
    options: ConversationMutationLockOptions,
  ): Promise<ConversationMutationAccess> {
    // This first read discovers immutable relation ids only. It intentionally
    // takes no row lock; all locks below follow the global lifecycle order:
    // User(s) -> WeddingPlan -> SharedMember -> Provider -> Conversation ->
    // ConversationParticipant.
    const identity = await this.relations.conversationIdentity(
      tx,
      conversationId,
    );
    if (!identity) {
      throw new NotFoundException('Conversation not found');
    }

    const isProvider = identity.provider.userId === currentUser.id;
    const isPlanOwner =
      identity.scope === ConversationScope.PLAN &&
      identity.weddingPlan?.ownerUserId === currentUser.id;
    const lifecycleUserIds = new Set<string>([currentUser.id]);
    const recipientUserIds = new Set<string>();
    if (options.lockRecipients) {
      if (isProvider) {
        if (
          identity.scope === ConversationScope.ACCOUNT &&
          identity.accountRequesterUserId
        ) {
          recipientUserIds.add(identity.accountRequesterUserId);
        } else if (identity.weddingPlan) {
          recipientUserIds.add(identity.weddingPlan.ownerUserId);
          for (const member of identity.weddingPlan.sharedMembers) {
            if (member.canManageProviders) {
              recipientUserIds.add(member.userId);
            }
          }
        }
      } else if (identity.provider.userId) {
        recipientUserIds.add(identity.provider.userId);
      }
      for (const userId of recipientUserIds) {
        lifecycleUserIds.add(userId);
      }
    }
    const planOwnerUserId =
      identity.scope === ConversationScope.PLAN
        ? (identity.weddingPlan?.ownerUserId ?? null)
        : null;
    if (planOwnerUserId) lifecycleUserIds.add(planOwnerUserId);
    const lockedUsers = await lockUserLifecycleRowsInTransaction(
      tx,
      [...lifecycleUserIds],
    );
    // D63 (RA-BE-76): live means active and not waiting out a deletion, the
    // one rule every section reads; nobody waiting is told of a message.
    const activeLifecycleUserIds = new Set(
      lockedUsers.filter(isLiveAccount).map((user) => user.id),
    );
    if (!activeLifecycleUserIds.has(currentUser.id)) {
      throw new NotFoundException('Conversation not found');
    }
    // D63 (w06): a plan whose owner waits out the deletion is closed to
    // everyone else, its conversations as every other section of it.
    if (
      planOwnerUserId &&
      planOwnerUserId !== currentUser.id &&
      !activeLifecycleUserIds.has(planOwnerUserId)
    ) {
      throw new NotFoundException('Conversation not found');
    }

    if (identity.weddingPlanId) {
      // The plan row is planning's: locked for share there.
      const planLock = await this.relations.plans.lockPlanRowForShareInTransaction(
        tx,
        identity.weddingPlanId,
      );
      if (planLock.length !== 1) {
        throw new NotFoundException('Conversation not found');
      }
    }

    const memberUserIds = new Set<string>();
    if (
      identity.weddingPlanId &&
      !isProvider &&
      !isPlanOwner
    ) {
      memberUserIds.add(currentUser.id);
    }
    if (
      options.lockRecipients &&
      isProvider &&
      identity.weddingPlanId &&
      identity.weddingPlan
    ) {
      for (const member of identity.weddingPlan.sharedMembers) {
        if (member.canManageProviders) {
          memberUserIds.add(member.userId);
        }
      }
    }
    if (identity.weddingPlanId && memberUserIds.size > 0) {
      // The membership rows are collaboration's: locked for share there.
      await this.relations.permissions.lockMembershipsForShareInTransaction(
        tx,
        identity.weddingPlanId,
        [...memberUserIds],
      );
    }

    // Keep the provider lifecycle stable through every conversation mutation.
    // If a suspension commits first, the serializable retry observes the
    // non-active status before any message, notification, or outbox write.
    const providerLock = await this.relations.providers.lockProviderRowsForShareInTransaction(
      tx,
      [identity.provider.id],
    );
    if (providerLock.length !== 1) {
      throw new NotFoundException('Conversation not found');
    }
    const provider = await this.relations.providers.getProvider(
      tx,
      identity.provider.id,
    );
    if (!provider) {
      throw new NotFoundException('Conversation not found');
    }
    if (provider.userId !== identity.provider.userId) {
      throw new NotFoundException('Conversation not found');
    }

    if (isProvider) {
      assertProviderOperational(provider);
    }

    const conversationLock = await this.repository.lockConversation(
      tx, conversationId, options.conversation,
    );
    if (conversationLock.length !== 1) {
      throw new NotFoundException('Conversation not found');
    }

    await this.repository.ensureParticipants(tx, [{ conversationId, userId: currentUser.id }]);
    const participantUserIds = new Set<string>([currentUser.id]);
    if (options.lockRecipients) {
      for (const recipientId of recipientUserIds) {
        participantUserIds.add(recipientId);
      }
    }
    const sortedParticipantUserIds = [...participantUserIds].sort();
    await this.repository.lockParticipants(
      tx, conversationId, sortedParticipantUserIds, options.participants,
    );

    const conversation = await this.findConversationRecord(tx, conversationId);
    const access = conversation
      ? this.accessFor(conversation, currentUser.id)
      : null;
    if (
      !conversation ||
      conversation.providerId !== identity.provider.id ||
      conversation.weddingPlanId !== identity.weddingPlanId ||
      conversation.scope !== identity.scope ||
      conversation.accountRequesterUserId !==
        identity.accountRequesterUserId ||
      !access ||
      !isActiveConversationParticipant(
        conversation.participants,
        currentUser.id,
      )
    ) {
      throw new NotFoundException('Conversation not found');
    }
    return { conversation, access, activeLifecycleUserIds };
  }

  private assertConversationSendable(
    conversation: ConversationRecord,
    allowProviderSelfJoin = false,
  ): void {
    assertProviderOperational(conversation.provider);
    if (conversation.weddingPlan) {
      assertWeddingPlanWritable(conversation.weddingPlan);
    }
    // RA-BE-95: each refusal with its code and in Arabic: the phone hands a
    // waiting message back to its box with this reason.
    if (conversation.closedAt) {
      throw new ConflictException({
        code: 'CONVERSATION_CLOSED',
        message: 'هذي المحادثة انقفلت، ما تستقبل رسائل.',
      });
    }
    if (
      !allowProviderSelfJoin &&
      !hasJoinedProvider(
        conversation.provider.userId,
        conversation.participants,
      )
    ) {
      throw new ConflictException({
        code: 'PROVIDER_NOT_JOINED',
        message: 'المزود ما دخل المحادثة لسا.',
      });
    }
    if (this.isBlocked(conversation)) {
      throw new ConflictException({
        code: 'CONVERSATION_BLOCKED',
        message: 'المراسلة في هذي المحادثة موقوفة.',
      });
    }
  }

  private accessFor(
    conversation: ConversationRecord,
    currentUserId: string,
  ): ConversationAccess | null {
    if (conversation.provider.userId === currentUserId) {
      assertProviderOperational(conversation.provider);
      return {
        side: 'PROVIDER',
        canManageProviders: false,
        canViewMoney: true,
        canManageMoney: false,
        canViewContact: true,
      };
    }
    if (
      conversation.scope === ConversationScope.ACCOUNT &&
      conversation.accountRequesterUserId === currentUserId
    ) {
      return {
        side: 'CUSTOMER',
        canManageProviders: true,
        canViewMoney: true,
        canManageMoney: true,
        canViewContact: true,
      };
    }
    if (conversation.scope !== ConversationScope.PLAN || !conversation.weddingPlan) {
      return null;
    }
    if (conversation.weddingPlan.ownerUserId === currentUserId) {
      return {
        side: 'CUSTOMER',
        canManageProviders: true,
        canViewMoney: true,
        canManageMoney: true,
        canViewContact: true,
      };
    }
    const member = conversation.weddingPlan.sharedMembers.find(
      (candidate) => candidate.userId === currentUserId,
    );
    if (!member?.canManageProviders) return null;
    const canManageMoney = member.canManageMoney;
    return {
      side: 'CUSTOMER',
      canManageProviders: true,
      canViewMoney: member.canViewMoney || canManageMoney,
      canManageMoney,
      canViewContact: true,
    };
  }

  private async accessWhere(
    currentUserId: string,
  ): Promise<ConversationAccessFilter> {
    const provider = await this.relations.providers.getProviderByUserId(
      this.prisma,
      currentUserId,
    );
    const ownedPlanIds = await this.relations.plans.listOwnedPlanIds(
      this.prisma,
      currentUserId,
    );
    const managedPlanIds = (
      await this.relations.permissions.listMemberships(this.prisma, currentUserId)
    )
      .filter((membership) => membership.canManageProviders)
      .map((membership) => membership.weddingPlanId);
    const managingPlanIds = (
      await this.plansOpenTo(
        currentUserId,
        managedPlanIds.length > 0
          ? await this.relations.plans.getPlans(this.prisma, managedPlanIds)
          : [],
      )
    ).map((plan) => plan.id);
    return {
      providerIds: provider && provider.status === ProviderStatus.ACTIVE ? [provider.id] : [],
      accountRequesterUserId: currentUserId,
      planIds: [...new Set([...ownedPlanIds, ...managingPlanIds])],
    };
  }

  private async findConversationRecord(
    client: Prisma.TransactionClient,
    conversationId: string,
  ): Promise<ConversationRecord | null> {
    const row = await this.repository.findConversation(client, conversationId);
    if (!row) return null;
    const [conversation] = await this.relations.attachConversationRelations(
      client,
      [row],
    );
    return conversation;
  }

  private async ensureParticipants(
    values: Array<{ conversationId: string; userId: string }>,
  ): Promise<void> {
    const unique = [
      ...new Map(values.map((value) => [`${value.conversationId}:${value.userId}`, value])).values(),
    ];
    if (unique.length === 0) return;
    await this.repository.ensureParticipants(this.prisma, unique);
  }

  private async unreadCounts(currentUserId: string, conversationIds: string[]) {
    if (conversationIds.length === 0) return new Map<string, number>();
    const rows = await this.repository.unreadCounts(this.prisma, currentUserId, conversationIds);
    return new Map(rows.map((row) => [row.conversationId, Number(row.count)]));
  }

  private async assertConversationCursor(
    accessWhere: ConversationAccessFilter,
    cursor?: string,
  ) {
    if (!cursor) return;
    const conversation = await this.repository.findAccessibleCursor(
      this.prisma, accessWhere, cursor,
    );
    if (!conversation) throw new BadRequestException('Invalid conversation cursor');
  }

  private async assertMessageCursor(conversationId: string, cursor?: string) {
    if (!cursor) return;
    const message = await this.repository.findMessageCursor(
      this.prisma, conversationId, cursor,
    );
    if (!message) throw new BadRequestException('Invalid message cursor');
  }

  private async toConversationResponse(
    currentUserId: string,
    conversation: ConversationRecord,
    unreadMessageCount: number,
  ) {
    const access = this.accessFor(conversation, currentUserId);
    if (!access) throw new NotFoundException('Conversation not found');
    const membership = conversation.participants.find(
      (participant) => participant.userId === currentUserId && !participant.revokedAt,
    );
    if (!membership) throw new NotFoundException('Conversation not found');
    const providerJoined = hasJoinedProvider(
      conversation.provider.userId,
      conversation.participants,
    );
    const blocked = this.isBlocked(conversation);
    const latestQuote = conversation.quoteRequests[0] ?? null;
    const counterpart =
      access.side === 'CUSTOMER'
        ? conversation.provider.user
          ? {
              ...toApplicationUserSummary(conversation.provider.user),
              appRole: conversation.provider.user.appRole,
            }
          : null
        : conversation.scope === ConversationScope.ACCOUNT && conversation.accountRequester
          ? {
              ...customerSummaryForProvider(conversation.accountRequester),
              appRole: conversation.accountRequester.appRole,
            }
          : conversation.scope === ConversationScope.PLAN && latestQuote
            ? planCustomerForProvider(latestQuote)
            : null;
    return {
      id: conversation.id,
      scope: conversation.scope,
      // D75 (RA-BE-80): the plan's title («عرس سلمى») is for the people she
      // chose; the provider reads the plan's id only. The field stays (D93).
      weddingPlan: conversation.weddingPlan
        ? {
            id: conversation.weddingPlan.id,
            title: access.side === 'CUSTOMER' ? conversation.weddingPlan.title : null,
          }
        : null,
      provider: {
        id: conversation.provider.id,
        businessName: conversation.provider.businessName,
        logoUrl: conversation.provider.logoUrl,
      },
      counterpart,
      quoteRequestCount: conversation._count.quoteRequests,
      latestQuoteRequest: latestQuote
        ? this.toQuoteRequestResponse(latestQuote, access)
        : null,
      lastMessage: conversation.messages[0]
        ? await this.toMessageResponse(
            conversation.messages[0],
            conversation.provider.userId,
          )
        : null,
      lastActivityAt: conversation.lastActivityAt,
      unreadMessageCount,
      muted: membership.mutedAt !== null,
      blocked,
      blockedByMe:
        access.side === 'PROVIDER'
          ? conversation.providerSideBlockedAt !== null
          : conversation.customerSideBlockedById === currentUserId,
      blockedByCounterpart:
        access.side === 'PROVIDER'
          ? conversation.customerSideBlockedAt !== null
          : conversation.providerSideBlockedAt !== null,
      providerJoined,
      canSend:
        providerJoined &&
        !blocked &&
        conversation.closedAt === null &&
        isProviderOperational(conversation.provider) &&
        (!conversation.weddingPlan ||
          isWeddingPlanWritable(conversation.weddingPlan)),
      permissions: {
        canManageProviders: access.canManageProviders,
        canViewMoney: access.canViewMoney,
        canManageMoney: access.canManageMoney,
        canViewContact: access.canViewContact,
      },
      closedAt: conversation.closedAt,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
    };
  }

  private toQuoteRequestResponse<
    T extends {
      user: ApplicationAvatarSource & { id: string };
      offers: Array<
        Parameters<typeof quoteOfferVersionView>[0] & {
          amount: Prisma.Decimal | null;
          revisionNoticeAt?: Date | null;
        }
      >;
      budgetMin: Prisma.Decimal | null;
      budgetMax: Prisma.Decimal | null;
      contactName: string | null;
      contactPhone: string | null;
      contactNormalizedPhone: string | null;
      shareBudget: boolean;
      shareContact: boolean;
    },
  >(quote: T, access: ConversationAccess) {
    const {
      budgetMin,
      budgetMax,
      contactName,
      contactPhone,
      contactNormalizedPhone: _contactNormalizedPhone,
      user,
      offers,
      ...safe
    } = quote;
    // B-08: the provider reads the budget and the phone only when the
    // customer shared them; his own side keeps its plan permissions.
    const provider = access.side === 'PROVIDER';
    const showBudget = access.canViewMoney && (!provider || quote.shareBudget);
    const showPhone = access.canViewContact && (!provider || quote.shareContact);
    return {
      ...safe,
      // B-14: his name as drawn, never his picture.
      user: provider ? customerSummaryForProvider(user) : toApplicationUserSummary(user),
      offers: offers.map((source) => {
        const {
          amount,
          currentVersionNo: _currentVersionNo,
          versionChanges: _versionChanges,
          revisionNoticeAt: _revisionNoticeAt,
          lines: _lines,
          ...offer
        } = source;
        return {
          ...offer,
          ...(access.canViewMoney ? { amount } : {}),
          // B-06, B-07: the version, «ايش تغيّر» and what the price covers,
          // read the one way every offer response reads them, without
          // amounts for a viewer who sees no money (RA-BE-73: the lines
          // went out as stored, an extra's price included).
          ...quoteOfferVersionView(source, access.canViewMoney),
        };
      }),
      ...(showBudget ? { budgetMin, budgetMax } : {}),
      ...(access.canViewContact ? { contactName } : {}),
      ...(showPhone ? { contactPhone } : {}),
    };
  }

  private messageRecipientIds(
    conversation: ConversationRecord,
    senderSide: ConversationSide,
    senderUserId: string,
  ): string[] {
    const recipients = new Set<string>();
    if (senderSide === 'CUSTOMER') {
      if (conversation.provider.userId) recipients.add(conversation.provider.userId);
    } else if (conversation.scope === ConversationScope.ACCOUNT) {
      if (conversation.accountRequesterUserId) {
        recipients.add(conversation.accountRequesterUserId);
      }
    } else if (conversation.weddingPlan) {
      recipients.add(conversation.weddingPlan.ownerUserId);
      for (const member of conversation.weddingPlan.sharedMembers) {
        if (member.canManageProviders) recipients.add(member.userId);
      }
    }
    recipients.delete(senderUserId);
    return [...recipients];
  }

  private isBlocked(conversation: Pick<
    ConversationRecord,
    'customerSideBlockedAt' | 'providerSideBlockedAt'
  >) {
    return (
      conversation.customerSideBlockedAt !== null ||
      conversation.providerSideBlockedAt !== null
    );
  }

  private decodeTimelineCursor(value?: string): TimelineCursor | null {
    if (!value) return null;
    try {
      const decoded = JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as Partial<
        TimelineCursor
      >;
      if (
        typeof decoded.occurredAt !== 'string' ||
        !Number.isFinite(Date.parse(decoded.occurredAt)) ||
        typeof decoded.key !== 'string' ||
        decoded.key.length === 0
      ) {
        throw new Error('invalid');
      }
      return { occurredAt: decoded.occurredAt, key: decoded.key };
    } catch {
      throw new BadRequestException('Invalid timeline cursor');
    }
  }

  private encodeTimelineCursor(cursor: TimelineCursor) {
    return Buffer.from(JSON.stringify(cursor), 'utf8').toString('base64url');
  }

  private timelineItemBefore(
    item: { occurredAt: Date; key: string },
    cursor: TimelineCursor,
  ) {
    const itemTime = item.occurredAt.getTime();
    const cursorTime = Date.parse(cursor.occurredAt);
    return itemTime < cursorTime || (itemTime === cursorTime && item.key < cursor.key);
  }

  private compareTimelineItems(
    left: { occurredAt: Date; key: string },
    right: { occurredAt: Date; key: string },
  ) {
    const byTime = right.occurredAt.getTime() - left.occurredAt.getTime();
    if (byTime !== 0) return byTime;
    return left.key === right.key ? 0 : left.key > right.key ? -1 : 1;
  }

  private async toMessageResponse<
    T extends {
      sender?: ApplicationAvatarSource & { id: string };
      attachments: Array<{
        id: string;
        storageKey: string;
        contentType: string;
        byteSize: number;
        createdAt: Date;
      }>;
    },
  >(
    message: T,
    // B-14: a message is read by both sides (and pushed to both in the
    // room), so only the provider's own account shows its picture; a
    // customer-side sender is a name.
    providerUserId: string | null,
    signedDownloads?: Map<string, Awaited<ReturnType<MediaStoragePort['createDownloadUrl']>>>,
  ) {
    const { sender, ...messageWithoutSender } = message;
    const attachments = await Promise.all(
      message.attachments.map(async (attachment) => {
        const access =
          signedDownloads?.get(attachment.storageKey) ??
          (await this.mediaStorage.createDownloadUrl(attachment.storageKey));
        return {
          id: attachment.id,
          url: access.downloadUrl,
          contentType: attachment.contentType,
          byteSize: attachment.byteSize,
          createdAt: attachment.createdAt,
          expiresAt: access.expiresAt,
        };
      }),
    );
    return {
      ...messageWithoutSender,
      ...(sender
        ? {
            sender:
              sender.id === providerUserId
                ? toApplicationUserSummary(sender)
                : customerSummaryForProvider(sender),
          }
        : {}),
      attachments,
    };
  }
}
