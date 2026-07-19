import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import {
  assertImageSignature,
  assertOwnedMediaKey,
  detectImageContentType,
  normalizeMediaUpload,
} from "../src/media/media-upload-policy";
import { MediaStorageService } from "../src/media/media-storage.service";
import { sanitizeUploadedImage } from "../src/media/media-image-sanitizer";
import sharp from "sharp";

const signingTicketStore = () => ({
  reserveUpload: async () => undefined,
  discardReservation: async () => undefined,
});

test("provider media accepts only bounded raster wedding assets", () => {
  const upload = normalizeMediaUpload({
    purpose: "provider-cover",
    fileName: " My Cover.JPG ",
    contentType: "image/jpeg",
    byteSize: 4_000_000,
  });
  assert.equal(upload.extension, "jpg");
  assert.equal(upload.contentType, "image/jpeg");
  assert.throws(
    () =>
      normalizeMediaUpload({
        purpose: "provider-cover",
        fileName: "video.mp4",
        contentType: "video/mp4",
        byteSize: 100,
      }),
    BadRequestException,
  );
  assert.throws(
    () =>
      normalizeMediaUpload({
        purpose: "chat-image",
        fileName: "huge.png",
        contentType: "image/png",
        byteSize: 10 * 1024 * 1024 + 1,
      }),
    BadRequestException,
  );
});

test("account avatars use the authenticated user media upload policy", () => {
  const upload = normalizeMediaUpload({
    purpose: "user-avatar",
    fileName: "avatar.webp",
    contentType: "image/webp",
    byteSize: 1_500_000,
  });

  assert.equal(upload.purpose, "user-avatar");
  assert.equal(upload.extension, "webp");
  assert.throws(
    () =>
      normalizeMediaUpload({
        purpose: "user-avatar",
        fileName: "oversized.jpg",
        contentType: "image/jpeg",
        byteSize: 5 * 1024 * 1024 + 1,
      }),
    BadRequestException,
  );
});

test("uploaded raster content must match the declared MIME signature", () => {
  const jpeg = Uint8Array.from([0xff, 0xd8, 0xff, 0xe0]);
  const png = Uint8Array.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
  ]);
  const webp = Uint8Array.from([
    0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50,
  ]);

  assert.equal(detectImageContentType(jpeg), "image/jpeg");
  assert.equal(detectImageContentType(png), "image/png");
  assert.equal(detectImageContentType(webp), "image/webp");
  assert.equal(detectImageContentType(Uint8Array.from([1, 2, 3])), null);
  assert.doesNotThrow(() => assertImageSignature(jpeg, "image/jpeg"));
  assert.throws(
    () => assertImageSignature(jpeg, "image/png"),
    BadRequestException,
  );
  assert.throws(
    () => assertImageSignature(Uint8Array.from([1, 2, 3]), "image/jpeg"),
    BadRequestException,
  );
});

test("uploaded images are fully decoded and re-encoded without trailing payloads", async () => {
  const valid = await sharp({
    create: {
      width: 4,
      height: 4,
      channels: 3,
      background: { r: 120, g: 20, b: 30 },
    },
  }).jpeg().toBuffer();
  const marker = Buffer.from("<script>not-image</script>");
  const sanitized = await sanitizeUploadedImage(
    Buffer.concat([valid, marker]),
    "image/jpeg",
  );

  assert.equal(sanitized.includes(marker), false);
  const metadata = await sharp(sanitized).metadata();
  assert.equal(metadata.format, "jpeg");
  assert.equal(metadata.width, 4);
  assert.equal(metadata.height, 4);
  await assert.rejects(
    () => sanitizeUploadedImage(Uint8Array.from([0xff, 0xd8, 0xff]), "image/jpeg"),
    BadRequestException,
  );
});

test("uploaded image dimensions are bounded before persistence", async () => {
  const tooWide = await sharp({
    create: {
      width: 8_193,
      height: 1,
      channels: 3,
      background: { r: 0, g: 0, b: 0 },
    },
  }).png().toBuffer();

  await assert.rejects(
    () => sanitizeUploadedImage(tooWide, "image/png"),
    BadRequestException,
  );
});

test("chat attachments accept only an opaque sender-owned storage key", () => {
  assert.doesNotThrow(() =>
    assertOwnedMediaKey(
      "chat-image/user-1/550e8400-e29b-41d4-a716-446655440000.webp",
      "chat-image",
      "user-1",
    ),
  );
  assert.throws(
    () =>
      assertOwnedMediaKey(
        "https://cdn.example.test/chat-image/user-1/550e8400-e29b-41d4-a716-446655440000.webp",
        "chat-image",
        "user-1",
      ),
    BadRequestException,
  );
  assert.throws(
    () =>
      assertOwnedMediaKey(
        "chat-image/user-2/550e8400-e29b-41d4-a716-446655440000.webp",
        "chat-image",
        "user-1",
      ),
    BadRequestException,
  );
  assert.throws(
    () =>
      assertOwnedMediaKey(
        "chat-image/user-1/../550e8400-e29b-41d4-a716-446655440000.webp",
        "chat-image",
        "user-1",
      ),
    BadRequestException,
  );
});

test("private chat uploads never return a public URL and GET links expire quickly", async () => {
  const previous = {
    endpoint: process.env.AARAST_MEDIA_ENDPOINT,
    signedEndpoint: process.env.AARAST_MEDIA_SIGNED_ENDPOINT,
    bucket: process.env.AARAST_MEDIA_BUCKET,
    publicBase: process.env.AARAST_MEDIA_PUBLIC_BASE_URL,
    accessKey: process.env.AARAST_MEDIA_ACCESS_KEY_ID,
    secretKey: process.env.AARAST_MEDIA_SECRET_ACCESS_KEY,
  };
  Object.assign(process.env, {
    AARAST_MEDIA_ENDPOINT: "https://storage.example.test",
    AARAST_MEDIA_SIGNED_ENDPOINT: "https://signed.example.test",
    AARAST_MEDIA_BUCKET: "aarast-media",
    AARAST_MEDIA_ACCESS_KEY_ID: "test-access-key",
    AARAST_MEDIA_SECRET_ACCESS_KEY: "test-secret-key",
  });
  delete process.env.AARAST_MEDIA_PUBLIC_BASE_URL;
  try {
    const storage = new MediaStorageService(signingTicketStore() as never);
    const ticket = await storage.createUpload({ id: "user-1" } as never, {
      purpose: "chat-image",
      fileName: "private.webp",
      contentType: "image/webp",
      byteSize: 2048,
    });
    assert.equal(ticket.publicUrl, null);
    assert.equal(ticket.attachmentRef, null);
    assert.equal(ticket.publicUrl, null);
    assert.match(ticket.key, /^chat-image\/user-1\/.+\.webp$/);

    const access = await storage.createDownloadUrl(ticket.key);
    const signedUrl = new URL(access.downloadUrl);
    assert.match(signedUrl.hostname, /(^|\.)signed\.example\.test$/);
    assert.equal(access.expiresInSeconds, 120);
    assert.equal(signedUrl.searchParams.get("X-Amz-Expires"), "120");
  } finally {
    const restore = (name: string, value?: string) => {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    };
    restore("AARAST_MEDIA_ENDPOINT", previous.endpoint);
    restore("AARAST_MEDIA_SIGNED_ENDPOINT", previous.signedEndpoint);
    restore("AARAST_MEDIA_BUCKET", previous.bucket);
    restore("AARAST_MEDIA_PUBLIC_BASE_URL", previous.publicBase);
    restore("AARAST_MEDIA_ACCESS_KEY_ID", previous.accessKey);
    restore("AARAST_MEDIA_SECRET_ACCESS_KEY", previous.secretKey);
  }
});

test("media upload route is authenticated and storage is environment configured", () => {
  const controller = readFileSync(
    join(process.cwd(), "src/media/media.controller.ts"),
    "utf8",
  );
  const storage = readFileSync(
    join(process.cwd(), "src/media/media-storage.service.ts"),
    "utf8",
  );
  assert.match(controller, /@Controller\(["']api\/v1\/media\/uploads["']\)/);
  assert.match(controller, /@UseGuards\(JwtAuthGuard\)/);
  assert.match(controller, /@Post\(['"]verify['"]\)/);
  assert.equal(
    (controller.match(/@Header\(["']Cache-Control["'], ["']private, no-store["']\)/g) ?? [])
      .length,
    2,
  );
  assert.match(storage, /S3Client/);
  assert.match(storage, /sanitizeUploadedImage/);
  assert.match(storage, /getSignedUrl/);
  assert.match(storage, /AARAST_MEDIA_BUCKET/);
  assert.doesNotMatch(storage, /accessKeyId:\s*['"][^'"]+['"]/);
});

test("media storage creates a short-lived signed upload without network access", async () => {
  const previous = {
    endpoint: process.env.AARAST_MEDIA_ENDPOINT,
    signedEndpoint: process.env.AARAST_MEDIA_SIGNED_ENDPOINT,
    bucket: process.env.AARAST_MEDIA_BUCKET,
    publicBase: process.env.AARAST_MEDIA_PUBLIC_BASE_URL,
    accessKey: process.env.AARAST_MEDIA_ACCESS_KEY_ID,
    secretKey: process.env.AARAST_MEDIA_SECRET_ACCESS_KEY,
  };
  Object.assign(process.env, {
    AARAST_MEDIA_ENDPOINT: "https://storage.example.test",
    AARAST_MEDIA_SIGNED_ENDPOINT: "https://uploads.example.test",
    AARAST_MEDIA_BUCKET: "aarast-media",
    AARAST_MEDIA_PUBLIC_BASE_URL: "https://cdn.example.test",
    AARAST_MEDIA_ACCESS_KEY_ID: "test-access-key",
    AARAST_MEDIA_SECRET_ACCESS_KEY: "test-secret-key",
  });
  try {
    const ticket = await new MediaStorageService(
      signingTicketStore() as never,
    ).createUpload(
      { id: "user-1" } as never,
      {
        purpose: "service-image",
        fileName: "work.webp",
        contentType: "image/webp",
        byteSize: 2048,
      },
    );
    assert.match(ticket.key, /^service-image\/user-1\/.+\.webp$/);
    assert.match(
      new URL(ticket.uploadUrl).hostname,
      /(^|\.)uploads\.example\.test$/,
    );
    const signedHeaders =
      new URL(ticket.uploadUrl).searchParams.get("X-Amz-SignedHeaders") ?? "";
    assert.match(signedHeaders, /(?:^|;)if-none-match(?:;|$)/);
    assert.deepEqual(ticket.requiredHeaders, { "If-None-Match": "*" });
    assert.equal(ticket.publicUrl, null);
    assert.equal(ticket.attachmentRef, null);
    assert.equal(ticket.expiresInSeconds, 300);
  } finally {
    const restore = (name: string, value?: string) => {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    };
    restore("AARAST_MEDIA_ENDPOINT", previous.endpoint);
    restore("AARAST_MEDIA_SIGNED_ENDPOINT", previous.signedEndpoint);
    restore("AARAST_MEDIA_BUCKET", previous.bucket);
    restore("AARAST_MEDIA_PUBLIC_BASE_URL", previous.publicBase);
    restore("AARAST_MEDIA_ACCESS_KEY_ID", previous.accessKey);
    restore("AARAST_MEDIA_SECRET_ACCESS_KEY", previous.secretKey);
  }
});

test("production compose provisions durable public media and passes the signed endpoint", () => {
  const compose = readFileSync(
    join(process.cwd(), "../deploy/dokploy/docker-compose.yml"),
    "utf8",
  );
  assert.match(compose, /^\s{2}media:\s*$/m);
  assert.match(compose, /^\s{2}media-init:\s*$/m);
  assert.match(compose, /aarast_media_data:\s*$/m);
  assert.match(
    compose,
    /AARAST_MEDIA_SIGNED_ENDPOINT:\s*\$\{AARAST_MEDIA_SIGNED_ENDPOINT/,
  );
  assert.match(compose, /aarast-media\.shadowgardn\.com/);
});
