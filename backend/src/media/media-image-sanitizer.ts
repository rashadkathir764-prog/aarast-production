import { BadRequestException } from '@nestjs/common';
import sharp from 'sharp';
import {
  IMAGE_VARIANT_SIZES,
  type ImageVariant,
} from '../modules/media/public/media-storage.port';
import { assertImageSignature } from './media-upload-policy';

// RA-BE-145: a decoded image costs about four bytes a pixel; at 25 million
// pixels one upload held some 100MB, and several at once on a t3.small
// starved the API. 12 million covers every phone camera in use.
export const maxInputPixels = 12_000_000;
const maxDimension = 8_192;

/**
 * One sharp job at a time (RA-BE-145): uploads were decoded side by side,
 * each holding its full image in memory, with nothing to bound them. A job
 * waits for the one before it; a failed job does not stop the next.
 */
export class ImageJobQueue {
  private tail: Promise<unknown> = Promise.resolve();
  private running = 0;
  private highest = 0;

  /** The most jobs seen running at once since the last [resetPeak]. */
  get peak(): number {
    return this.highest;
  }

  resetPeak(): void {
    this.highest = this.running;
  }

  run<T>(job: () => Promise<T>): Promise<T> {
    const result = this.tail.then(async () => {
      this.running += 1;
      this.highest = Math.max(this.highest, this.running);
      try {
        return await job();
      } finally {
        this.running -= 1;
      }
    });
    this.tail = result.catch(() => undefined);
    return result;
  }
}

export const imageJobs = new ImageJobQueue();

export function sanitizeUploadedImage(
  bytes: Uint8Array,
  contentType: string,
): Promise<Buffer> {
  assertImageSignature(bytes, contentType);
  return imageJobs.run(() => sanitize(bytes, contentType));
}

async function sanitize(bytes: Uint8Array, contentType: string) {
  try {
    const input = Buffer.from(bytes);
    const metadata = await sharp(input, {
      limitInputPixels: maxInputPixels,
      failOn: 'warning',
      animated: false,
    }).metadata();
    const expectedFormat = contentType === 'image/jpeg'
      ? 'jpeg'
      : contentType === 'image/png'
        ? 'png'
        : 'webp';
    if (
      metadata.format !== expectedFormat ||
      !metadata.width ||
      !metadata.height ||
      metadata.width > maxDimension ||
      metadata.height > maxDimension ||
      metadata.width * metadata.height > maxInputPixels ||
      (metadata.pages ?? 1) !== 1
    ) {
      throw new BadRequestException('Uploaded image dimensions are invalid');
    }

    let pipeline = sharp(input, {
      limitInputPixels: maxInputPixels,
      failOn: 'warning',
      animated: false,
    }).autoOrient();
    if (contentType === 'image/jpeg') {
      pipeline = pipeline.jpeg({ quality: 90, progressive: true });
    } else if (contentType === 'image/png') {
      pipeline = pipeline.png({ compressionLevel: 9, adaptiveFiltering: true });
    } else {
      pipeline = pipeline.webp({ quality: 90, effort: 5 });
    }
    return await pipeline.toBuffer();
  } catch (error) {
    if (error instanceof BadRequestException) throw error;
    throw new BadRequestException('Uploaded file is not a decodable image');
  }
}

/**
 * The smaller copies of a sanitized cover or logo (RA-MO-364, RA-BE-191):
 * the phone drew a cover of up to 8192px, some 13MB decoded, for a card a
 * few hundred pixels wide. Each fits inside its size on its longer side,
 * is never enlarged, and is WebP (which keeps a logo's transparency).
 */
export function createImageVariants(
  sanitized: Buffer,
): Promise<Record<ImageVariant, Buffer>> {
  return imageJobs.run(async () => {
    const variants = {} as Record<ImageVariant, Buffer>;
    // One after the other: the queue's one job is one sharp pipeline.
    for (const variant of Object.keys(IMAGE_VARIANT_SIZES) as ImageVariant[]) {
      const size = IMAGE_VARIANT_SIZES[variant];
      variants[variant] = await sharp(sanitized, {
        limitInputPixels: maxInputPixels,
        failOn: 'warning',
        animated: false,
      })
        .resize({
          width: size,
          height: size,
          fit: 'inside',
          withoutEnlargement: true,
        })
        .webp({ quality: 80, effort: 4 })
        .toBuffer();
    }
    return variants;
  });
}
