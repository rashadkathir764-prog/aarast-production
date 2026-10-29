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
import { MediaUploadTicketService } from '../../src/modules/media/infrastructure/media-upload-ticket.service';
import { UsersService } from '../../src/modules/identity/internal/profile/users.service';
import { DataExportService } from '../../src/modules/identity/internal/profile/data-export.service';
import { PermissionService } from '../../src/modules/collaboration/internal/permission.service';
import {
  accountDeletionService,
  erasureNotices,
  identityErasurePorts,
  ownerPorts,
} from './support/owner-ports';

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
  const permissions = new PermissionService(prisma as never, ownerPorts.plans);
  const users = new UsersService(
    prisma as never,
    permissions,
    media,
    ...identityErasurePorts,
  );
  // D63: the app asks for the deletion; the hourly purge erases the account
  // through the one saga once its 30 days are over.
  const deletion = accountDeletionService(prisma, users);
  const dataExports = new DataExportService(
    prisma as never,
    ownerPorts.plans,
    permissions,
    ownerPorts.finance,
    ownerPorts.tasks,
    ownerPorts.guests,
    ownerPorts.providers,
  );
  const DAY = 24 * 60 * 60 * 1000;
  /** Asks for the deletion, lets its 30 days pass, and runs the purge. */
  async function eraseThroughGrace(account: { id: string }): Promise<void> {
    await deletion.request(account as never, 'حذف');
    const past = new Date(Date.now() - 60_000);
    await prisma.user.update({
      where: { id: account.id },
      data: {
        deletionRequestedAt: new Date(past.getTime() - 30 * DAY),
        deletionScheduledFor: past,
      },
    });
    const purge = await deletion.purgeDueAccounts(new Date());
    if (purge.failures.length > 0) {
      throw new Error(
        `purge failed: ${purge.failures.map((failure) => failure.code).join(', ')}`,
      );
    }
  }
  async function refusal(promise: Promise<unknown>): Promise<string | null> {
    try {
      await promise;
      return null;
    } catch (error) {
      const http = error as { getResponse?: () => unknown; getStatus?: () => number };
      const body = http.getResponse?.();
      if (typeof body === 'object' && body && 'code' in body) {
        return String((body as { code: unknown }).code);
      }
      if (http.getStatus) return String(http.getStatus());
      throw error;
    }
  }

  /**
   * D63: the 30 days between the request and the erasure (w05, w06), the
   * one-time download (w40), B-33 at the request and at the purge, and n06.
   */
  async function graceChecks(): Promise<void> {
    const stamp = Date.now();
    const owner = await prisma.user.create({
      data: {
        name: 'سلمان المنصور',
        phone: `+96777${String(stamp + 11).slice(-7)}`,
        passwordHash: 'x',
      },
    });
    const member = await prisma.user.create({
      data: {
        name: 'صالح المنصور',
        phone: `+96777${String(stamp + 12).slice(-7)}`,
        passwordHash: 'x',
      },
    });
    const ownerSession = { id: owner.id } as never;
    const memberSession = { id: member.id } as never;
    const gracePlan = await prisma.weddingPlan.create({
      data: { ownerUserId: owner.id, title: `${tag}-grace-plan` },
    });
    await prisma.sharedMember.create({
      data: { weddingPlanId: gracePlan.id, userId: member.id },
    });
    const guestPhone = `+96777${String(stamp + 13).slice(-7)}`;
    await prisma.guest.create({
      data: {
        weddingPlanId: gracePlan.id,
        name: `${tag}-grace-guest`,
        normalizedName: `${tag}-grace-guest`,
        // The guests' CHECK: the stored phone is its normalized form.
        phone: guestPhone,
        normalizedPhone: guestPhone,
      },
    });
    try {
      const impact = await deletion.impact(ownerSession);
      assertCheck(
        impact.graceDays === 30 &&
          impact.ownedPlans.length === 1 &&
          impact.ownedPlans[0]?.memberNames.join() === 'صالح' &&
          impact.ownedPlans[0]?.upcomingBookings === 0 &&
          impact.provider === null &&
          impact.blockedBy === null,
        'w05: the impact names the plan, its member by first name and no booking',
      );
      assertCheck(
        (await refusal(deletion.request(ownerSession, 'احذف'))) ===
          'CONFIRM_WORD_MISMATCH',
        'w05: a wrong confirm word is refused',
      );
      erasureNotices.written.length = 0;
      const pending = await deletion.request(ownerSession, ' حذف ');
      assertCheck(
        pending.status === 'PENDING' &&
          pending.scheduledFor.getTime() - pending.requestedAt.getTime() ===
            30 * DAY,
        'the request waits exactly 30 days',
      );
      const again = await deletion.request(ownerSession, 'حذف');
      assertCheck(
        again.status === 'PENDING' &&
          again.scheduledFor.getTime() === pending.scheduledFor.getTime(),
        'asking again answers the same request',
      );
      assertCheck(
        erasureNotices.written.filter(
          (notice) =>
            notice.userId === member.id &&
            notice.type === NotificationType.PLAN_UPDATED &&
            notice.routeTarget === '/home',
        ).length === 1,
        'the member is told once that the plan is closed',
      );
      assertCheck(
        (await refusal(permissions.assertPlanReadable(gracePlan.id, memberSession))) ===
          '404',
        'w06: the member cannot open the plan while its owner waits',
      );
      const early = await deletion.purgeDueAccounts(new Date());
      assertCheck(
        early.erased === 0 &&
          early.failures.length === 0 &&
          (await prisma.user.count({ where: { id: owner.id } })) === 1,
        'the purge leaves an account whose 30 days are not over',
      );

      erasureNotices.written.length = 0;
      const restored = await deletion.cancel(ownerSession);
      const afterCancel = await prisma.user.findUniqueOrThrow({
        where: { id: owner.id },
      });
      assertCheck(
        restored.status === 'NONE' &&
          afterCancel.deletionRequestedAt === null &&
          afterCancel.deletionScheduledFor === null,
        'w06 «تراجعت، رجّع حسابي» takes the request back',
      );
      assertCheck(
        erasureNotices.written.some(
          (notice) =>
            notice.userId === member.id &&
            notice.routeTarget === `/wedding-plans/${gracePlan.id}/dashboard`,
        ),
        'the member is told the plan is back',
      );
      assertCheck(
        (await refusal(permissions.assertPlanReadable(gracePlan.id, memberSession))) ===
          null,
        'the member opens the plan again',
      );
      assertCheck(
        (await refusal(deletion.cancel(ownerSession))) === 'DELETION_NOT_PENDING',
        'taking back with nothing pending is refused',
      );

      const link = await dataExports.create(ownerSession);
      const token = link.downloadPath.split('/').pop()!;
      assertCheck(
        link.downloadPath.startsWith('/api/v1/data-exports/') &&
          link.expiresAt.getTime() - Date.now() <= 15 * 60_000 &&
          (await prisma.dataExport.count({ where: { tokenHash: token } })) === 0,
        'w40: the link expires within fifteen minutes and its token is not stored',
      );
      const file = (await dataExports.download(token)) as {
        body: {
          plans: Array<{
            title: string;
            members: Array<{ name: string | null }>;
            guests: unknown[];
          }>;
        };
      };
      const text = JSON.stringify(file.body);
      assertCheck(
        file.body.plans[0]?.title === gracePlan.title &&
          file.body.plans[0]?.members[0]?.name === 'صالح المنصور' &&
          file.body.plans[0]?.guests.length === 1,
        'the download holds the plan, its member and its guest',
      );
      assertCheck(
        !text.includes(member.phone!) && !text.includes(guestPhone),
        'the download holds no other person phone',
      );
      assertCheck(
        (await refusal(dataExports.download(token))) === 'EXPORT_LINK_INVALID',
        'the link works once',
      );
      const stale = await dataExports.create(ownerSession);
      await prisma.dataExport.update({
        where: { id: stale.id },
        data: {
          createdAt: new Date(Date.now() - 20 * 60_000),
          expiresAt: new Date(Date.now() - 5 * 60_000),
        },
      });
      assertCheck(
        (await refusal(dataExports.download(stale.downloadPath.split('/').pop()!))) ===
          'EXPORT_LINK_INVALID',
        'an expired link is refused',
      );

      // B-33 at the request: a provider with a wedding still to do.
      const graceCity = await prisma.city.create({
        data: { nameAr: `${tag}-grace-city`, countryCode: 'YE' },
      });
      const graceCategory = await prisma.providerCategory.create({
        data: { nameAr: `${tag}-grace-category`, slug: `${tag}-grace-category` },
      });
      const graceProvider = await prisma.provider.create({
        data: {
          userId: owner.id,
          cityId: graceCity.id,
          primaryCategoryId: graceCategory.id,
          businessName: `${tag}-grace-provider`,
          phone: `+96777${String(stamp + 14).slice(-7)}`,
          status: ProviderStatus.ACTIVE,
        },
      });
      const customerPlan = await prisma.weddingPlan.create({
        data: { ownerUserId: member.id, title: `${tag}-customer-plan` },
      });
      // A quote request lives in its plan's conversation with the provider.
      const bookedConversation = await prisma.conversation.create({
        data: {
          scope: ConversationScope.PLAN,
          weddingPlanId: customerPlan.id,
          providerId: graceProvider.id,
          createdByUserId: member.id,
          participants: { create: [{ userId: member.id }] },
        },
      });
      const bookedQuote = await prisma.quoteRequest.create({
        data: {
          userId: member.id,
          weddingPlanId: customerPlan.id,
          providerId: graceProvider.id,
          cityId: graceCity.id,
          conversationId: bookedConversation.id,
          status: QuoteRequestStatus.ACCEPTED,
          acceptedAt: new Date(),
          message: `${tag}-booked`,
        },
      });
      const booking = await prisma.booking.create({
        data: {
          quoteRequestId: bookedQuote.id,
          providerId: graceProvider.id,
          eventDate: new Date(
            `${new Date(Date.now() + 10 * DAY).toISOString().slice(0, 10)}T00:00:00.000Z`,
          ),
          status: 'CONFIRMED',
          confirmedAt: new Date(),
          requestedByUserId: member.id,
        },
      });
      const blockedImpact = await deletion.impact(ownerSession);
      assertCheck(
        blockedImpact.blockedBy === 'PROVIDER_HAS_UPCOMING_BOOKINGS' &&
          blockedImpact.provider?.upcomingBookings === 1,
        'w05: the impact shows the provider wedding that blocks the deletion',
      );
      assertCheck(
        (await refusal(deletion.request(ownerSession, 'حذف'))) ===
          'PROVIDER_HAS_UPCOMING_BOOKINGS',
        'B-33 at the request: a provider with an upcoming wedding is refused',
      );
      // B-33 at the purge: a wedding confirmed while the account waited.
      await prisma.user.update({
        where: { id: owner.id },
        data: {
          deletionRequestedAt: new Date(Date.now() - 31 * DAY),
          deletionScheduledFor: new Date(Date.now() - 60_000),
        },
      });
      const blockedPurge = await deletion.purgeDueAccounts(new Date());
      const failed = await prisma.user.findUniqueOrThrow({ where: { id: owner.id } });
      assertCheck(
        blockedPurge.failures.some(
          (failure) =>
            failure.userId === owner.id &&
            failure.code === 'PROVIDER_HAS_UPCOMING_BOOKINGS',
        ) &&
          failed.deletionPurgeFailure === 'PROVIDER_HAS_UPCOMING_BOOKINGS' &&
          failed.deletionPurgeFailedAt !== null,
        'B-33 at the purge: the failure is returned and recorded, nothing erased',
      );
      const requests = await prisma.$transaction((tx) =>
        deletion.listDataRequests(tx, new Date()),
      );
      assertCheck(
        requests.deletions.some(
          (row) =>
            row.userId === owner.id &&
            row.providerAccount &&
            row.purgeFailure === 'PROVIDER_HAS_UPCOMING_BOOKINGS',
        ) && requests.exports.filter((row) => row.userId === owner.id).length === 2,
        'n06 lists the waiting provider account with its failure, and its two downloads',
      );
      await prisma.$transaction((tx) =>
        deletion.restoreAccountDeletionInTransaction(tx, owner.id),
      );
      const restoredByAdmin = await prisma.user.findUniqueOrThrow({
        where: { id: owner.id },
      });
      assertCheck(
        restoredByAdmin.deletionScheduledFor === null &&
          restoredByAdmin.deletionPurgeFailure === null,
        'n06 «رجّعه بطلبه» takes the deletion back and forgets the failure',
      );

      await prisma.booking.update({
        where: { id: booking.id },
        data: { status: 'CANCELLED', cancelledAt: new Date(), cancelledBy: 'PROVIDER' },
      });
      erasureNotices.written.length = 0;
      await eraseThroughGrace({ id: owner.id });
      assertCheck(
        (await prisma.user.count({ where: { id: owner.id } })) === 0 &&
          (await prisma.weddingPlan.count({ where: { id: gracePlan.id } })) === 0 &&
          (await prisma.dataExport.count({ where: { userId: owner.id } })) === 0,
        'after its 30 days the account, its plan and its downloads are erased',
      );
      assertCheck(
        erasureNotices.written.some(
          (notice) =>
            notice.userId === member.id &&
            notice.type === NotificationType.PLAN_UPDATED &&
            notice.routeTarget === '/home',
        ),
        'the member is told the plan went with its owner',
      );
    } finally {
      for (const id of [owner.id, member.id]) {
        if ((await prisma.user.count({ where: { id } })) === 0) continue;
        await prisma.user.update({
          where: { id },
          data: {
            deletionRequestedAt: new Date(Date.now() - 31 * DAY),
            deletionScheduledFor: new Date(Date.now() - 60_000),
            deletionPurgeFailedAt: null,
            deletionPurgeFailure: null,
          },
        });
        await prisma.booking.updateMany({
          where: { providerId: { in: (await prisma.provider.findMany({ where: { userId: id }, select: { id: true } })).map((row) => row.id) }, status: 'CONFIRMED' },
          data: { status: 'CANCELLED', cancelledAt: new Date(), cancelledBy: 'PROVIDER' },
        });
        await users.eraseDueAccount(id, new Date());
      }
    }
  }
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
    await eraseThroughGrace({ id: bareUser.id });
    assertCheck(
      (await prisma.user.count({ where: { id: bareUser.id } })) === 0,
      'account with no plan deletes cleanly',
    );
    bareUserId = '';

    await graceChecks();

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
    await eraseThroughGrace({ id: administrator.id });
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
      retainedAdministrator.deletionRequestedAt === null &&
        retainedAdministrator.deletionScheduledFor === null,
      'the administrator keeps no pending deletion once its application identity is erased',
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

    erasureNotices.written.length = 0;
    await eraseThroughGrace({ id: user.id });
    assertCheck(
      erasureNotices.written.some(
        (notice) =>
          notice.userId === sentinel.id &&
          notice.type === NotificationType.BOOKING_UPDATED &&
          notice.routeTarget === '/provider/dashboard?tab=requests',
      ),
      'the provider of the erased customer open requests is told «حذف حسابه»',
    );
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

    await eraseThroughGrace({ id: sentinel.id });
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
          await prisma.user.update({
            where: { id: account.id },
            data: {
              deletionRequestedAt: new Date(Date.now() - 31 * DAY),
              deletionScheduledFor: new Date(Date.now() - 60_000),
            },
          });
          await users.eraseDueAccount(account.id, new Date());
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
