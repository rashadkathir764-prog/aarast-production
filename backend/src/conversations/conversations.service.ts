import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  ConversationParticipantRole,
  NotificationPriority,
  NotificationType,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { NotificationsService } from '../notifications/notifications.service';
import { OutboxEventTypes } from '../outbox/outbox.constants';
import { OutboxService } from '../outbox/outbox.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  ApplicationAvatarSource,
  applicationAvatarFields,
  toApplicationUserSummary,
} from '../users/application-user-identity';
import { MediaStorageService } from '../media/media-storage.service';
import {
  assertConversationParticipant,
  conversationParticipantState,
  normalizeMessageBody,
  normalizeMessagePageSize,
} from './conversation-policy';
import { SendMessageDto } from './dto/send-message.dto';
import { ConversationRealtimePublisher } from './conversation-realtime.publisher';

@Injectable()
export class ConversationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly realtime: ConversationRealtimePublisher,
    private readonly mediaStorage: MediaStorageService,
    private readonly outbox: OutboxService,
  ) {}

  async ensureForQuote(currentUser: AuthenticatedUser, quoteRequestId: string) {
    const quote = await this.prisma.quoteRequest.findUnique({
      where: { id: quoteRequestId },
      include: { provider: { select: { userId: true } } },
    });
    if (!quote) throw new NotFoundException('Quote request not found');
    if (!quote.provider.userId) {
      throw new ConflictException('Provider account is not available for chat');
    }
    assertConversationParticipant(currentUser.id, quote.userId, quote.provider.userId);

    const participantData = [
      {
        userId: quote.userId,
        role: ConversationParticipantRole.REQUESTER,
      },
      ...(quote.provider.userId === quote.userId
        ? []
        : [
            {
              userId: quote.provider.userId,
              role: ConversationParticipantRole.PROVIDER,
            },
          ]),
    ];

    const conversation = await this.prisma.conversation.upsert({
      where: { quoteRequestId },
      update: {},
      create: {
        quoteRequestId,
        participants: { create: participantData },
      },
      select: { id: true },
    });
    return this.findConversation(currentUser, conversation.id);
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
    await this.assertConversationCursor(currentUser.id, cursor);
    const conversations = await this.prisma.conversation.findMany({
      where: { participants: { some: { userId: currentUser.id } } },
      orderBy: [
        { lastMessageAt: { sort: 'desc', nulls: 'last' } },
        { createdAt: 'desc' },
        { id: 'desc' },
      ],
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: this.conversationInclude(),
    });
    const hasMore = conversations.length > limit;
    const page = conversations.slice(0, limit);
    return {
      items: await Promise.all(
        page.map((conversation) => this.toConversationResponse(currentUser.id, conversation)),
      ),
      nextCursor: hasMore ? (page[page.length - 1]?.id ?? null) : null,
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
    const nextCursor = hasMore ? (page[page.length - 1]?.id ?? null) : null;
    return {
      items: await Promise.all(page.reverse().map((message) => this.toMessageResponse(message))),
      nextCursor,
    };
  }

  async send(currentUser: AuthenticatedUser, conversationId: string, dto: SendMessageDto) {
    const conversation = await this.assertAccess(currentUser, conversationId);
    if (conversation.closedAt) {
      throw new ConflictException('Conversation is closed');
    }
    if (conversation.participants.some((participant) => participant.blockedAt)) {
      throw new ConflictException('Conversation is blocked');
    }
    const attachments = dto.attachments ?? [];
    if (attachments.length > 4) {
      throw new BadRequestException('A message can contain up to 4 attachments');
    }
    if (
      new Set(attachments.map((attachment) => attachment.attachmentRef)).size !== attachments.length
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
        verifiedAttachments.map(async (attachment) => {
          const storageKey = attachment.key;
          return [storageKey, await this.mediaStorage.createDownloadUrl(storageKey)] as const;
        }),
      ),
    );
    const body = normalizeMessageBody(dto.body);
    const now = new Date();
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
        data: { lastMessageAt: now },
      });
      await tx.conversationParticipant.update({
        where: {
          conversationId_userId: {
            conversationId,
            userId: currentUser.id,
          },
        },
        data: { lastReadAt: now },
      });
      await this.outbox.enqueue(tx, {
        type: OutboxEventTypes.conversationMessageAvailable,
        aggregateType: 'conversation',
        aggregateId: conversationId,
        payload: { conversationId, messageId: created.id },
      });
      return created;
    });

    const response = await this.toMessageResponse(message, signedDownloads);
    const recipient = conversation.participants.find(
      (participant) => participant.userId !== currentUser.id,
    );
    this.realtime.message(conversationId, response);
    if (recipient && !recipient.mutedAt) {
      const preference = await this.prisma.notificationPreference.findUnique({
        where: { userId: recipient.userId },
        select: { providerMessagesEnabled: true },
      });
      if (preference?.providerMessagesEnabled !== false) {
        await this.notifications.createNotification({
          userId: recipient.userId,
          weddingPlanId: conversation.quoteRequest.weddingPlanId,
          type: NotificationType.CHAT_MESSAGE_RECEIVED,
          priority: NotificationPriority.NORMAL,
          title: 'رسالة جديدة',
          body: `لديك رسالة جديدة من ${currentUser.name}`,
          entityType: 'conversation',
          entityId: conversationId,
          routeTarget: `/conversations/${conversationId}`,
          data: { conversationId, quoteRequestId: conversation.quoteRequestId },
          dedupeKey: `chat:${message.id}:${recipient.userId}`,
        });
      }
    }
    return response;
  }

  async downloadAttachment(
    currentUser: AuthenticatedUser,
    conversationId: string,
    attachmentId: string,
  ) {
    await this.assertAccess(currentUser, conversationId);
    const attachment = await this.prisma.chatAttachment.findFirst({
      where: {
        id: attachmentId,
        message: { conversationId, deletedAt: null },
      },
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
    await this.prisma.conversationParticipant.update({
      where: {
        conversationId_userId: { conversationId, userId: currentUser.id },
      },
      data: { lastReadAt },
    });
    const receipt = { conversationId, lastReadAt, userId: currentUser.id };
    this.realtime.read(conversationId, receipt);
    return receipt;
  }

  async setMuted(currentUser: AuthenticatedUser, conversationId: string, enabled: boolean) {
    await this.assertAccess(currentUser, conversationId);
    const participant = await this.prisma.conversationParticipant.update({
      where: {
        conversationId_userId: { conversationId, userId: currentUser.id },
      },
      data: { mutedAt: enabled ? new Date() : null },
      select: { mutedAt: true },
    });
    return { conversationId, muted: participant.mutedAt !== null };
  }

  async setBlocked(currentUser: AuthenticatedUser, conversationId: string, enabled: boolean) {
    await this.assertAccess(currentUser, conversationId);
    const participant = await this.prisma.conversationParticipant.update({
      where: {
        conversationId_userId: { conversationId, userId: currentUser.id },
      },
      data: { blockedAt: enabled ? new Date() : null },
      select: { blockedAt: true },
    });
    return { conversationId, blocked: participant.blockedAt !== null };
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
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: this.conversationInclude(),
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    assertConversationParticipant(
      currentUser.id,
      conversation.quoteRequest.userId,
      conversation.quoteRequest.provider.userId,
    );
    return this.toConversationResponse(currentUser.id, conversation);
  }

  private async assertAccess(currentUser: AuthenticatedUser, conversationId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: {
        quoteRequest: {
          include: { provider: { select: { userId: true } } },
        },
        participants: true,
      },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    assertConversationParticipant(
      currentUser.id,
      conversation.quoteRequest.userId,
      conversation.quoteRequest.provider.userId,
    );
    return conversation;
  }

  private async assertConversationCursor(currentUserId: string, cursor?: string) {
    if (!cursor) return;
    const conversation = await this.prisma.conversation.findFirst({
      where: {
        id: cursor,
        participants: { some: { userId: currentUserId } },
      },
      select: { id: true },
    });
    if (!conversation) {
      throw new BadRequestException('Invalid conversation cursor');
    }
  }

  private async assertMessageCursor(conversationId: string, cursor?: string) {
    if (!cursor) return;
    const message = await this.prisma.chatMessage.findFirst({
      where: { id: cursor, conversationId, deletedAt: null },
      select: { id: true },
    });
    if (!message) {
      throw new BadRequestException('Invalid message cursor');
    }
  }

  private conversationInclude() {
    return {
      quoteRequest: {
        include: {
          provider: {
            select: {
              id: true,
              userId: true,
              businessName: true,
              logoUrl: true,
            },
          },
          service: { select: { id: true, title: true } },
          weddingPlan: { select: { id: true, title: true } },
          user: { select: { id: true, ...applicationAvatarFields } },
        },
      },
      participants: {
        include: {
          user: {
            select: { id: true, appRole: true, ...applicationAvatarFields },
          },
        },
      },
      messages: {
        where: { deletedAt: null },
        orderBy: [{ createdAt: 'desc' as const }, { id: 'desc' as const }],
        take: 1,
        include: { attachments: true },
      },
    };
  }

  private async toConversationResponse(
    currentUserId: string,
    conversation: Awaited<ReturnType<ConversationsService['conversationRecord']>>,
  ) {
    const membership = conversation.participants.find(
      (participant) => participant.userId === currentUserId,
    );
    if (!membership) throw new NotFoundException('Conversation not found');
    const counterpart = conversation.participants.find(
      (participant) => participant.userId !== currentUserId,
    );
    const participantState = conversationParticipantState(currentUserId, conversation.participants);
    const unreadCount = await this.prisma.chatMessage.count({
      where: {
        conversationId: conversation.id,
        senderUserId: { not: currentUserId },
        deletedAt: null,
        ...(membership?.lastReadAt ? { createdAt: { gt: membership.lastReadAt } } : {}),
      },
    });
    const lastMessage = conversation.messages[0]
      ? await this.toMessageResponse(conversation.messages[0])
      : null;
    const quoteRequest = {
      ...conversation.quoteRequest,
      user: toApplicationUserSummary(conversation.quoteRequest.user),
    };
    const counterpartUser = counterpart?.user
      ? {
          ...toApplicationUserSummary(counterpart.user),
          appRole: counterpart.user.appRole,
        }
      : null;
    return {
      id: conversation.id,
      quoteRequestId: conversation.quoteRequestId,
      quoteRequest,
      counterpart: counterpartUser,
      lastMessage,
      unreadCount,
      muted: membership?.mutedAt != null,
      ...participantState,
      lastMessageAt: conversation.lastMessageAt,
      closedAt: conversation.closedAt,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
    };
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

  private conversationRecord() {
    return this.prisma.conversation.findUniqueOrThrow({
      where: { id: '' },
      include: this.conversationInclude(),
    });
  }
}
