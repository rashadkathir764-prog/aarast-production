import { BadRequestException } from '@nestjs/common';

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
    throw new BadRequestException('Only JPEG, PNG, and WebP images are supported');
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
