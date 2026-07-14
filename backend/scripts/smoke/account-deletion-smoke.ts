import 'reflect-metadata';

import {
  OtpPurpose,
  PrismaClient,
  WeddingCostStatus,
} from '@prisma/client';
import sharp from 'sharp';
import { MediaStorageService } from '../../src/media/media-storage.service';
import { MediaUploadTicketService } from '../../src/media/media-upload-ticket.service';
import { UsersService } from '../../src/users/users.service';

const localMediaDefaults = {
  AARAST_MEDIA_ENDPOINT: 'http://127.0.0.1:9000',
  AARAST_MEDIA_SIGNED_ENDPOINT: 'http://127.0.0.1:9000',
  AARAST_MEDIA_BUCKET: 'aarast-media',
  AARAST_MEDIA_PUBLIC_BASE_URL: 'http://127.0.0.1:9000/aarast-media',
  AARAST_MEDIA_REGION: 'us-east-1',
  AARAST_MEDIA_FORCE_PATH_STYLE: 'true',
  AARAST_MEDIA_ACCESS_KEY_ID: 'aarast-local-media-key',
  AARAST_MEDIA_SECRET_ACCESS_KEY:
    'aarast-local-media-secret-change-me',
} as const;

function configureLocalMediaWhenNeeded(): void {
  const smokeUrl = new URL(
    process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115',
  );
  if (!['127.0.0.1', 'localhost', '::1'].includes(smokeUrl.hostname)) return;
  for (const [name, value] of Object.entries(localMediaDefaults)) {
    if (!process.env[name]?.trim()) process.env[name] = value;
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
    assertCheck(Boolean(verified.publicUrl), 'account avatar is fully verified');
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

    const plan = await prisma.weddingPlan.create({
      data: { ownerUserId: user.id, title: `${tag}-plan` },
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

    await users.deleteMe(currentUser);
    assertCheck(
      (await prisma.user.count({ where: { id: user.id } })) === 0,
      'account row is deleted after the complete Restrict chain',
    );
    assertCheck(
      (await prisma.weddingPlan.count({ where: { id: plan.id } })) === 0,
      'owned money plan graph is deleted',
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
      (await prisma.idempotencyKey.count({ where: { userId: user.id } })) === 0 &&
        (await prisma.otpCode.count({ where: { phone } })) === 0,
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
    assertCheck(afterDelete.status === 404, 'deleted public media is no longer readable');
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

    console.log('Overall Result: PASS');
  } finally {
    try {
      for (const account of [
        { id: userId, phone },
        { id: sentinelUserId, phone: sentinelPhone },
      ]) {
        if (
          account.id &&
          (await prisma.user.count({ where: { id: account.id } })) > 0
        ) {
          await users.deleteMe({ id: account.id, phone: account.phone } as never);
        }
      }
      const ownedKeys = [mediaKey, sentinelMediaKey].filter(Boolean);
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
