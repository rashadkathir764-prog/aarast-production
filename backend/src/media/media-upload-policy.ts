import {
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';

export const mediaPurposes = [
  'user-avatar',
  'provider-logo',
  'provider-cover',
  'service-image',
  'chat-image',
] as const;

export type MediaPurpose = (typeof mediaPurposes)[number];

const extensionByContentType = new Map([
  ['image/jpeg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
]);

export interface MediaUploadInput {
  purpose: string;
  fileName: string;
  contentType: string;
  byteSize: number;
}

export function normalizeMediaUpload(input: MediaUploadInput) {
  if (!mediaPurposes.includes(input.purpose as MediaPurpose)) {
    throw new BadRequestException('Unsupported media purpose');
  }
  const contentType = input.contentType.trim().toLowerCase();
  const extension = extensionByContentType.get(contentType);
  if (!extension) {
    throw new BadRequestException(
      'Only JPEG, PNG, and WebP images are supported',
    );
  }
  if (!Number.isInteger(input.byteSize) || input.byteSize < 1) {
    throw new BadRequestException('Image size is invalid');
  }
  if (input.byteSize > 10 * 1024 * 1024) {
    throw new BadRequestException('Image must not exceed 10 MB');
  }
  if (input.purpose === 'user-avatar' && input.byteSize > 5 * 1024 * 1024) {
    throw new BadRequestException('Profile image must not exceed 5 MB');
  }
  return {
    purpose: input.purpose as MediaPurpose,
    fileName: input.fileName.trim(),
    contentType,
    byteSize: input.byteSize,
    extension,
  };
}

export function assertOwnedMediaUrl(
  value: string,
  publicBaseUrl: string,
  purpose: MediaPurpose,
  userId: string,
): void {
  let actual: URL;
  let base: URL;
  try {
    actual = new URL(value);
    base = new URL(publicBaseUrl);
  } catch {
    throw new BadRequestException('Media URL is invalid');
  }
  const basePath = base.pathname.replace(/\/$/, '');
  const expectedPrefix = `${basePath}/${purpose}/${userId}/`;
  if (
    actual.protocol !== 'https:' ||
    actual.origin !== base.origin ||
    !actual.pathname.startsWith(expectedPrefix)
  ) {
    throw new BadRequestException('Media URL is not owned by this account');
  }
}

/**
 * Chat attachments are private objects. The client may submit only the opaque
 * key returned by the signed-upload endpoint, never a public or external URL.
 */
export function assertOwnedMediaKey(
  value: string,
  purpose: MediaPurpose,
  userId: string,
): void {
  const normalized = value.trim();
  const escapedUserId = userId.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const expected = new RegExp(
    `^${purpose}/${escapedUserId}/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\\.(?:jpg|png|webp)$`,
    'i',
  );
  if (
    !expected.test(normalized) ||
    normalized.includes('..') ||
    normalized.includes('?') ||
    normalized.includes('#') ||
    normalized.includes('://')
  ) {
    throw new BadRequestException(
      'Media reference is not owned by this account',
    );
  }
}

/**
 * Validate an optional image URL submitted on a write (avatar, provider logo /
 * cover, service image). Returns the trimmed URL when it points to an object
 * this user uploaded through the signed-upload flow for `purpose`; returns null
 * for an empty value (clearing the image). Rejects any external or non-owned
 * URL, so the server never persists a link it does not control.
 */
export function normalizeOwnedMediaUrl(
  value: string | null | undefined,
  purpose: MediaPurpose,
  userId: string,
): string | null {
  if (value === null || value === undefined) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  const publicBaseUrl = process.env.AARAST_MEDIA_PUBLIC_BASE_URL?.trim();
  if (!publicBaseUrl) {
    throw new ServiceUnavailableException('Media storage is not configured');
  }
  assertOwnedMediaUrl(trimmed, publicBaseUrl, purpose, userId);
  return trimmed;
}

/**
 * Same ownership guarantee as {@link normalizeOwnedMediaUrl} but the URL is
 * mandatory (e.g. a service image row must carry one).
 */
export function requireOwnedMediaUrl(
  value: string | null | undefined,
  purpose: MediaPurpose,
  userId: string,
  field = 'imageUrl',
): string {
  const normalized = normalizeOwnedMediaUrl(value, purpose, userId);
  if (!normalized) {
    throw new BadRequestException(`${field} is required`);
  }
  return normalized;
}
