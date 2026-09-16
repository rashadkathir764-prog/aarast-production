import { randomUUID } from 'node:crypto';
import {
  BadRequestException,
  ConflictException,
  HttpException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  DeleteObjectsCommand,
  GetBucketLocationCommand,
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { Prisma } from '@prisma/client';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { CreateMediaUploadDto } from './dto/create-media-upload.dto';
import { sanitizeUploadedImage } from './media-image-sanitizer';
import {
  assertOwnedMediaKey,
  normalizeMediaUpload,
  ownedMediaKeyFromUrl,
} from './media-upload-policy';
import { MediaUploadTicketService } from './media-upload-ticket.service';
import type {
  MediaConsumptionTarget,
  MediaPurpose,
  MediaStoragePort,
  VerifiedMediaUpload,
} from '../modules/media/public/media-storage.port';

@Injectable()
export class MediaStorageService implements MediaStoragePort {
  static readonly downloadExpiresInSeconds = 120;

  constructor(private readonly tickets: MediaUploadTicketService) {}

  async createUpload(
    currentUser: AuthenticatedUser,
    dto: CreateMediaUploadDto,
  ) {
    const input = normalizeMediaUpload(dto);
    const config = this.config(input.purpose !== 'chat-image', true);
    const key = `${input.purpose}/${currentUser.id}/${randomUUID()}.${input.extension}`;
    const command = new PutObjectCommand({
      Bucket: config.bucket,
      Key: key,
      ContentType: input.contentType,
      ContentLength: input.byteSize,
      IfNoneMatch: '*',
      Metadata: { ownerUserId: currentUser.id, purpose: input.purpose },
    });
    await this.tickets.reserveUpload({
      key,
      userId: currentUser.id,
      purpose: input.purpose,
      contentType: input.contentType,
      declaredByteSize: input.byteSize,
    });
    try {
      const uploadUrl = await getSignedUrl(config.client, command, {
        expiresIn: MediaUploadTicketService.uploadUrlExpiresInSeconds,
        signableHeaders: new Set(['content-type', 'if-none-match']),
      });
      return {
        key,
        attachmentRef: null,
        uploadUrl,
        publicUrl: null,
        contentType: input.contentType,
        byteSize: input.byteSize,
        requiredHeaders: { 'If-None-Match': '*' },
        expiresInSeconds: MediaUploadTicketService.uploadUrlExpiresInSeconds,
      };
    } catch (error) {
      await this.tickets.discardReservation(key, currentUser.id);
      if (error instanceof HttpException) throw error;
      throw new ServiceUnavailableException(
        'Media upload could not be prepared',
      );
    } finally {
      config.client.destroy();
    }
  }

  async createDownloadUrl(storageKey: string) {
    const config = this.config(false, true);
    const expiresInSeconds = MediaStorageService.downloadExpiresInSeconds;
    try {
      const downloadUrl = await getSignedUrl(
        config.client,
        new GetObjectCommand({
          Bucket: config.bucket,
          Key: storageKey,
          ResponseCacheControl: 'private, no-store',
        }),
        { expiresIn: expiresInSeconds },
      );
      return {
        downloadUrl,
        expiresInSeconds,
        expiresAt: new Date(Date.now() + expiresInSeconds * 1000),
      };
    } finally {
      config.client.destroy();
    }
  }

  async verifyUpload(
    currentUser: AuthenticatedUser,
    storageKey: string,
    purpose: MediaPurpose,
  ): Promise<VerifiedMediaUpload> {
    assertOwnedMediaKey(storageKey, purpose, currentUser.id);
    const claim = await this.tickets.claimForVerification(
      storageKey,
      currentUser.id,
      purpose,
    );
    let config: ReturnType<MediaStorageService['config']> | null = null;
    try {
      config = this.config(purpose !== 'chat-image');
      const stored = await this.verifyStoredUpload(
        config,
        currentUser,
        storageKey,
        purpose,
        claim.alreadyVerified,
      );
      if (!claim.alreadyVerified) {
        await this.tickets.markVerified(storageKey, stored.byteSize);
      }
      return this.verifiedUploadResponse(
        storageKey,
        purpose,
        config.publicBaseUrl,
        stored.contentType,
        stored.byteSize,
      );
    } catch (error) {
      if (!claim.alreadyVerified) {
        await this.tickets.releaseVerification(storageKey);
      }
      if (error instanceof HttpException) throw error;
      const statusCode = this.storageStatusCode(error);
      if (statusCode != null && statusCode >= 400 && statusCode < 500) {
        throw new BadRequestException('Uploaded image could not be verified');
      }
      throw new ServiceUnavailableException(
        'Media storage is temporarily unavailable',
      );
    } finally {
      config?.client.destroy();
    }
  }

  async verifyPublicMediaUrl(
    currentUser: AuthenticatedUser,
    value: string | null | undefined,
    purpose: MediaPurpose,
  ): Promise<string | null> {
    if (value === null || value === undefined || !value.trim()) return null;
    const publicBaseUrl = process.env.AARAST_MEDIA_PUBLIC_BASE_URL?.trim();
    if (!publicBaseUrl) {
      throw new ServiceUnavailableException('Media storage is not configured');
    }
    const normalized = value.trim();
    const key = ownedMediaKeyFromUrl(
      normalized,
      publicBaseUrl,
      purpose,
      currentUser.id,
    );
    const verified = await this.verifyUpload(currentUser, key, purpose);
    return verified.publicUrl;
  }

  async consumeUpload(
    currentUser: AuthenticatedUser,
    storageKey: string,
    purpose: MediaPurpose,
    target: MediaConsumptionTarget,
    transaction: Prisma.TransactionClient,
  ): Promise<void> {
    assertOwnedMediaKey(storageKey, purpose, currentUser.id);
    await this.tickets.consume(
      storageKey,
      currentUser.id,
      target,
      transaction,
    );
  }

  async consumePublicMediaUrl(
    currentUser: AuthenticatedUser,
    value: string,
    purpose: MediaPurpose,
    target: MediaConsumptionTarget,
    transaction: Prisma.TransactionClient,
  ): Promise<void> {
    const publicBaseUrl = process.env.AARAST_MEDIA_PUBLIC_BASE_URL?.trim();
    if (!publicBaseUrl) {
      throw new ServiceUnavailableException('Media storage is not configured');
    }
    const key = ownedMediaKeyFromUrl(
      value,
      publicBaseUrl,
      purpose,
      currentUser.id,
    );
    await this.tickets.consume(key, currentUser.id, target, transaction);
  }

  scheduleTargetDeletion(
    target: MediaConsumptionTarget,
    transaction: Prisma.TransactionClient,
  ): Promise<void> {
    return this.tickets.scheduleTargetDeletion(target, transaction);
  }

  scheduleAllOwnedMediaDeletion(
    userId: string,
    transaction: Prisma.TransactionClient,
  ): Promise<string[]> {
    return this.tickets.scheduleUserDeletion(userId, transaction);
  }

  scheduleApplicationIdentityMediaDeletion(
    userId: string,
    transaction: Prisma.TransactionClient,
  ): Promise<string[]> {
    return this.tickets.scheduleApplicationIdentityDeletion(
      userId,
      transaction,
    );
  }

  lockAccountDeletionBoundary(
    userId: string,
    transaction: Prisma.TransactionClient,
  ): Promise<void> {
    return this.tickets.lockAccountDeletionBoundary(transaction, userId);
  }

  scheduleChatAttachmentDeletion(
    attachmentIds: readonly string[],
    transaction: Prisma.TransactionClient,
  ): Promise<void> {
    return this.tickets.scheduleChatAttachmentDeletion(
      transaction,
      attachmentIds,
    );
  }

  async deleteScheduledObjects(
    keys: string[],
  ): Promise<{ deleted: number; failed: number }> {
    if (keys.length === 0) return { deleted: 0, failed: 0 };
    let config: ReturnType<MediaStorageService['config']> | null = null;
    let deleted = 0;
    let failed = 0;
    try {
      config = this.config(false);
      for (let offset = 0; offset < keys.length; offset += 1_000) {
        const batch = keys.slice(offset, offset + 1_000);
        try {
          const result = await config.client.send(
            new DeleteObjectsCommand({
              Bucket: config.bucket,
              Delete: {
                Quiet: false,
                Objects: batch.map((Key) => ({ Key })),
              },
            }),
          );
          const failedKeys = new Set(
            (result.Errors ?? [])
              .map((error) => error.Key)
              .filter((key): key is string => Boolean(key)),
          );
          const deletedKeys = batch.filter((key) => !failedKeys.has(key));
          await this.tickets.confirmCleanupMany(deletedKeys);
          deleted += deletedKeys.length;
          failed += failedKeys.size;
        } catch {
          failed += batch.length;
        }
      }
    } finally {
      config?.client.destroy();
    }
    return { deleted, failed };
  }

  async checkReadiness(): Promise<void> {
    const config = this.config(false);
    try {
      await config.client.send(
        new GetBucketLocationCommand({ Bucket: config.bucket }),
      );
    } finally {
      config.client.destroy();
    }
  }

  private config(requirePublicBaseUrl: boolean, signForClient = false) {
    const storageEndpoint = process.env.AARAST_MEDIA_ENDPOINT?.trim();
    const signedEndpoint = process.env.AARAST_MEDIA_SIGNED_ENDPOINT?.trim();
    const endpoint = signForClient
      ? signedEndpoint || storageEndpoint
      : storageEndpoint;
    const bucket = process.env.AARAST_MEDIA_BUCKET?.trim();
    const publicBaseUrl = process.env.AARAST_MEDIA_PUBLIC_BASE_URL?.trim();
    if (
      !storageEndpoint ||
      !endpoint ||
      !bucket ||
      (requirePublicBaseUrl && !publicBaseUrl)
    ) {
      throw new ServiceUnavailableException('Media storage is not configured');
    }
    const accessKeyId = process.env.AARAST_MEDIA_ACCESS_KEY_ID?.trim();
    const secretAccessKey = process.env.AARAST_MEDIA_SECRET_ACCESS_KEY?.trim();
    return {
      bucket,
      publicBaseUrl: publicBaseUrl?.replace(/\/$/, ''),
      client: new S3Client({
        endpoint,
        region: process.env.AARAST_MEDIA_REGION?.trim() || 'auto',
        forcePathStyle: process.env.AARAST_MEDIA_FORCE_PATH_STYLE === 'true',
        ...(accessKeyId && secretAccessKey
          ? { credentials: { accessKeyId, secretAccessKey } }
          : {}),
      }),
    };
  }

  private verifiedUploadResponse(
    storageKey: string,
    purpose: MediaPurpose,
    publicBaseUrl: string | undefined,
    contentType: string,
    byteSize: number,
  ): VerifiedMediaUpload {
    return {
      key: storageKey,
      attachmentRef: purpose === 'chat-image' ? storageKey : null,
      publicUrl:
        purpose === 'chat-image' ? null : `${publicBaseUrl!}/${storageKey}`,
      contentType,
      byteSize,
      verified: true,
    };
  }

  private async verifyStoredUpload(
    config: ReturnType<MediaStorageService['config']>,
    currentUser: AuthenticatedUser,
    storageKey: string,
    purpose: MediaPurpose,
    mustAlreadyBeVerified: boolean,
  ): Promise<{ contentType: string; byteSize: number }> {
    for (let attempt = 0; attempt < 3; attempt += 1) {
      const head = await config.client.send(
        new HeadObjectCommand({ Bucket: config.bucket, Key: storageKey }),
      );
      const contentType = head.ContentType?.trim().toLowerCase() ?? '';
      const byteSize = head.ContentLength ?? 0;
      normalizeMediaUpload({
        purpose,
        fileName: storageKey,
        contentType,
        byteSize,
      });
      if (
        head.Metadata?.owneruserid !== currentUser.id ||
        head.Metadata?.purpose !== purpose
      ) {
        throw new BadRequestException(
          'Uploaded image metadata does not match this account',
        );
      }
      if (head.Metadata?.verified === 'true') {
        return { contentType, byteSize };
      }
      if (mustAlreadyBeVerified) {
        throw new BadRequestException(
          'Verified media object state does not match its upload ticket',
        );
      }
      const object = await config.client.send(
        new GetObjectCommand({ Bucket: config.bucket, Key: storageKey }),
      );
      const bytes = await object.Body?.transformToByteArray();
      if (!bytes) {
        throw new BadRequestException('Uploaded image is empty');
      }
      const sanitized = await sanitizeUploadedImage(bytes, contentType);
      normalizeMediaUpload({
        purpose,
        fileName: storageKey,
        contentType,
        byteSize: sanitized.length,
      });
      try {
        await config.client.send(
          new PutObjectCommand({
            Bucket: config.bucket,
            Key: storageKey,
            Body: sanitized,
            ContentType: contentType,
            ContentLength: sanitized.length,
            IfMatch: head.ETag,
            Metadata: {
              ownerUserId: currentUser.id,
              purpose,
              verified: 'true',
            },
          }),
        );
        return { contentType, byteSize: sanitized.length };
      } catch (error) {
        if (this.storageStatusCode(error) === 412 && attempt < 2) continue;
        if (this.storageStatusCode(error) === 412) {
          throw new ConflictException(
            'Media object changed repeatedly during verification',
          );
        }
        throw error;
      }
    }
    throw new ConflictException('Media upload verification could not settle');
  }

  private storageStatusCode(error: unknown): number | null {
    if (!error || typeof error !== 'object') return null;
    const metadata = (error as { $metadata?: { httpStatusCode?: unknown } })
      .$metadata;
    return typeof metadata?.httpStatusCode === 'number'
      ? metadata.httpStatusCode
      : null;
  }
}
