import type { Prisma } from '@prisma/client';
import type { AuthenticatedUser } from '../../identity/public/identity-session.types';

export const MEDIA_STORAGE_PORT = Symbol('MEDIA_STORAGE_PORT');

export type MediaPurpose =
  | 'user-avatar'
  | 'provider-logo'
  | 'provider-cover'
  | 'service-image'
  | 'chat-image'
  | 'cost-receipt'
  // B-16 (D62): public like service images; a photo is listed to customers
  // only after review, and a refused one is deleted.
  | 'provider-portfolio'
  // D83: the plan's invitation card photo, read by its guests on their
  // public RSVP page. Uploaded and saved by its address like service
  // images, but the bucket keeps it private: it is read only through
  // createStoredMediaDownloadUrl, by the guest's link or a plan member.
  | 'guest-invitation-card';

/**
 * Purposes kept off the public CDN: read only through a short-lived signed
 * URL after the owner's authorization (chat images, and cost receipts,
 * V1 checklist 4.4).
 */
export const PRIVATE_MEDIA_PURPOSES: readonly MediaPurpose[] = ['chat-image', 'cost-receipt'];

export function isPrivateMediaPurpose(purpose: MediaPurpose): boolean {
  return PRIVATE_MEDIA_PURPOSES.includes(purpose);
}

/**
 * RA-MO-364, RA-BE-191: a cover or a logo is kept with two smaller copies,
 * made when it is verified: `thumb` for cards and lists, `medium` for a
 * screen-wide view. Each fits inside its size in pixels on its longer side.
 */
export const IMAGE_VARIANT_SIZES = { thumb: 480, medium: 1080 } as const;
export type ImageVariant = keyof typeof IMAGE_VARIANT_SIZES;

export const IMAGE_VARIANT_PURPOSES: readonly MediaPurpose[] = [
  'provider-logo',
  'provider-cover',
];

export function hasImageVariants(purpose: MediaPurpose): boolean {
  return IMAGE_VARIANT_PURPOSES.includes(purpose);
}

/**
 * Where a copy of the object at [keyOrUrl] is kept: its name without the
 * extension, the size, `.webp`. Works on a storage key and on its public
 * address alike.
 */
export function imageVariantKey(keyOrUrl: string, variant: ImageVariant): string {
  const extension = /\.[a-z0-9]+$/i;
  if (!extension.test(keyOrUrl)) {
    throw new Error('A media key without an extension has no image variants');
  }
  return keyOrUrl.replace(
    extension,
    `-${IMAGE_VARIANT_SIZES[variant]}.webp`,
  );
}

/** The public addresses of both copies of the image at [publicUrl]. */
export function imageVariantUrls(publicUrl: string): {
  thumbUrl: string;
  mediumUrl: string;
} {
  return {
    thumbUrl: imageVariantKey(publicUrl, 'thumb'),
    mediumUrl: imageVariantKey(publicUrl, 'medium'),
  };
}

export interface MediaConsumptionTarget {
  type:
    | 'USER_AVATAR'
    | 'USER_APP_AVATAR'
    | 'PROVIDER_LOGO'
    | 'PROVIDER_COVER'
    | 'SERVICE_IMAGE'
    | 'CHAT_ATTACHMENT'
    | 'COST_RECEIPT'
    | 'PORTFOLIO_ITEM'
    | 'GUEST_INVITATION_CARD';
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
  /**
   * A short-lived signed read of an object saved by its address for
   * `purpose` (under AARAST_MEDIA_PUBLIC_BASE_URL), whoever uploaded it.
   * The caller authorises the read; an address outside that purpose is a 400.
   */
  createStoredMediaDownloadUrl(
    publicUrl: string,
    purpose: MediaPurpose,
  ): Promise<{
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
  /**
   * The verified tickets consumed by these cost receipts become deletion
   * jobs, before finance deletes the receipt rows (V1 checklist 4.4).
   */
  scheduleCostReceiptDeletion(
    receiptIds: readonly string[],
    transaction: Prisma.TransactionClient,
  ): Promise<void>;
  checkReadiness(): Promise<void>;
}
