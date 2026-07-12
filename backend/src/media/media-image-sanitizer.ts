import { BadRequestException } from '@nestjs/common';
import sharp from 'sharp';
import { assertImageSignature } from './media-upload-policy';

const maxInputPixels = 25_000_000;
const maxDimension = 8_192;

export async function sanitizeUploadedImage(
  bytes: Uint8Array,
  contentType: string,
): Promise<Buffer> {
  assertImageSignature(bytes, contentType);
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
