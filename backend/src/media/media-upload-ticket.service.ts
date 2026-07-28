import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { MediaUploadStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { assertActiveMutationActorForUpdateInTransaction } from '../users/user-lifecycle-lock';
import { MediaPurpose } from './media-upload-policy';

export interface MediaUploadVerificationClaim {
  alreadyVerified: boolean;
}

export interface MediaConsumptionTarget {
  type:
    | 'USER_AVATAR'
    | 'USER_APP_AVATAR'
    | 'PROVIDER_LOGO'
    | 'PROVIDER_COVER'
    | 'SERVICE_IMAGE'
    | 'CHAT_ATTACHMENT';
  id: string;
}

@Injectable()
export class MediaUploadTicketService {
  static readonly uploadUrlExpiresInSeconds = 300;
  static readonly reservationTtlMs = 10 * 60 * 1_000;
  static readonly maximumUploadsPerRollingDay = 100;
  static readonly maximumDeclaredBytesPerRollingDay = 250 * 1024 * 1024;
  static readonly abandonedVerificationMs = 30 * 60 * 1_000;
  static readonly unconsumedVerifiedUploadMs = 24 * 60 * 60 * 1_000;
  static readonly cleanupBatchSize = 100;

  constructor(private readonly prisma: PrismaService) {}

  async reserveUpload(input: {
    key: string;
    userId: string;
    purpose: MediaPurpose;
    contentType: string;
    declaredByteSize: number;
  }): Promise<void> {
    const now = new Date();
    const rollingDayStartedAt = new Date(now.getTime() - 24 * 60 * 60 * 1_000);
    await this.prisma.$transaction(async (tx) => {
      await this.lockAccount(tx, input.userId);
      await assertActiveMutationActorForUpdateInTransaction(tx, input.userId);
      const uploadCount = await tx.mediaUploadTicket.count({
        where: {
          userId: input.userId,
          createdAt: { gte: rollingDayStartedAt },
        },
      });
      const aggregate = await tx.mediaUploadTicket.aggregate({
        where: {
          userId: input.userId,
          createdAt: { gte: rollingDayStartedAt },
        },
        _sum: { declaredByteSize: true },
      });
      const declaredBytes = aggregate._sum.declaredByteSize ?? 0;
      if (
        uploadCount >= MediaUploadTicketService.maximumUploadsPerRollingDay ||
        declaredBytes + input.declaredByteSize >
          MediaUploadTicketService.maximumDeclaredBytesPerRollingDay
      ) {
        throw new HttpException(
          'Daily media upload quota exceeded',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
      await tx.mediaUploadTicket.create({
        data: {
          key: input.key,
          userId: input.userId,
          purpose: input.purpose,
          contentType: input.contentType,
          declaredByteSize: input.declaredByteSize,
          expiresAt: new Date(
            now.getTime() + MediaUploadTicketService.reservationTtlMs,
          ),
        },
      });
    });
  }

  async discardReservation(key: string, userId: string): Promise<void> {
    // No URL was issued when signing fails, so no object or quota-consuming
    // client action can exist for this reservation.
    await this.prisma.mediaUploadTicket.deleteMany({
      where: { key, userId, status: MediaUploadStatus.PENDING },
    });
  }

  async claimForVerification(
    key: string,
    userId: string,
    purpose: MediaPurpose,
  ): Promise<MediaUploadVerificationClaim> {
    const now = new Date();
    return this.prisma.$transaction(async (tx) => {
      // Account deletion and upload reservation take the same advisory lock
      // before the User row. Matching that order makes lifecycle changes and
      // verification claims serialize without a User/account lock inversion.
      await this.lockAccount(tx, userId);
      await assertActiveMutationActorForUpdateInTransaction(tx, userId);

      const ticket = await tx.mediaUploadTicket.findUnique({
        where: { key },
        select: {
          userId: true,
          purpose: true,
          status: true,
          expiresAt: true,
        },
      });
      if (!ticket || ticket.userId !== userId || ticket.purpose !== purpose) {
        throw new BadRequestException('Media upload ticket is invalid');
      }
      if (ticket.status === MediaUploadStatus.VERIFIED) {
        return { alreadyVerified: true };
      }
      if (ticket.status === MediaUploadStatus.VERIFYING) {
        throw new ConflictException(
          'Media upload verification is in progress',
        );
      }
      if (
        ticket.status === MediaUploadStatus.DELETE_PENDING ||
        ticket.status === MediaUploadStatus.DELETED ||
        ticket.expiresAt.getTime() <= now.getTime()
      ) {
        throw new BadRequestException('Media upload ticket has expired');
      }
      const claimed = await tx.mediaUploadTicket.updateMany({
        where: {
          key,
          userId,
          purpose,
          status: MediaUploadStatus.PENDING,
          expiresAt: { gt: now },
        },
        data: { status: MediaUploadStatus.VERIFYING },
      });
      if (claimed.count !== 1) {
        throw new ConflictException(
          'Media upload verification is in progress',
        );
      }
      return { alreadyVerified: false };
    });
  }

  async markVerified(key: string, verifiedByteSize: number): Promise<void> {
    const result = await this.prisma.mediaUploadTicket.updateMany({
      where: { key, status: MediaUploadStatus.VERIFYING },
      data: {
        status: MediaUploadStatus.VERIFIED,
        verifiedByteSize,
        verifiedAt: new Date(),
      },
    });
    if (result.count === 1) return;
    const existing = await this.prisma.mediaUploadTicket.findUnique({
      where: { key },
      select: { status: true },
    });
    if (existing?.status !== MediaUploadStatus.VERIFIED) {
      throw new ServiceUnavailableException(
        'Media upload verification state could not be persisted',
      );
    }
  }

  async releaseVerification(key: string): Promise<void> {
    await this.prisma.mediaUploadTicket.updateMany({
      where: {
        key,
        status: MediaUploadStatus.VERIFYING,
        expiresAt: { gt: new Date() },
      },
      data: { status: MediaUploadStatus.PENDING },
    });
  }

  async consume(
    key: string,
    userId: string,
    target: MediaConsumptionTarget,
    transaction: Prisma.TransactionClient,
  ): Promise<void> {
    await this.lockTarget(transaction, target);
    const result = await transaction.mediaUploadTicket.updateMany({
      where: {
        key,
        userId,
        status: MediaUploadStatus.VERIFIED,
        OR: [
          { consumedAt: null },
          { consumedByType: target.type, consumedById: target.id },
        ],
      },
      data: {
        consumedAt: new Date(),
        consumedByType: target.type,
        consumedById: target.id,
      },
    });
    if (result.count !== 1) {
      throw new BadRequestException(
        'Verified media upload is unavailable or already used elsewhere',
      );
    }
  }

  async scheduleTargetDeletion(
    target: MediaConsumptionTarget,
    transaction: Prisma.TransactionClient,
  ): Promise<void> {
    await this.lockTarget(transaction, target);
    await transaction.mediaUploadTicket.updateMany({
      where: {
        status: MediaUploadStatus.VERIFIED,
        consumedByType: target.type,
        consumedById: target.id,
      },
      data: { status: MediaUploadStatus.DELETE_PENDING },
    });
  }

  async scheduleUserDeletion(
    userId: string,
    transaction: Prisma.TransactionClient,
  ): Promise<string[]> {
    await this.lockAccount(transaction, userId);
    const tickets = await transaction.mediaUploadTicket.findMany({
      where: { userId, status: { not: MediaUploadStatus.DELETED } },
      orderBy: { key: 'asc' },
      select: { key: true },
    });
    const keys = tickets.map((ticket) => ticket.key);
    if (keys.length > 0) {
      await transaction.mediaUploadTicket.updateMany({
        where: { key: { in: keys }, userId },
        data: { status: MediaUploadStatus.DELETE_PENDING },
      });
    }
    return keys;
  }

  async claimCleanupBatch(now = new Date()): Promise<string[] | null> {
    return this.prisma.$transaction(async (tx) => {
      const [lock] = await tx.$queryRaw<Array<{ locked: boolean }>>`
        SELECT pg_try_advisory_xact_lock(20260711, 4) AS locked
      `;
      if (!lock?.locked) return null;

      // Retain deleted ticket tombstones for the complete rolling quota window.
      await tx.mediaUploadTicket.deleteMany({
        where: {
          status: MediaUploadStatus.DELETED,
          createdAt: { lt: new Date(now.getTime() - 24 * 60 * 60 * 1_000) },
        },
      });

      const staleVerificationBefore = new Date(
        now.getTime() - MediaUploadTicketService.abandonedVerificationMs,
      );
      const staleVerifiedBefore = new Date(
        now.getTime() -
          MediaUploadTicketService.unconsumedVerifiedUploadMs,
      );

      // Selection and state transition are one row-locked SQL statement. A
      // concurrent domain transaction that consumes the ticket either wins
      // first (and no longer matches) or observes DELETE_PENDING and rolls back.
      const claimed = await tx.$queryRaw<Array<{ key: string }>>`
        WITH candidates AS (
          SELECT ticket."key"
          FROM "MediaUploadTicket" ticket
          WHERE
            (ticket."status" = 'PENDING' AND ticket."expiresAt" < ${now})
            OR (
              ticket."status" = 'VERIFYING'
              AND ticket."updatedAt" < ${staleVerificationBefore}
            )
            OR (
              ticket."status" = 'VERIFIED'
              AND ticket."consumedAt" IS NULL
              AND ticket."verifiedAt" < ${staleVerifiedBefore}
            )
            OR (
              ticket."status" = 'DELETE_PENDING'
              AND ticket."updatedAt" < ${staleVerificationBefore}
              AND ticket."expiresAt" < ${now}
            )
          ORDER BY ticket."createdAt" ASC, ticket."key" ASC
          FOR UPDATE SKIP LOCKED
          LIMIT ${MediaUploadTicketService.cleanupBatchSize}
        )
        UPDATE "MediaUploadTicket" ticket
        SET "status" = 'DELETE_PENDING', "updatedAt" = ${now}
        FROM candidates
        WHERE ticket."key" = candidates."key"
        RETURNING ticket."key"
      `;
      return claimed.map((ticket) => ticket.key);
    });
  }

  async countCleanupBacklog(now = new Date()): Promise<number> {
    const staleVerificationBefore = new Date(
      now.getTime() - MediaUploadTicketService.abandonedVerificationMs,
    );
    const staleVerifiedBefore = new Date(
      now.getTime() -
        MediaUploadTicketService.unconsumedVerifiedUploadMs,
    );
    return this.prisma.mediaUploadTicket.count({
      where: {
        OR: [
          { status: MediaUploadStatus.PENDING, expiresAt: { lt: now } },
          {
            status: MediaUploadStatus.VERIFYING,
            updatedAt: { lt: staleVerificationBefore },
          },
          {
            status: MediaUploadStatus.VERIFIED,
            consumedAt: null,
            verifiedAt: { lt: staleVerifiedBefore },
          },
          {
            status: MediaUploadStatus.DELETE_PENDING,
            updatedAt: { lt: staleVerificationBefore },
            expiresAt: { lt: now },
          },
        ],
      },
    });
  }

  async confirmCleanupMany(keys: string[]): Promise<void> {
    if (keys.length === 0) return;
    await this.prisma.mediaUploadTicket.updateMany({
      where: { key: { in: keys }, status: MediaUploadStatus.DELETE_PENDING },
      data: { status: MediaUploadStatus.DELETED, deletedAt: new Date() },
    });
  }

  private async lockAccount(
    transaction: Pick<Prisma.TransactionClient, '$queryRaw'>,
    userId: string,
  ): Promise<void> {
    await transaction.$queryRaw`
      SELECT 1 AS locked
      FROM (
        SELECT pg_advisory_xact_lock(
          hashtextextended(${userId}, 20260711)
        )
      ) acquired
    `;
  }

  private async lockTarget(
    transaction: Pick<Prisma.TransactionClient, '$queryRaw'>,
    target: MediaConsumptionTarget,
  ): Promise<void> {
    await transaction.$queryRaw`
      SELECT 1 AS locked
      FROM (
        SELECT pg_advisory_xact_lock(
          hashtextextended(${`${target.type}:${target.id}`}, 20260712)
        )
      ) acquired
    `;
  }
}
