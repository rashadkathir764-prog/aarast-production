import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  ConversationParticipantRole,
  NotificationPriority,
  NotificationType,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { assertOwnedMediaUrl } from '../media/media-upload-policy';
import {
  assertConversationParticipant,
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
    assertConversationParticipant(
      currentUser.id,
      quote.userId,
      quote.provider.userId,
    );

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

  async list(currentUser: AuthenticatedUser) {
    const conversations = await this.prisma.conversation.findMany({
      where: { participants: { some: { userId: currentUser.id } } },
      orderBy: [{ lastMessageAt: 'desc' }, { createdAt: 'desc' }],
      take: 100,
      include: this.conversationInclude(),
    });
    return Promise.all(
      conversations.map((conversation) =>
        this.toConversationResponse(currentUser.id, conversation),
      ),
    );
  }

  async messages(
    currentUser: AuthenticatedUser,
    conversationId: string,
    cursor?: string,
    limitValue?: string,
  ) {
    await this.assertAccess(currentUser, conversationId);
    const limit = normalizeMessagePageSize(limitValue);
    const messages = await this.prisma.chatMessage.findMany({
      where: { conversationId, deletedAt: null },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: {
        sender: { select: { id: true, name: true, avatarUrl: true } },
        attachments: { orderBy: { createdAt: 'asc' } },
      },
    });
    const hasMore = messages.length > limit;
    const page = messages.slice(0, limit);
    return {
      items: page.reverse(),
      nextCursor: hasMore ? page[page.length - 1]?.id ?? null : null,
    };
  }

  async send(
    currentUser: AuthenticatedUser,
    conversationId: string,
    dto: SendMessageDto,
  ) {
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
    const publicBaseUrl = process.env.AARAST_MEDIA_PUBLIC_BASE_URL?.trim();
    if (attachments.length > 0 && !publicBaseUrl) {
      throw new ServiceUnavailableException('Media storage is not configured');
    }
    for (const attachment of attachments) {
      if (!attachment.contentType.toLowerCase().startsWith('image/')) {
        throw new BadRequestException('Only image attachments are supported');
      }
      assertOwnedMediaUrl(
        attachment.url,
        publicBaseUrl!,
        'chat-image',
        currentUser.id,
      );
    }
    const body = normalizeMessageBody(dto.body);
    const now = new Date();
    const message = await this.prisma.$transaction(async (tx) => {
      const created = await tx.chatMessage.create({
        data: {
          conversationId,
          senderUserId: currentUser.id,
          body,
          attachments: {
            create: attachments.map((attachment) => ({
              url: attachment.url.trim(),
              contentType: attachment.contentType.trim().toLowerCase(),
              byteSize: attachment.byteSize,
            })),
          },
        },
        include: {
          sender: { select: { id: true, name: true, avatarUrl: true } },
          attachments: true,
        },
      });
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
      return created;
    });

    const recipient = conversation.participants.find(
      (participant) => participant.userId !== currentUser.id,
    );
    this.realtime.message(conversationId, message);
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
    return message;
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

  async setMuted(
    currentUser: AuthenticatedUser,
    conversationId: string,
    enabled: boolean,
  ) {
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

  async setBlocked(
    currentUser: AuthenticatedUser,
    conversationId: string,
    enabled: boolean,
  ) {
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

  async report(
    currentUser: AuthenticatedUser,
    conversationId: string,
    reasonValue: string,
  ) {
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

  private async findConversation(
    currentUser: AuthenticatedUser,
    conversationId: string,
  ) {
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

  private async assertAccess(
    currentUser: AuthenticatedUser,
    conversationId: string,
  ) {
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

  private conversationInclude() {
    return {
      quoteRequest: {
        include: {
          provider: {
            select: { id: true, userId: true, businessName: true, logoUrl: true },
          },
          service: { select: { id: true, title: true } },
          weddingPlan: { select: { id: true, title: true } },
          user: { select: { id: true, name: true, avatarUrl: true } },
        },
      },
      participants: {
        include: {
          user: { select: { id: true, name: true, avatarUrl: true, appRole: true } },
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
    const counterpart = conversation.participants.find(
      (participant) => participant.userId !== currentUserId,
    );
    const unreadCount = await this.prisma.chatMessage.count({
      where: {
        conversationId: conversation.id,
        senderUserId: { not: currentUserId },
        deletedAt: null,
        ...(membership?.lastReadAt
          ? { createdAt: { gt: membership.lastReadAt } }
          : {}),
      },
    });
    return {
      id: conversation.id,
      quoteRequestId: conversation.quoteRequestId,
      quoteRequest: conversation.quoteRequest,
      counterpart: counterpart?.user ?? null,
      lastMessage: conversation.messages[0] ?? null,
      unreadCount,
      muted: membership?.mutedAt != null,
      blocked: conversation.participants.some(
        (participant) => participant.blockedAt != null,
      ),
      lastMessageAt: conversation.lastMessageAt,
      closedAt: conversation.closedAt,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
    };
  }

  private conversationRecord() {
    return this.prisma.conversation.findUniqueOrThrow({
      where: { id: '' },
      include: this.conversationInclude(),
    });
  }
}
