import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  ConversationScope,
  NotificationPriority,
  NotificationType,
  Prisma,
  SharedMemberRole,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { MediaStorageService } from '../media/media-storage.service';
import { NotificationsService } from '../notifications/notifications.service';
import { OutboxEventTypes } from '../outbox/outbox.constants';
import { OutboxService } from '../outbox/outbox.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  ApplicationAvatarSource,
  applicationAvatarFields,
  toApplicationUserSummary,
} from '../users/application-user-identity';
import {
  normalizeMessageBody,
  normalizeMessagePageSize,
} from './conversation-policy';
import { ConversationRealtimePublisher } from './conversation-realtime.publisher';
import { SendMessageDto } from './dto/send-message.dto';

const conversationInclude = Prisma.validator<Prisma.ConversationInclude>()({
  provider: {
    select: {
      id: true,
      userId: true,
      businessName: true,
      logoUrl: true,
      user: { select: { id: true, appRole: true, ...applicationAvatarFields } },
    },
  },
  weddingPlan: {
    select: {
      id: true,
      title: true,
      ownerUserId: true,
      sharedMembers: {
        select: {
          userId: true,
          role: true,
          canManageProviders: true,
          canViewMoney: true,
          canManageMoney: true,
        },
      },
    },
  },
  accountRequester: {
    select: { id: true, appRole: true, ...applicationAvatarFields },
  },
  participants: {
    include: {
      user: { select: { id: true, appRole: true, ...applicationAvatarFields } },
    },
  },
  quoteRequests: {
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: 1,
    include: {
      service: { select: { id: true, title: true } },
      user: { select: { id: true, ...applicationAvatarFields } },
      offers: { orderBy: [{ createdAt: 'desc' }, { id: 'desc' }] },
    },
  },
  messages: {
    where: { deletedAt: null },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: 1,
    include: {
      sender: { select: { id: true, ...applicationAvatarFields } },
      attachments: { orderBy: { createdAt: 'asc' } },
    },
  },
  _count: { select: { quoteRequests: true } },
});

type ConversationRecord = Prisma.ConversationGetPayload<{
  include: typeof conversationInclude;
}>;
type ConversationSide = 'CUSTOMER' | 'PROVIDER';

interface ConversationAccess {
  side: ConversationSide;
  canManageProviders: boolean;
  canViewMoney: boolean;
  canManageMoney: boolean;
  canViewContact: boolean;
}

interface TimelineCursor {
  occurredAt: string;
  key: string;
}

@Injectable()
export class ConversationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly realtime: ConversationRealtimePublisher,
    private readonly mediaStorage: MediaStorageService,
    private readonly outbox: OutboxService,
  ) {}

  async getForQuote(currentUser: AuthenticatedUser, quoteRequestId: string) {
    const quote = await this.prisma.quoteRequest.findUnique({
      where: { id: quoteRequestId },
      select: { conversationId: true },
    });
    if (!quote) throw new NotFoundException('Quote request not found');
    return this.findConversation(currentUser, quote.conversationId);
  }

  async authorize(currentUser: AuthenticatedUser, conversationId: string) {
    await this.assertAccess(currentUser, conversationId);
    return { conversationId };
  }

  async get(currentUser: AuthenticatedUser, conversationId: string) {
    return this.findConversation(currentUser, conversationId);
  }

  async list(currentUser: AuthenticatedUser, cursor?: string, limitValue?: string) {
    const limit = normalizeMessagePageSize(limitValue);
    const accessWhere = this.accessWhere(currentUser.id);
    await this.assertConversationCursor(accessWhere, cursor);
    const candidates = await this.prisma.conversation.findMany({
      where: accessWhere,
      orderBy: [{ lastActivityAt: 'desc' }, { createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      select: { id: true, provider: { select: { userId: true } } },
    });
    const hasMore = candidates.length > limit;
    const page = candidates.slice(0, limit);
    await this.ensureParticipants(
      page.flatMap((conversation) => [
        { conversationId: conversation.id, userId: currentUser.id },
        ...(conversation.provider.userId
          ? [{ conversationId: conversation.id, userId: conversation.provider.userId }]
          : []),
      ]),
    );
    const ids = page.map((conversation) => conversation.id);
    const conversations = ids.length
      ? await this.prisma.conversation.findMany({
          where: { id: { in: ids } },
          orderBy: [
            { lastActivityAt: 'desc' },
            { createdAt: 'desc' },
            { id: 'desc' },
          ],
          include: conversationInclude,
        })
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
    const quoteRequests = await this.prisma.quoteRequest.findMany({
      where: { conversationId },
      include: {
        service: { select: { id: true, title: true } },
        user: { select: { id: true, ...applicationAvatarFields } },
        offers: { orderBy: [{ createdAt: 'desc' }, { id: 'desc' }] },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
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
    await this.assertAccess(currentUser, conversationId);
    const limit = normalizeMessagePageSize(limitValue);
    await this.assertMessageCursor(conversationId, cursor);
    const messages = await this.prisma.chatMessage.findMany({
      where: { conversationId, deletedAt: null },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: {
        sender: { select: { id: true, ...applicationAvatarFields } },
        attachments: { orderBy: { createdAt: 'asc' } },
      },
    });
    const hasMore = messages.length > limit;
    const page = messages.slice(0, limit);
    return {
      items: await Promise.all(page.reverse().map((message) => this.toMessageResponse(message))),
      nextCursor: hasMore ? (page[0]?.id ?? null) : null,
    };
  }

  async timeline(
    currentUser: AuthenticatedUser,
    conversationId: string,
    cursorValue?: string,
    limitValue?: string,
  ) {
    await this.assertAccess(currentUser, conversationId);
    const limit = normalizeMessagePageSize(limitValue);
    const cursor = this.decodeTimelineCursor(cursorValue);
    const before = cursor ? new Date(cursor.occurredAt) : undefined;
    const [messages, events, expiredOffers] = await Promise.all([
      this.prisma.chatMessage.findMany({
        where: {
          conversationId,
          deletedAt: null,
          ...(before ? { createdAt: { lte: before } } : {}),
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
        include: {
          sender: { select: { id: true, ...applicationAvatarFields } },
          attachments: { orderBy: { createdAt: 'asc' } },
        },
      }),
      this.prisma.conversationEvent.findMany({
        where: {
          conversationId,
          ...(before ? { occurredAt: { lte: before } } : {}),
        },
        orderBy: [{ occurredAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      }),
      this.prisma.quoteOffer.findMany({
        where: {
          quoteRequest: { conversationId },
          status: 'PENDING',
          validUntil: { not: null, lte: before ?? new Date() },
        },
        select: { id: true, quoteRequestId: true, validUntil: true },
        orderBy: [{ validUntil: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      }),
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
                message: await this.toMessageResponse(item.source),
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
    const { conversation, access } = await this.assertAccess(currentUser, conversationId);
    if (conversation.closedAt) throw new ConflictException('Conversation is closed');
    if (!conversation.provider.userId) {
      throw new ConflictException({
        code: 'PROVIDER_NOT_JOINED',
        message: 'المورد لم ينضم للمحادثة بعد',
      });
    }
    if (this.isBlocked(conversation)) {
      throw new ConflictException('Conversation is blocked');
    }
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
    const now = new Date();
    const recipientIds = this.messageRecipientIds(conversation, access.side, currentUser.id);
    const message = await this.prisma.$transaction(async (tx) => {
      const created = await tx.chatMessage.create({
        data: {
          conversationId,
          senderUserId: currentUser.id,
          body,
          attachments: {
            create: verifiedAttachments.map((attachment) => ({
              storageKey: attachment.key,
              contentType: attachment.contentType,
              byteSize: attachment.byteSize,
            })),
          },
        },
        include: {
          sender: { select: { id: true, ...applicationAvatarFields } },
          attachments: true,
        },
      });
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
      await tx.conversation.update({
        where: { id: conversationId },
        data: { lastActivityAt: now },
      });
      await tx.conversationParticipant.updateMany({
        where: { conversationId, userId: currentUser.id },
        data: { lastReadAt: now, revokedAt: null },
      });
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
        const [preferences, participantStates] = await Promise.all([
          tx.notificationPreference.findMany({
            where: { userId: { in: recipientIds } },
            select: { userId: true, providerMessagesEnabled: true },
          }),
          tx.conversationParticipant.findMany({
            where: { conversationId, userId: { in: recipientIds }, revokedAt: null },
            select: { userId: true, mutedAt: true },
          }),
        ]);
        const preferenceByUser = new Map(
          preferences.map((preference) => [preference.userId, preference]),
        );
        const participantByUser = new Map(
          participantStates.map((participant) => [participant.userId, participant]),
        );
        for (const recipientId of recipientIds) {
          if (preferenceByUser.get(recipientId)?.providerMessagesEnabled === false) continue;
          if (participantByUser.get(recipientId)?.mutedAt) continue;
          await this.notifications.createNotificationInTransaction(tx, {
            userId: recipientId,
            weddingPlanId: conversation.weddingPlanId,
            type: NotificationType.CHAT_MESSAGE_RECEIVED,
            priority: NotificationPriority.NORMAL,
            title: 'رسالة جديدة',
            body: `لديك رسالة جديدة من ${currentUser.name}`,
            entityType: 'conversation',
            entityId: conversationId,
            routeTarget: `/conversations/${conversationId}`,
            data: {
              conversationId,
              providerId: conversation.providerId,
              ...(conversation.weddingPlanId
                ? { weddingPlanId: conversation.weddingPlanId }
                : {}),
              messageId: created.id,
            },
            dedupeKey: `chat:${created.id}:${recipientId}`,
          });
        }
      }
      return created;
    });

    const response = await this.toMessageResponse(message, signedDownloads);
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
    const attachment = await this.prisma.chatAttachment.findFirst({
      where: { id: attachmentId, message: { conversationId, deletedAt: null } },
      select: { storageKey: true },
    });
    if (!attachment) throw new NotFoundException('Attachment not found');
    const access = await this.mediaStorage.createDownloadUrl(attachment.storageKey);
    return {
      url: access.downloadUrl,
      expiresInSeconds: access.expiresInSeconds,
      expiresAt: access.expiresAt,
    };
  }

  async markRead(currentUser: AuthenticatedUser, conversationId: string) {
    await this.assertAccess(currentUser, conversationId);
    const lastReadAt = new Date();
    await this.prisma.conversationParticipant.updateMany({
      where: { conversationId, userId: currentUser.id },
      data: { lastReadAt, revokedAt: null },
    });
    const receipt = { conversationId, lastReadAt, userId: currentUser.id };
    this.realtime.read(conversationId, receipt);
    return receipt;
  }

  async setMuted(currentUser: AuthenticatedUser, conversationId: string, enabled: boolean) {
    await this.assertAccess(currentUser, conversationId);
    const participant = await this.prisma.conversationParticipant.update({
      where: { conversationId_userId: { conversationId, userId: currentUser.id } },
      data: { mutedAt: enabled ? new Date() : null },
      select: { mutedAt: true },
    });
    return { conversationId, muted: participant.mutedAt !== null };
  }

  async setBlocked(currentUser: AuthenticatedUser, conversationId: string, enabled: boolean) {
    const { access } = await this.assertAccess(currentUser, conversationId);
    const conversation = await this.prisma.conversation.update({
      where: { id: conversationId },
      data:
        access.side === 'PROVIDER'
          ? { providerSideBlockedAt: enabled ? new Date() : null }
          : {
              customerSideBlockedAt: enabled ? new Date() : null,
              customerSideBlockedById: enabled ? currentUser.id : null,
            },
      select: {
        customerSideBlockedAt: true,
        customerSideBlockedById: true,
        providerSideBlockedAt: true,
      },
    });
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
  }

  async report(currentUser: AuthenticatedUser, conversationId: string, reasonValue: string) {
    await this.assertAccess(currentUser, conversationId);
    const reason = reasonValue.trim();
    if (reason.length < 3 || reason.length > 500) {
      throw new BadRequestException('Report reason must contain 3 to 500 characters');
    }
    return this.prisma.conversationReport.upsert({
      where: {
        conversationId_reporterUserId: {
          conversationId,
          reporterUserId: currentUser.id,
        },
      },
      update: { reason, status: 'OPEN' },
      create: { conversationId, reporterUserId: currentUser.id, reason },
      select: { id: true, status: true, createdAt: true, updatedAt: true },
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

  private async assertAccess(currentUser: AuthenticatedUser, conversationId: string) {
    let conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: conversationInclude,
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    const access = this.accessFor(conversation, currentUser.id);
    if (!access) {
      await this.prisma.conversationParticipant.updateMany({
        where: { conversationId, userId: currentUser.id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      this.realtime.revokeConversationAccess(currentUser.id, [conversationId]);
      throw new NotFoundException('Conversation not found');
    }
    await this.ensureParticipants([
      { conversationId, userId: currentUser.id },
      ...(conversation.provider.userId
        ? [{ conversationId, userId: conversation.provider.userId }]
        : []),
    ]);
    conversation = await this.prisma.conversation.findUniqueOrThrow({
      where: { id: conversationId },
      include: conversationInclude,
    });
    return { conversation, access };
  }

  private accessFor(
    conversation: ConversationRecord,
    currentUserId: string,
  ): ConversationAccess | null {
    if (conversation.provider.userId === currentUserId) {
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
    const canManageMoney =
      member.canManageMoney || member.role === SharedMemberRole.FINANCE_MANAGER;
    return {
      side: 'CUSTOMER',
      canManageProviders: true,
      canViewMoney: member.canViewMoney || canManageMoney,
      canManageMoney,
      canViewContact: true,
    };
  }

  private accessWhere(currentUserId: string): Prisma.ConversationWhereInput {
    return {
      OR: [
        { provider: { is: { userId: currentUserId } } },
        { scope: ConversationScope.ACCOUNT, accountRequesterUserId: currentUserId },
        {
          scope: ConversationScope.PLAN,
          weddingPlan: { is: { ownerUserId: currentUserId } },
        },
        {
          scope: ConversationScope.PLAN,
          weddingPlan: {
            is: {
              sharedMembers: {
                some: { userId: currentUserId, canManageProviders: true },
              },
            },
          },
        },
      ],
    };
  }

  private async ensureParticipants(
    values: Array<{ conversationId: string; userId: string }>,
  ): Promise<void> {
    const unique = [
      ...new Map(values.map((value) => [`${value.conversationId}:${value.userId}`, value])).values(),
    ];
    if (unique.length === 0) return;
    await this.prisma.$transaction([
      ...unique.map((value) =>
        this.prisma.conversationParticipant.updateMany({
          where: value,
          data: { revokedAt: null },
        }),
      ),
      this.prisma.conversationParticipant.createMany({ data: unique, skipDuplicates: true }),
    ]);
  }

  private async unreadCounts(currentUserId: string, conversationIds: string[]) {
    if (conversationIds.length === 0) return new Map<string, number>();
    const rows = await this.prisma.$queryRaw<Array<{ conversationId: string; count: bigint }>>(
      Prisma.sql`
        SELECT m."conversationId", count(*)::bigint AS "count"
        FROM "ChatMessage" m
        JOIN "ConversationParticipant" p
          ON p."conversationId" = m."conversationId"
         AND p."userId" = ${currentUserId}
         AND p."revokedAt" IS NULL
        WHERE m."conversationId" IN (${Prisma.join(conversationIds)})
          AND m."senderUserId" <> ${currentUserId}
          AND m."deletedAt" IS NULL
          AND (p."lastReadAt" IS NULL OR m."createdAt" > p."lastReadAt")
        GROUP BY m."conversationId"
      `,
    );
    return new Map(rows.map((row) => [row.conversationId, Number(row.count)]));
  }

  private async assertConversationCursor(
    accessWhere: Prisma.ConversationWhereInput,
    cursor?: string,
  ) {
    if (!cursor) return;
    const conversation = await this.prisma.conversation.findFirst({
      where: { AND: [{ id: cursor }, accessWhere] },
      select: { id: true },
    });
    if (!conversation) throw new BadRequestException('Invalid conversation cursor');
  }

  private async assertMessageCursor(conversationId: string, cursor?: string) {
    if (!cursor) return;
    const message = await this.prisma.chatMessage.findFirst({
      where: { id: cursor, conversationId, deletedAt: null },
      select: { id: true },
    });
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
    const providerParticipant = conversation.provider.userId
      ? conversation.participants.find(
          (participant) =>
            participant.userId === conversation.provider.userId && !participant.revokedAt,
        )
      : null;
    const providerJoined = Boolean(conversation.provider.userId && providerParticipant);
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
              ...toApplicationUserSummary(conversation.accountRequester),
              appRole: conversation.accountRequester.appRole,
            }
          : null;
    return {
      id: conversation.id,
      scope: conversation.scope,
      weddingPlan: conversation.weddingPlan
        ? { id: conversation.weddingPlan.id, title: conversation.weddingPlan.title }
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
        ? await this.toMessageResponse(conversation.messages[0])
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
      canSend: providerJoined && !blocked && conversation.closedAt === null,
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
      offers: Array<{ amount: Prisma.Decimal | null }>;
      budgetMin: Prisma.Decimal | null;
      budgetMax: Prisma.Decimal | null;
      contactName: string | null;
      contactPhone: string | null;
      contactNormalizedPhone: string | null;
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
    return {
      ...safe,
      user: toApplicationUserSummary(user),
      offers: offers.map(({ amount, ...offer }) => ({
        ...offer,
        ...(access.canViewMoney ? { amount } : {}),
      })),
      ...(access.canViewMoney ? { budgetMin, budgetMax } : {}),
      ...(access.canViewContact ? { contactName, contactPhone } : {}),
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
    signedDownloads?: Map<string, Awaited<ReturnType<MediaStorageService['createDownloadUrl']>>>,
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
      ...(sender ? { sender: toApplicationUserSummary(sender) } : {}),
      attachments,
    };
  }
}
