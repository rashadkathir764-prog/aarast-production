import 'reflect-metadata';

import {
  AdminRole,
  AuthSessionScope,
  ConversationEventType,
  ConversationScope,
  NotificationType,
  OtpPurpose,
  Prisma,
  PrismaClient,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
  WeddingCostStatus,
  UserRole,
} from '@prisma/client';
import sharp from 'sharp';
import { MediaStorageService } from '../../src/media/media-storage.service';
import { MediaUploadTicketService } from '../../src/media/media-upload-ticket.service';
import { UsersService } from '../../src/users/users.service';

const { assertManagedSmokeEnvironment } = require('./smoke-utils.js') as {
  assertManagedSmokeEnvironment: (environment?: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);

function configureLocalMediaWhenNeeded(): void {
  const smokeUrl = new URL(
    process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115',
  );
  if (!['127.0.0.1', 'localhost', '::1'].includes(smokeUrl.hostname)) return;
  if (!process.env.AARAST_MEDIA_ENDPOINT?.trim()) {
    process.env.AARAST_MEDIA_ENDPOINT = 'http://127.0.0.1:9000';
  }
  if (!process.env.AARAST_MEDIA_SIGNED_ENDPOINT?.trim()) {
    process.env.AARAST_MEDIA_SIGNED_ENDPOINT = 'http://127.0.0.1:9000';
  }
  if (!process.env.AARAST_MEDIA_BUCKET?.trim()) {
    process.env.AARAST_MEDIA_BUCKET = 'aarast-media';
  }
  if (!process.env.AARAST_MEDIA_PUBLIC_BASE_URL?.trim()) {
    process.env.AARAST_MEDIA_PUBLIC_BASE_URL =
      'http://127.0.0.1:9000/aarast-media';
  }
  if (!process.env.AARAST_MEDIA_REGION?.trim()) {
    process.env.AARAST_MEDIA_REGION = 'us-east-1';
  }
  if (!process.env.AARAST_MEDIA_FORCE_PATH_STYLE?.trim()) {
    process.env.AARAST_MEDIA_FORCE_PATH_STYLE = 'true';
  }
  if (!process.env.AARAST_MEDIA_ACCESS_KEY_ID?.trim()) {
    process.env.AARAST_MEDIA_ACCESS_KEY_ID = 'aarast-local-media-key';
  }
  if (!process.env.AARAST_MEDIA_SECRET_ACCESS_KEY?.trim()) {
    process.env.AARAST_MEDIA_SECRET_ACCESS_KEY =
      'aarast-local-media-secret-change-me';
  }
}

function assertCheck(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`FAIL: ${message}`);
  console.log(`PASS - ${message}`);
}

async function main() {
  configureLocalMediaWhenNeeded();
  const prisma = new PrismaClient();
  const tickets = new MediaUploadTicketService(prisma as never);
  const media = new MediaStorageService(tickets);
  const users = new UsersService(prisma as never, {} as never, media);
  const tag = `deltest-${Date.now()}`;
  const phone = `+96771${String(Date.now()).slice(-7)}`;
  let userId = '';
  let mediaKey = '';
  let publicUrl = '';
  let sentinelUserId = '';
  let sentinelPhone = '';
  let sentinelMediaKey = '';
  let sentinelPublicUrl = '';
  let conversationMediaKey = '';
  let clientUserId = '';
  let clientPhone = '';
  let bareUserId = '';
  let barePhone = '';
  let adminUserId = '';
  let adminPhone = '';
  const quoteRequestIds: string[] = [];
  const deletedConversationIds: string[] = [];
  const deletedNotificationIds: string[] = [];

  try {
    const user = await prisma.user.create({
      data: { name: 'DELETION SMOKE', phone, passwordHash: 'x' },
    });
    userId = user.id;
    const currentUser = { id: user.id, phone } as never;
    const imageBytes = await sharp({
      create: {
        width: 8,
        height: 8,
        channels: 3,
        background: { r: 126, g: 18, b: 61 },
      },
    })
      .png()
      .toBuffer();
    const upload = await media.createUpload(currentUser, {
      purpose: 'user-avatar',
      fileName: 'account-delete-smoke.png',
      contentType: 'image/png',
      byteSize: imageBytes.length,
    });
    mediaKey = upload.key;
    const put = await fetch(upload.uploadUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': upload.contentType,
        'Content-Length': String(imageBytes.length),
        ...upload.requiredHeaders,
      },
      body: new Uint8Array(imageBytes),
    });
    assertCheck(put.ok, 'account avatar bytes upload to real object storage');
    const verified = await media.verifyUpload(
      currentUser,
      upload.key,
      'user-avatar',
    );
    assertCheck(
      Boolean(verified.publicUrl),
      'account avatar is fully verified',
    );
    publicUrl = verified.publicUrl!;
    await users.updateMe(currentUser, { avatarUrl: publicUrl });
    const consumed = await prisma.mediaUploadTicket.findUnique({
      where: { key: upload.key },
    });
    assertCheck(
      consumed?.status === 'VERIFIED' &&
        consumed.consumedByType === 'USER_AVATAR' &&
        consumed.consumedById === user.id,
      'avatar ticket is bound atomically to the user profile',
    );

    // A second real account/object proves cleanup is ownership-scoped rather
    // than merely proving that the selected object disappeared.
    sentinelPhone = `+96772${String(Date.now() + 1).slice(-7)}`;
    const sentinel = await prisma.user.create({
      data: {
        name: 'DELETION SENTINEL',
        phone: sentinelPhone,
        passwordHash: 'x',
      },
    });
    sentinelUserId = sentinel.id;
    const sentinelCurrent = {
      id: sentinel.id,
      phone: sentinelPhone,
    } as never;
    const sentinelUpload = await media.createUpload(sentinelCurrent, {
      purpose: 'user-avatar',
      fileName: 'account-delete-sentinel.png',
      contentType: 'image/png',
      byteSize: imageBytes.length,
    });
    sentinelMediaKey = sentinelUpload.key;
    const sentinelPut = await fetch(sentinelUpload.uploadUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': sentinelUpload.contentType,
        'Content-Length': String(imageBytes.length),
        ...sentinelUpload.requiredHeaders,
      },
      body: new Uint8Array(imageBytes),
    });
    assertCheck(sentinelPut.ok, 'sentinel account media uploads independently');
    const sentinelVerified = await media.verifyUpload(
      sentinelCurrent,
      sentinelUpload.key,
      'user-avatar',
    );
    sentinelPublicUrl = sentinelVerified.publicUrl!;
    await users.updateMe(sentinelCurrent, { avatarUrl: sentinelPublicUrl });

    barePhone = `+96773${String(Date.now() + 2).slice(-7)}`;
    const bareUser = await prisma.user.create({
      data: {
        name: 'DELETION BARE ACCOUNT',
        phone: barePhone,
        passwordHash: 'x',
      },
    });
    bareUserId = bareUser.id;
    await users.deleteMe(
      { id: bareUser.id, phone: barePhone } as never,
      'smoke-delete-bare-user',
    );
    assertCheck(
      (await prisma.user.count({ where: { id: bareUser.id } })) === 0,
      'account with no plan deletes cleanly',
    );
    bareUserId = '';

    adminPhone = `+96776${String(Date.now() + 5).slice(-7)}`;
    const administrator = await prisma.user.create({
      data: {
        name: 'ADMIN IDENTITY SENTINEL',
        phone: adminPhone,
        email: `${tag}-admin@example.test`,
        passwordHash: 'admin-password-hash',
        avatarUrl: `https://admin.invalid/${tag}.webp`,
        role: UserRole.ADMIN,
        adminRole: AdminRole.SUPER_ADMIN,
        appPasswordHash: 'application-password-hash',
        appPasswordConfiguredAt: new Date(),
        appName: 'ADMIN APPLICATION PERSONA',
        appEmail: `${tag}-app@example.test`,
        appAvatarUrl: `https://app.invalid/${tag}.webp`,
      },
    });
    adminUserId = administrator.id;
    await prisma.refreshToken.createMany({
      data: [
        {
          userId: administrator.id,
          tokenHash: `${tag}-admin-refresh`,
          scope: AuthSessionScope.ADMIN,
          expiresAt: new Date(Date.now() + 60_000),
        },
        {
          userId: administrator.id,
          tokenHash: `${tag}-app-refresh`,
          scope: AuthSessionScope.APPLICATION,
          expiresAt: new Date(Date.now() + 60_000),
        },
      ],
    });
    await prisma.otpCode.createMany({
      data: [
        {
          phone: adminPhone,
          codeHash: 'admin-otp',
          purpose: OtpPurpose.ADMIN_LOGIN,
          expiresAt: new Date(Date.now() + 60_000),
        },
        {
          phone: adminPhone,
          codeHash: 'app-otp',
          purpose: OtpPurpose.LOGIN,
          expiresAt: new Date(Date.now() + 60_000),
        },
      ],
    });
    await prisma.idempotencyKey.createMany({
      data: [
        {
          userId: administrator.id,
          key: `${tag}-admin-key`,
          method: 'POST',
          path: '/admin/providers/:providerId/approve',
          requestHash: '1'.repeat(64),
          expiresAt: new Date(Date.now() + 60_000),
        },
        {
          userId: administrator.id,
          key: `${tag}-app-key`,
          method: 'POST',
          path: '/api/v1/wedding-plans',
          requestHash: '2'.repeat(64),
          expiresAt: new Date(Date.now() + 60_000),
        },
      ],
    });
    await users.deleteMe(
      {
        id: administrator.id,
        phone: adminPhone,
        sessionScope: 'application',
      } as never,
      'smoke-delete-admin-application-identity',
    );
    const retainedAdministrator = await prisma.user.findUniqueOrThrow({
      where: { id: administrator.id },
    });
    assertCheck(
      retainedAdministrator.role === UserRole.ADMIN &&
        retainedAdministrator.passwordHash === 'admin-password-hash' &&
        retainedAdministrator.name === 'ADMIN IDENTITY SENTINEL' &&
        retainedAdministrator.appPasswordHash === null &&
        retainedAdministrator.appName === null &&
        retainedAdministrator.appEmail === null &&
        retainedAdministrator.appAvatarUrl === null,
      'application deletion clears only the administrator application identity',
    );
    assertCheck(
      (await prisma.refreshToken.count({
        where: {
          userId: administrator.id,
          scope: AuthSessionScope.ADMIN,
        },
      })) === 1 &&
        (await prisma.refreshToken.count({
          where: {
            userId: administrator.id,
            scope: AuthSessionScope.APPLICATION,
          },
        })) === 0 &&
        (await prisma.otpCode.count({
          where: { phone: adminPhone, purpose: OtpPurpose.ADMIN_LOGIN },
        })) === 1 &&
        (await prisma.otpCode.count({
          where: { phone: adminPhone, purpose: OtpPurpose.LOGIN },
        })) === 0,
      'application deletion revokes application auth while preserving admin auth',
    );
    assertCheck(
      (await prisma.idempotencyKey.count({
        where: {
          userId: administrator.id,
          path: { startsWith: '/admin/' },
        },
      })) === 1 &&
        (await prisma.idempotencyKey.count({
          where: {
            userId: administrator.id,
            NOT: {
              OR: [
                { path: '/admin' },
                { path: { startsWith: '/admin/' } },
                { path: '/api/v1/admin' },
                { path: { startsWith: '/api/v1/admin/' } },
                { path: '/api/v1/auth/admin' },
                { path: { startsWith: '/api/v1/auth/admin/' } },
              ],
            },
          },
        })) === 0,
      'application deletion preserves only administrator idempotency history',
    );
    await prisma.idempotencyKey.deleteMany({
      where: { userId: administrator.id },
    });
    await prisma.otpCode.deleteMany({ where: { phone: adminPhone } });
    await prisma.user.delete({ where: { id: administrator.id } });
    adminUserId = '';

    const plan = await prisma.weddingPlan.create({
      data: { ownerUserId: user.id, title: `${tag}-plan` },
    });
    const emptyPlan = await prisma.weddingPlan.create({
      data: { ownerUserId: user.id, title: `${tag}-empty-plan` },
    });
    const city = await prisma.city.create({
      data: {
        nameAr: `${tag}-city`,
        countryCode: 'YE',
      },
    });
    const providerCategory = await prisma.providerCategory.create({
      data: {
        nameAr: `${tag}-provider-category`,
        slug: `${tag}-provider-category`,
      },
    });
    const provider = await prisma.provider.create({
      data: {
        userId: sentinel.id,
        cityId: city.id,
        primaryCategoryId: providerCategory.id,
        businessName: `${tag}-provider`,
        phone: sentinelPhone,
        status: ProviderStatus.ACTIVE,
      },
    });
    const service = await prisma.providerService.create({
      data: {
        providerId: provider.id,
        categoryId: providerCategory.id,
        cityId: city.id,
        title: `${tag}-service`,
      },
    });
    const conversation = await prisma.conversation.create({
      data: {
        scope: ConversationScope.PLAN,
        weddingPlanId: plan.id,
        providerId: provider.id,
        createdByUserId: user.id,
        participants: {
          create: [{ userId: user.id }, { userId: sentinel.id }],
        },
      },
    });
    deletedConversationIds.push(conversation.id);
    const acceptedQuoteRequest = await prisma.quoteRequest.create({
      data: {
        userId: user.id,
        weddingPlanId: plan.id,
        providerId: provider.id,
        serviceId: service.id,
        cityId: city.id,
        conversationId: conversation.id,
        status: QuoteRequestStatus.ACCEPTED,
        acceptedAt: new Date(),
        message: `${tag}-accepted-request`,
      },
    });
    quoteRequestIds.push(acceptedQuoteRequest.id);
    const pendingQuoteRequest = await prisma.quoteRequest.create({
      data: {
        userId: user.id,
        weddingPlanId: plan.id,
        providerId: provider.id,
        serviceId: service.id,
        cityId: city.id,
        conversationId: conversation.id,
        status: QuoteRequestStatus.SENT,
        message: `${tag}-pending-request`,
      },
    });
    quoteRequestIds.push(pendingQuoteRequest.id);
    const alternateProvider = await prisma.provider.create({
      data: {
        cityId: city.id,
        primaryCategoryId: providerCategory.id,
        businessName: `${tag}-alternate-provider`,
        phone: `+96774${String(Date.now() + 3).slice(-7)}`,
        status: ProviderStatus.ACTIVE,
      },
    });
    const alternateConversation = await prisma.conversation.create({
      data: {
        scope: ConversationScope.PLAN,
        weddingPlanId: plan.id,
        providerId: alternateProvider.id,
        createdByUserId: user.id,
        participants: { create: { userId: user.id } },
      },
    });
    deletedConversationIds.push(alternateConversation.id);
    const alternateQuote = await prisma.quoteRequest.create({
      data: {
        userId: user.id,
        weddingPlanId: plan.id,
        providerId: alternateProvider.id,
        cityId: city.id,
        conversationId: alternateConversation.id,
        status: QuoteRequestStatus.SENT,
        message: `${tag}-alternate-provider-request`,
      },
    });
    quoteRequestIds.push(alternateQuote.id);

    const accountConversation = await prisma.conversation.create({
      data: {
        scope: ConversationScope.ACCOUNT,
        accountRequesterUserId: user.id,
        providerId: provider.id,
        createdByUserId: user.id,
        participants: {
          create: [{ userId: user.id }, { userId: sentinel.id }],
        },
      },
    });
    deletedConversationIds.push(accountConversation.id);
    const accountQuote = await prisma.quoteRequest.create({
      data: {
        userId: user.id,
        providerId: provider.id,
        serviceId: service.id,
        cityId: city.id,
        conversationId: accountConversation.id,
        status: QuoteRequestStatus.SENT,
        message: `${tag}-account-request`,
      },
    });
    quoteRequestIds.push(accountQuote.id);

    clientPhone = `+96775${String(Date.now() + 4).slice(-7)}`;
    const client = await prisma.user.create({
      data: {
        name: 'DELETION CUSTOMER SENTINEL',
        phone: clientPhone,
        passwordHash: 'x',
      },
    });
    clientUserId = client.id;
    const clientPlans = await Promise.all([
      prisma.weddingPlan.create({
        data: { ownerUserId: client.id, title: `${tag}-client-plan-1` },
      }),
      prisma.weddingPlan.create({
        data: { ownerUserId: client.id, title: `${tag}-client-plan-2` },
      }),
    ]);
    await prisma.sharedMember.create({
      data: {
        weddingPlanId: clientPlans[0].id,
        userId: user.id,
        canManageProviders: true,
      },
    });
    const sharedConversation = await prisma.conversation.create({
      data: {
        scope: ConversationScope.PLAN,
        weddingPlanId: clientPlans[0].id,
        providerId: provider.id,
        createdByUserId: user.id,
        participants: {
          create: [
            { userId: client.id },
            { userId: user.id },
            { userId: sentinel.id },
          ],
        },
      },
    });
    const memberQuote = await prisma.quoteRequest.create({
      data: {
        userId: user.id,
        weddingPlanId: clientPlans[0].id,
        providerId: provider.id,
        serviceId: service.id,
        cityId: city.id,
        conversationId: sharedConversation.id,
        status: QuoteRequestStatus.SENT,
        message: `${tag}-member-request`,
      },
    });
    const clientQuote = await prisma.quoteRequest.create({
      data: {
        userId: client.id,
        weddingPlanId: clientPlans[0].id,
        providerId: provider.id,
        serviceId: service.id,
        cityId: city.id,
        conversationId: sharedConversation.id,
        status: QuoteRequestStatus.ACCEPTED,
        acceptedAt: new Date(),
        message: `${tag}-client-accepted-request`,
      },
    });
    const ordinaryDeletedQuote = await prisma.quoteRequest.create({
      data: {
        userId: client.id,
        weddingPlanId: clientPlans[0].id,
        providerId: provider.id,
        serviceId: service.id,
        cityId: city.id,
        conversationId: sharedConversation.id,
        status: QuoteRequestStatus.CANCELLED,
        cancelledAt: new Date(),
        message: `${tag}-ordinary-delete`,
      },
    });
    await prisma.quoteRequest.delete({
      where: { id: ordinaryDeletedQuote.id },
    });
    assertCheck(
      (await prisma.conversation.count({
        where: { id: sharedConversation.id },
      })) === 1 &&
        (await prisma.quoteRequest.count({
          where: { conversationId: sharedConversation.id },
        })) === 2,
      'ordinary QuoteRequest deletion leaves the shared Conversation intact',
    );
    const clientOffer = await prisma.quoteOffer.create({
      data: {
        quoteRequestId: clientQuote.id,
        providerId: provider.id,
        amount: 2400,
        status: QuoteOfferStatus.ACCEPTED,
      },
    });
    await prisma.planProviderLink.create({
      data: {
        weddingPlanId: clientPlans[0].id,
        providerId: provider.id,
        quoteRequestId: clientQuote.id,
        quoteOfferId: clientOffer.id,
      },
    });
    const clientCategory = await prisma.budgetCategory.create({
      data: {
        weddingPlanId: clientPlans[0].id,
        name: `${tag}-client-category`,
        normalizedName: `${tag}-client-category`,
      },
    });
    const clientCost = await prisma.weddingCost.create({
      data: {
        weddingPlanId: clientPlans[0].id,
        budgetCategoryId: clientCategory.id,
        providerId: provider.id,
        quoteOfferId: clientOffer.id,
        title: `${tag}-client-cost`,
        totalAmount: 2400,
      },
    });
    const secondClientConversation = await prisma.conversation.create({
      data: {
        scope: ConversationScope.PLAN,
        weddingPlanId: clientPlans[1].id,
        providerId: provider.id,
        createdByUserId: client.id,
        participants: {
          create: [{ userId: client.id }, { userId: sentinel.id }],
        },
      },
    });
    const secondClientQuote = await prisma.quoteRequest.create({
      data: {
        userId: client.id,
        weddingPlanId: clientPlans[1].id,
        providerId: provider.id,
        serviceId: service.id,
        cityId: city.id,
        conversationId: secondClientConversation.id,
        status: QuoteRequestStatus.SENT,
        message: `${tag}-second-client-plan-request`,
      },
    });
    const acceptedOffer = await prisma.quoteOffer.create({
      data: {
        quoteRequestId: acceptedQuoteRequest.id,
        providerId: provider.id,
        amount: 1000,
        status: QuoteOfferStatus.ACCEPTED,
        message: `${tag}-accepted-offer`,
      },
    });
    await prisma.planProviderLink.create({
      data: {
        weddingPlanId: plan.id,
        providerId: provider.id,
        quoteRequestId: acceptedQuoteRequest.id,
        quoteOfferId: acceptedOffer.id,
      },
    });
    await prisma.conversationEvent.create({
      data: {
        conversationId: conversation.id,
        quoteRequestId: acceptedQuoteRequest.id,
        quoteOfferId: acceptedOffer.id,
        actorUserId: user.id,
        type: ConversationEventType.QUOTE_OFFER_ACCEPTED,
        dedupeKey: `${tag}-accepted-event`,
      },
    });
    await prisma.chatMessage.create({
      data: {
        conversationId: conversation.id,
        senderUserId: user.id,
        body: `${tag}-message`,
      },
    });
    const chatUpload = await media.createUpload(sentinelCurrent, {
      purpose: 'chat-image',
      fileName: 'account-delete-conversation.png',
      contentType: 'image/png',
      byteSize: imageBytes.length,
    });
    conversationMediaKey = chatUpload.key;
    const chatPut = await fetch(chatUpload.uploadUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': chatUpload.contentType,
        'Content-Length': String(imageBytes.length),
        ...chatUpload.requiredHeaders,
      },
      body: new Uint8Array(imageBytes),
    });
    assertCheck(chatPut.ok, 'other-party conversation attachment uploads');
    const verifiedChat = await media.verifyUpload(
      sentinelCurrent,
      chatUpload.key,
      'chat-image',
    );
    const attachmentId = await prisma.$transaction(async (tx) => {
      const message = await tx.chatMessage.create({
        data: {
          conversationId: conversation.id,
          senderUserId: sentinel.id,
          body: `${tag}-provider-message`,
          attachments: {
            create: {
              storageKey: verifiedChat.key,
              contentType: verifiedChat.contentType,
              byteSize: verifiedChat.byteSize,
            },
          },
        },
        include: { attachments: true },
      });
      const attachment = message.attachments[0];
      assertCheck(
        Boolean(attachment),
        'conversation attachment row is created',
      );
      await media.consumeUpload(
        sentinelCurrent,
        verifiedChat.key,
        'chat-image',
        { type: 'CHAT_ATTACHMENT', id: attachment.id },
        tx,
      );
      return attachment.id;
    });
    const cat = await prisma.budgetCategory.create({
      data: {
        weddingPlanId: plan.id,
        name: `${tag}-cat`,
        normalizedName: `${tag}-cat`,
      },
    });
    const cost = await prisma.$transaction(async (tx) => {
      const created = await tx.weddingCost.create({
        data: {
          weddingPlanId: plan.id,
          budgetCategoryId: cat.id,
          providerId: provider.id,
          quoteOfferId: acceptedOffer.id,
          title: `${tag}-cost`,
          totalAmount: 1000,
        },
      });
      await tx.costPayment.create({
        data: {
          weddingCostId: created.id,
          amount: 100,
          note: `${tag}-payment`,
        },
      });
      await tx.weddingCost.update({
        where: { id: created.id },
        data: {
          paidAmount: 100,
          status: WeddingCostStatus.PARTIALLY_PAID,
        },
      });
      await tx.paymentSchedule.create({
        data: {
          weddingCostId: created.id,
          amount: 200,
          dueDate: new Date(Date.now() + 24 * 60 * 60 * 1_000),
          note: `${tag}-schedule`,
        },
      });
      return created;
    });
    await prisma.guest.create({
      data: {
        weddingPlanId: plan.id,
        name: `${tag}-guest`,
        normalizedName: `${tag}-guest`,
      },
    });
    await prisma.idempotencyKey.create({
      data: {
        userId: user.id,
        key: `${tag}-key`,
        method: 'POST',
        path: '/api/v1/smoke',
        requestHash: '0'.repeat(64),
        expiresAt: new Date(Date.now() + 60_000),
      },
    });
    await prisma.otpCode.create({
      data: {
        phone,
        codeHash: 'x',
        purpose: OtpPurpose.LOGIN,
        expiresAt: new Date(Date.now() + 60_000),
      },
    });

    const ownerNotification = await prisma.notification.create({
      data: {
        userId: user.id,
        weddingPlanId: plan.id,
        type: NotificationType.GENERAL,
        title: `${tag}-owner-notification`,
        body: `${tag}-owner-notification`,
        entityType: 'quote_request',
        entityId: acceptedQuoteRequest.id,
      },
    });
    const providerNotification = await prisma.notification.create({
      data: {
        userId: sentinel.id,
        type: NotificationType.GENERAL,
        title: `${tag}-provider-notification`,
        body: `${tag}-provider-notification`,
        entityType: 'quote_request',
        entityId: acceptedQuoteRequest.id,
      },
    });
    deletedNotificationIds.push(ownerNotification.id, providerNotification.id);
    await prisma.outboxEvent.createMany({
      data: [
        {
          type: 'smoke.notification',
          aggregateType: 'notification',
          aggregateId: ownerNotification.id,
          payload: { notificationId: ownerNotification.id },
        },
        {
          type: 'smoke.notification',
          aggregateType: 'notification',
          aggregateId: providerNotification.id,
          payload: { notificationId: providerNotification.id },
        },
        {
          type: 'smoke.conversation',
          aggregateType: 'conversation',
          aggregateId: conversation.id,
          payload: { conversationId: conversation.id },
        },
      ],
    });

    await users.deleteMe(currentUser, 'smoke-delete-owner');
    assertCheck(
      (await prisma.user.count({ where: { id: user.id } })) === 0,
      'account row is deleted after the complete Restrict chain',
    );
    assertCheck(
      (await prisma.weddingPlan.count({
        where: { id: { in: [plan.id, emptyPlan.id] } },
      })) === 0,
      'owned plans with and without quotes are deleted',
    );
    assertCheck(
      (await prisma.quoteRequest.count({
        where: { id: { in: quoteRequestIds } },
      })) === 0,
      'all quote requests sharing the deleted plan conversation are deleted',
    );
    assertCheck(
      (await prisma.conversation.count({
        where: { id: { in: deletedConversationIds } },
      })) === 0 &&
        (await prisma.conversationParticipant.count({
          where: { conversationId: { in: deletedConversationIds } },
        })) === 0 &&
        (await prisma.conversationEvent.count({
          where: { conversationId: { in: deletedConversationIds } },
        })) === 0 &&
        (await prisma.chatMessage.count({
          where: { conversationId: { in: deletedConversationIds } },
        })) === 0,
      'PLAN and ACCOUNT conversations plus children are deleted',
    );
    assertCheck(
      (await prisma.weddingCost.count({ where: { id: cost.id } })) === 0 &&
        (await prisma.costPayment.count({
          where: { weddingCostId: cost.id },
        })) === 0 &&
        (await prisma.paymentSchedule.count({
          where: { weddingCostId: cost.id },
        })) === 0,
      'cost, immutable payment ledger, and payment schedules are deleted',
    );
    assertCheck(
      (await prisma.user.count({ where: { id: client.id } })) === 1 &&
        (await prisma.weddingPlan.count({
          where: { id: { in: clientPlans.map((item) => item.id) } },
        })) === 2 &&
        (await prisma.conversation.count({
          where: {
            id: {
              in: [sharedConversation.id, secondClientConversation.id],
            },
          },
        })) === 2,
      'deleting a shared member does not delete the owner or either customer plan conversation',
    );
    assertCheck(
      (await prisma.quoteRequest.count({ where: { id: memberQuote.id } })) ===
        0 &&
        (await prisma.quoteRequest.count({
          where: { id: { in: [clientQuote.id, secondClientQuote.id] } },
        })) === 2 &&
        (await prisma.conversationParticipant.count({
          where: {
            conversationId: sharedConversation.id,
            userId: user.id,
          },
        })) === 0,
      'shared-member request and participant state are removed without touching other requests',
    );
    assertCheck(
      (await prisma.weddingCost.count({ where: { id: clientCost.id } })) ===
        1 &&
        (await prisma.provider.count({
          where: { id: { in: [provider.id, alternateProvider.id] } },
        })) === 2,
      'another plan cost and both businesses not owned by the account are preserved',
    );
    assertCheck(
      (await prisma.chatAttachment.count({ where: { id: attachmentId } })) ===
        0 &&
        (await prisma.mediaUploadTicket.count({
          where: {
            key: conversationMediaKey,
            status: 'DELETE_PENDING',
            userId: sentinel.id,
          },
        })) === 1,
      'other-party attachment is cascaded and its object is durably scheduled',
    );
    assertCheck(
      (await prisma.notification.count({
        where: { id: { in: deletedNotificationIds } },
      })) === 0 &&
        (await prisma.outboxEvent.count({
          where: {
            aggregateId: {
              in: [...deletedNotificationIds, ...deletedConversationIds],
            },
          },
        })) === 0,
      'account, quote, and conversation notifications/outbox rows are purged',
    );
    const [orphans] = await prisma.$queryRaw<
      Array<{
        quoteRequests: number;
        participants: number;
        events: number;
        messages: number;
        costs: number;
        payments: number;
        schedules: number;
      }>
    >(Prisma.sql`
      SELECT
        (SELECT COUNT(*)::int FROM "QuoteRequest" child LEFT JOIN "Conversation" parent ON parent."id" = child."conversationId" WHERE parent."id" IS NULL) AS "quoteRequests",
        (SELECT COUNT(*)::int FROM "ConversationParticipant" child LEFT JOIN "Conversation" parent ON parent."id" = child."conversationId" WHERE parent."id" IS NULL) AS "participants",
        (SELECT COUNT(*)::int FROM "ConversationEvent" child LEFT JOIN "Conversation" parent ON parent."id" = child."conversationId" WHERE parent."id" IS NULL) AS "events",
        (SELECT COUNT(*)::int FROM "ChatMessage" child LEFT JOIN "Conversation" parent ON parent."id" = child."conversationId" WHERE parent."id" IS NULL) AS "messages",
        (SELECT COUNT(*)::int FROM "WeddingCost" child LEFT JOIN "WeddingPlan" plan ON plan."id" = child."weddingPlanId" LEFT JOIN "BudgetCategory" category ON category."id" = child."budgetCategoryId" WHERE plan."id" IS NULL OR category."id" IS NULL) AS "costs",
        (SELECT COUNT(*)::int FROM "CostPayment" child LEFT JOIN "WeddingCost" parent ON parent."id" = child."weddingCostId" WHERE parent."id" IS NULL) AS "payments",
        (SELECT COUNT(*)::int FROM "PaymentSchedule" child LEFT JOIN "WeddingCost" parent ON parent."id" = child."weddingCostId" WHERE parent."id" IS NULL) AS "schedules"
    `);
    assertCheck(
      Boolean(orphans) && Object.values(orphans).every((count) => count === 0),
      'direct orphan queries are all zero after owner deletion',
    );
    assertCheck(
      (await prisma.idempotencyKey.count({ where: { userId: user.id } })) ===
        0 && (await prisma.otpCode.count({ where: { phone } })) === 0,
      'non-cascading account rows are deleted',
    );
    const scheduled = await prisma.mediaUploadTicket.findUnique({
      where: { key: upload.key },
    });
    assertCheck(
      scheduled?.status === 'DELETE_PENDING' && scheduled.userId === null,
      'media ownership ledger survives account deletion as a durable job',
    );

    // Simulate the worker after every signed PUT URL and reservation has
    // expired; deleting earlier would allow the old URL to recreate the key.
    const expired = new Date(Date.now() - 60 * 60 * 1_000);
    await prisma.mediaUploadTicket.update({
      where: { key: upload.key },
      data: { expiresAt: expired, updatedAt: expired },
    });
    const cleanupKeys = await tickets.claimCleanupBatch();
    assertCheck(
      cleanupKeys?.includes(upload.key),
      'expired account media is atomically claimed by cleanup',
    );
    const cleanup = await media.deleteScheduledObjects(cleanupKeys ?? []);
    assertCheck(
      cleanup.deleted === 1 && cleanup.failed === 0,
      'account media object is deleted from real storage',
    );
    const tombstone = await prisma.mediaUploadTicket.findUnique({
      where: { key: upload.key },
    });
    assertCheck(
      tombstone?.status === 'DELETED' && tombstone.deletedAt !== null,
      'quota tombstone remains for the rolling usage window',
    );
    const afterDelete = await fetch(`${publicUrl}?smoke=${Date.now()}`, {
      cache: 'no-store',
    });
    assertCheck(
      afterDelete.status === 404,
      'deleted public media is no longer readable',
    );
    const sentinelTicket = await prisma.mediaUploadTicket.findUnique({
      where: { key: sentinelMediaKey },
    });
    const sentinelObject = await fetch(
      `${sentinelPublicUrl}?sentinel=${Date.now()}`,
      { cache: 'no-store' },
    );
    assertCheck(
      sentinelTicket?.status === 'VERIFIED' && sentinelObject.ok,
      'deleting one account preserves another account media and ticket',
    );
    assertCheck(
      (await prisma.user.count({ where: { id: sentinel.id } })) === 1 &&
        (await prisma.provider.count({ where: { id: provider.id } })) === 1,
      'deleting the plan owner preserves the provider account and business',
    );

    await users.deleteMe(sentinelCurrent, 'smoke-delete-sentinel');
    sentinelUserId = '';
    const preservedClientCost = await prisma.weddingCost.findUnique({
      where: { id: clientCost.id },
    });
    assertCheck(
      (await prisma.user.count({ where: { id: sentinel.id } })) === 0 &&
        (await prisma.provider.count({ where: { id: provider.id } })) === 0 &&
        (await prisma.conversation.count({
          where: {
            id: {
              in: [sharedConversation.id, secondClientConversation.id],
            },
          },
        })) === 0 &&
        (await prisma.quoteRequest.count({
          where: { id: { in: [clientQuote.id, secondClientQuote.id] } },
        })) === 0,
      'provider account deletion purges conversations and requests across customer plans',
    );
    assertCheck(
      (await prisma.user.count({ where: { id: client.id } })) === 1 &&
        (await prisma.weddingPlan.count({
          where: { id: { in: clientPlans.map((item) => item.id) } },
        })) === 2 &&
        preservedClientCost?.providerId === null &&
        preservedClientCost?.quoteOfferId === null &&
        preservedClientCost?.totalAmount.toString() === '2400',
      'provider deletion preserves customer plans and their WeddingCost',
    );
    assertCheck(
      (await prisma.provider.count({ where: { id: alternateProvider.id } })) ===
        1,
      'provider deletion does not remove another unowned business',
    );

    console.log('Overall Result: PASS');
  } finally {
    try {
      if (adminUserId) {
        await prisma.idempotencyKey.deleteMany({
          where: { userId: adminUserId },
        });
        if (adminPhone) {
          await prisma.otpCode.deleteMany({ where: { phone: adminPhone } });
        }
        await prisma.user.deleteMany({ where: { id: adminUserId } });
        adminUserId = '';
      }
      for (const account of [
        { id: userId, phone },
        { id: sentinelUserId, phone: sentinelPhone },
        { id: clientUserId, phone: clientPhone },
        { id: bareUserId, phone: barePhone },
      ]) {
        if (
          account.id &&
          (await prisma.user.count({ where: { id: account.id } })) > 0
        ) {
          await users.deleteMe(
            { id: account.id, phone: account.phone } as never,
            `smoke-delete-${account.id}`,
          );
        }
      }
      const ownedKeys = [
        mediaKey,
        sentinelMediaKey,
        conversationMediaKey,
      ].filter(Boolean);
      if (ownedKeys.length > 0) {
        await prisma.mediaUploadTicket.updateMany({
          where: { key: { in: ownedKeys }, status: { not: 'DELETED' } },
          data: {
            status: 'DELETE_PENDING',
            expiresAt: new Date(0),
            updatedAt: new Date(0),
          },
        });
        for (let batch = 0; batch < 10; batch += 1) {
          const keys = await tickets.claimCleanupBatch();
          if (!keys || keys.length === 0) break;
          await media.deleteScheduledObjects(keys);
          if (ownedKeys.every((key) => keys.includes(key))) break;
        }
        await prisma.mediaUploadTicket.deleteMany({
          where: { key: { in: ownedKeys } },
        });
      }
    } catch (cleanupError) {
      console.error('Account deletion smoke cleanup failed', cleanupError);
    } finally {
      await prisma.$disconnect();
    }
  }
}

void main().catch((error) => {
  console.error('Overall Result: FAIL');
  console.error(error);
  process.exitCode = 1;
});
