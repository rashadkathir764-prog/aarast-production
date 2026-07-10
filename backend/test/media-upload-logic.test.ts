import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import {
  assertOwnedMediaKey,
  normalizeMediaUpload,
} from '../src/media/media-upload-policy';
import { MediaStorageService } from '../src/media/media-storage.service';

test('provider media accepts only bounded raster wedding assets', () => {
  const upload = normalizeMediaUpload({
    purpose: 'provider-cover',
    fileName: ' My Cover.JPG ',
    contentType: 'image/jpeg',
    byteSize: 4_000_000,
  });
  assert.equal(upload.extension, 'jpg');
  assert.equal(upload.contentType, 'image/jpeg');
  assert.throws(
    () =>
      normalizeMediaUpload({
        purpose: 'provider-cover',
        fileName: 'video.mp4',
        contentType: 'video/mp4',
        byteSize: 100,
      }),
    BadRequestException,
  );
  assert.throws(
    () =>
      normalizeMediaUpload({
        purpose: 'chat-image',
        fileName: 'huge.png',
        contentType: 'image/png',
        byteSize: 10 * 1024 * 1024 + 1,
      }),
    BadRequestException,
  );
});

test('account avatars use the authenticated user media upload policy', () => {
  const upload = normalizeMediaUpload({
    purpose: 'user-avatar',
    fileName: 'avatar.webp',
    contentType: 'image/webp',
    byteSize: 1_500_000,
  });

  assert.equal(upload.purpose, 'user-avatar');
  assert.equal(upload.extension, 'webp');
  assert.throws(
    () =>
      normalizeMediaUpload({
        purpose: 'user-avatar',
        fileName: 'oversized.jpg',
        contentType: 'image/jpeg',
        byteSize: 5 * 1024 * 1024 + 1,
      }),
    BadRequestException,
  );
});

test('chat attachments accept only an opaque sender-owned storage key', () => {
  assert.doesNotThrow(() =>
    assertOwnedMediaKey(
      'chat-image/user-1/550e8400-e29b-41d4-a716-446655440000.webp',
      'chat-image',
      'user-1',
    ),
  );
  assert.throws(
    () =>
      assertOwnedMediaKey(
        'https://cdn.example.test/chat-image/user-1/550e8400-e29b-41d4-a716-446655440000.webp',
        'chat-image',
        'user-1',
      ),
    BadRequestException,
  );
  assert.throws(
    () =>
      assertOwnedMediaKey(
        'chat-image/user-2/550e8400-e29b-41d4-a716-446655440000.webp',
        'chat-image',
        'user-1',
      ),
    BadRequestException,
  );
  assert.throws(
    () =>
      assertOwnedMediaKey(
        'chat-image/user-1/../550e8400-e29b-41d4-a716-446655440000.webp',
        'chat-image',
        'user-1',
      ),
    BadRequestException,
  );
});

test('private chat uploads never return a public URL and GET links expire quickly', async () => {
  const previous = {
    endpoint: process.env.AARAST_MEDIA_ENDPOINT,
    bucket: process.env.AARAST_MEDIA_BUCKET,
    publicBase: process.env.AARAST_MEDIA_PUBLIC_BASE_URL,
    accessKey: process.env.AARAST_MEDIA_ACCESS_KEY_ID,
    secretKey: process.env.AARAST_MEDIA_SECRET_ACCESS_KEY,
  };
  Object.assign(process.env, {
    AARAST_MEDIA_ENDPOINT: 'https://storage.example.test',
    AARAST_MEDIA_BUCKET: 'aarast-media',
    AARAST_MEDIA_ACCESS_KEY_ID: 'test-access-key',
    AARAST_MEDIA_SECRET_ACCESS_KEY: 'test-secret-key',
  });
  delete process.env.AARAST_MEDIA_PUBLIC_BASE_URL;
  try {
    const storage = new MediaStorageService();
    const ticket = await storage.createUpload({ id: 'user-1' } as never, {
      purpose: 'chat-image',
      fileName: 'private.webp',
      contentType: 'image/webp',
      byteSize: 2048,
    });
    assert.equal(ticket.publicUrl, null);
    assert.equal(ticket.attachmentRef, ticket.key);
    assert.match(ticket.key, /^chat-image\/user-1\/.+\.webp$/);

    const access = await storage.createDownloadUrl(ticket.key);
    const signedUrl = new URL(access.downloadUrl);
    assert.match(signedUrl.hostname, /(^|\.)storage\.example\.test$/);
    assert.equal(access.expiresInSeconds, 120);
    assert.equal(signedUrl.searchParams.get('X-Amz-Expires'), '120');
  } finally {
    const restore = (name: string, value?: string) => {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    };
    restore('AARAST_MEDIA_ENDPOINT', previous.endpoint);
    restore('AARAST_MEDIA_BUCKET', previous.bucket);
    restore('AARAST_MEDIA_PUBLIC_BASE_URL', previous.publicBase);
    restore('AARAST_MEDIA_ACCESS_KEY_ID', previous.accessKey);
    restore('AARAST_MEDIA_SECRET_ACCESS_KEY', previous.secretKey);
  }
});

test('media upload route is authenticated and storage is environment configured', () => {
  const controller = readFileSync(
    join(process.cwd(), 'src/media/media.controller.ts'),
    'utf8',
  );
  const storage = readFileSync(
    join(process.cwd(), 'src/media/media-storage.service.ts'),
    'utf8',
  );
  assert.match(controller, /@Controller\('media\/uploads'\)/);
  assert.match(controller, /@UseGuards\(JwtAuthGuard\)/);
  assert.match(storage, /S3Client/);
  assert.match(storage, /getSignedUrl/);
  assert.match(storage, /AARAST_MEDIA_BUCKET/);
  assert.doesNotMatch(storage, /accessKeyId:\s*['"][^'"]+['"]/);
});

test('media storage creates a short-lived signed upload without network access', async () => {
  const previous = {
    endpoint: process.env.AARAST_MEDIA_ENDPOINT,
    bucket: process.env.AARAST_MEDIA_BUCKET,
    publicBase: process.env.AARAST_MEDIA_PUBLIC_BASE_URL,
    accessKey: process.env.AARAST_MEDIA_ACCESS_KEY_ID,
    secretKey: process.env.AARAST_MEDIA_SECRET_ACCESS_KEY,
  };
  Object.assign(process.env, {
    AARAST_MEDIA_ENDPOINT: 'https://storage.example.test',
    AARAST_MEDIA_BUCKET: 'aarast-media',
    AARAST_MEDIA_PUBLIC_BASE_URL: 'https://cdn.example.test',
    AARAST_MEDIA_ACCESS_KEY_ID: 'test-access-key',
    AARAST_MEDIA_SECRET_ACCESS_KEY: 'test-secret-key',
  });
  try {
    const ticket = await new MediaStorageService().createUpload(
      { id: 'user-1' } as never,
      {
        purpose: 'service-image',
        fileName: 'work.webp',
        contentType: 'image/webp',
        byteSize: 2048,
      },
    );
    assert.match(ticket.key, /^service-image\/user-1\/.+\.webp$/);
    assert.match(
      new URL(ticket.uploadUrl).hostname,
      /(^|\.)storage\.example\.test$/,
    );
    const publicUrl = ticket.publicUrl;
    assert.ok(publicUrl);
    assert.match(publicUrl, /^https:\/\/cdn\.example\.test\/service-image/);
    assert.equal(ticket.expiresInSeconds, 300);
  } finally {
    const restore = (name: string, value?: string) => {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    };
    restore('AARAST_MEDIA_ENDPOINT', previous.endpoint);
    restore('AARAST_MEDIA_BUCKET', previous.bucket);
    restore('AARAST_MEDIA_PUBLIC_BASE_URL', previous.publicBase);
    restore('AARAST_MEDIA_ACCESS_KEY_ID', previous.accessKey);
    restore('AARAST_MEDIA_SECRET_ACCESS_KEY', previous.secretKey);
  }
});
