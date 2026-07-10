import { randomUUID } from 'node:crypto';
import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import {
  GetObjectCommand,
  HeadBucketCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CreateMediaUploadDto } from './dto/create-media-upload.dto';
import { normalizeMediaUpload } from './media-upload-policy';

@Injectable()
export class MediaStorageService {
  static readonly downloadExpiresInSeconds = 120;

  async createUpload(
    currentUser: AuthenticatedUser,
    dto: CreateMediaUploadDto,
  ) {
    const input = normalizeMediaUpload(dto);
    const config = this.config(input.purpose !== 'chat-image');
    const key = `${input.purpose}/${currentUser.id}/${randomUUID()}.${input.extension}`;
    const command = new PutObjectCommand({
      Bucket: config.bucket,
      Key: key,
      ContentType: input.contentType,
      ContentLength: input.byteSize,
      Metadata: { ownerUserId: currentUser.id, purpose: input.purpose },
    });
    const uploadUrl = await getSignedUrl(config.client, command, {
      expiresIn: 300,
    });
    return {
      key,
      attachmentRef: input.purpose === 'chat-image' ? key : null,
      uploadUrl,
      publicUrl:
        input.purpose === 'chat-image'
          ? null
          : `${config.publicBaseUrl!}/${key}`,
      contentType: input.contentType,
      byteSize: input.byteSize,
      expiresInSeconds: 300,
    };
  }

  async createDownloadUrl(storageKey: string) {
    const config = this.config(false);
    const expiresInSeconds = MediaStorageService.downloadExpiresInSeconds;
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
  }

  async checkReadiness(): Promise<void> {
    const config = this.config(false);
    try {
      await config.client.send(new HeadBucketCommand({ Bucket: config.bucket }));
    } finally {
      config.client.destroy();
    }
  }

  private config(requirePublicBaseUrl: boolean) {
    const endpoint = process.env.AARAST_MEDIA_ENDPOINT?.trim();
    const bucket = process.env.AARAST_MEDIA_BUCKET?.trim();
    const publicBaseUrl = process.env.AARAST_MEDIA_PUBLIC_BASE_URL?.trim();
    if (!endpoint || !bucket || (requirePublicBaseUrl && !publicBaseUrl)) {
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
}
