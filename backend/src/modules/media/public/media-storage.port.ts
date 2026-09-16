import type { Prisma } from '@prisma/client';
import type { AuthenticatedUser } from '../../identity/public/identity-session.types';

export const MEDIA_STORAGE_PORT = Symbol('MEDIA_STORAGE_PORT');

export type MediaPurpose =
  | 'user-avatar'
  | 'provider-logo'
  | 'provider-cover'
  | 'service-image'
  | 'chat-image';

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

export interface VerifiedMediaUpload {
  key: string;
  attachmentRef: string | null;
  publicUrl: string | null;
  contentType: string;
  byteSize: number;
  verified: true;
}

export interface MediaStoragePort {
  createDownloadUrl(storageKey: string): Promise<{
    downloadUrl: string;
    expiresInSeconds: number;
    expiresAt: Date;
  }>;
  verifyUpload(
    currentUser: AuthenticatedUser,
    storageKey: string,
    purpose: MediaPurpose,
  ): Promise<VerifiedMediaUpload>;
  verifyPublicMediaUrl(
    currentUser: AuthenticatedUser,
    value: string | null | undefined,
    purpose: MediaPurpose,
  ): Promise<string | null>;
  consumeUpload(
    currentUser: AuthenticatedUser,
    storageKey: string,
    purpose: MediaPurpose,
    target: MediaConsumptionTarget,
    transaction: Prisma.TransactionClient,
  ): Promise<void>;
  consumePublicMediaUrl(
    currentUser: AuthenticatedUser,
    value: string,
    purpose: MediaPurpose,
    target: MediaConsumptionTarget,
    transaction: Prisma.TransactionClient,
  ): Promise<void>;
  scheduleTargetDeletion(
    target: MediaConsumptionTarget,
    transaction: Prisma.TransactionClient,
  ): Promise<void>;
  scheduleAllOwnedMediaDeletion(
    userId: string,
    transaction: Prisma.TransactionClient,
  ): Promise<string[]>;
  scheduleApplicationIdentityMediaDeletion(
    userId: string,
    transaction: Prisma.TransactionClient,
  ): Promise<string[]>;
  lockAccountDeletionBoundary(
    userId: string,
    transaction: Prisma.TransactionClient,
  ): Promise<void>;
  /**
   * Account erasure: the verified tickets consumed by these chat attachments
   * become deletion jobs (a conversation can contain media uploaded by the
   * other party; its durable ticket must survive the cascade as a job).
   */
  scheduleChatAttachmentDeletion(
    attachmentIds: readonly string[],
    transaction: Prisma.TransactionClient,
  ): Promise<void>;
  checkReadiness(): Promise<void>;
}
