import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import { S3Client } from "@aws-sdk/client-s3";
import sharp from "sharp";
import {
  createImageVariants,
  imageJobs,
  sanitizeUploadedImage,
} from "../src/media/media-image-sanitizer";
import { MediaStorageService } from "../src/media/media-storage.service";
import {
  imageVariantKey,
  imageVariantUrls,
} from "../src/modules/media/public/media-storage.port";
import { MarketplacePresenter } from "../src/marketplace/marketplace.presenter";

// RA-BE-145: sharp decoded up to 25 megapixels inside the API with nothing to
// bound how many at once, on a t3.small. RA-BE-191 / RA-MO-364: covers and
// logos were kept only at up to 8192px, so the phone decoded a 13MB cover for
// a card a few hundred pixels wide.

const solid = (width: number, height: number) =>
  sharp({
    create: { width, height, channels: 3, background: { r: 200, g: 40, b: 90 } },
  });

test("an image over 12 megapixels is refused", async () => {
  const large = await solid(4_000, 3_001).png({ compressionLevel: 1 }).toBuffer();
  await assert.rejects(
    () => sanitizeUploadedImage(large, "image/png"),
    BadRequestException,
  );
  const fits = await solid(4_000, 3_000).jpeg().toBuffer();
  const sanitized = await sanitizeUploadedImage(fits, "image/jpeg");
  assert.equal((await sharp(sanitized).metadata()).width, 4_000);
});

test("sharp runs one job at a time", async () => {
  const photo = await solid(1_200, 900).jpeg().toBuffer();
  imageJobs.resetPeak();
  const results = await Promise.all([
    sanitizeUploadedImage(photo, "image/jpeg"),
    sanitizeUploadedImage(photo, "image/jpeg"),
    createImageVariants(photo),
    sanitizeUploadedImage(photo, "image/jpeg"),
  ]);
  assert.equal(results.length, 4);
  assert.equal(imageJobs.peak, 1);
});

test("a failed job does not stop the next one", async () => {
  const photo = await solid(10, 10).jpeg().toBuffer();
  const failing = imageJobs.run(async () => {
    throw new Error("broken");
  });
  await assert.rejects(failing, /broken/);
  assert.ok((await sanitizeUploadedImage(photo, "image/jpeg")).length > 0);
});

test("the copies fit 480 and 1080 pixels, WebP, never enlarged", async () => {
  const cover = await solid(2_200, 1_100).jpeg().toBuffer();
  const variants = await createImageVariants(cover);
  const thumb = await sharp(variants.thumb).metadata();
  const medium = await sharp(variants.medium).metadata();
  assert.deepEqual([thumb.format, thumb.width, thumb.height], ["webp", 480, 240]);
  assert.deepEqual([medium.format, medium.width, medium.height], ["webp", 1_080, 540]);

  const logo = await solid(300, 200).png().toBuffer();
  const small = await createImageVariants(logo);
  assert.equal((await sharp(small.thumb).metadata()).width, 300);
  assert.equal((await sharp(small.medium).metadata()).width, 300);
});

test("a copy's address is the image's own with its size", () => {
  const url = "https://media.example.test/provider-cover/u1/abc.jpg";
  assert.deepEqual(imageVariantUrls(url), {
    thumbUrl: "https://media.example.test/provider-cover/u1/abc-480.webp",
    mediumUrl: "https://media.example.test/provider-cover/u1/abc-1080.webp",
  });
  assert.equal(
    imageVariantKey("provider-logo/u1/abc.webp", "thumb"),
    "provider-logo/u1/abc-480.webp",
  );
});

type StoredObject = {
  body: Buffer;
  contentType: string;
  metadata: Record<string, string>;
  etag: string;
};

/** A bucket in memory behind S3Client.send, for the length of [run]. */
async function withBucket<T>(
  bucket: Map<string, StoredObject>,
  run: () => Promise<T>,
): Promise<T> {
  const original = S3Client.prototype.send;
  const previous = { ...process.env };
  Object.assign(process.env, {
    AARAST_MEDIA_ENDPOINT: "https://storage.example.test",
    AARAST_MEDIA_BUCKET: "aarast-media",
    AARAST_MEDIA_PUBLIC_BASE_URL: "https://media.example.test",
    AARAST_MEDIA_ACCESS_KEY_ID: "test-access-key",
    AARAST_MEDIA_SECRET_ACCESS_KEY: "test-secret-key",
  });
  let etags = 0;
  (S3Client.prototype as any).send = async function send(command: any) {
    const input = command.input;
    switch (command.constructor.name) {
      case "HeadObjectCommand": {
        const object = bucket.get(input.Key);
        if (!object) throw Object.assign(new Error("NotFound"), { $metadata: { httpStatusCode: 404 } });
        return {
          ContentType: object.contentType,
          ContentLength: object.body.length,
          Metadata: object.metadata,
          ETag: object.etag,
        };
      }
      case "GetObjectCommand": {
        const object = bucket.get(input.Key)!;
        return { Body: { transformToByteArray: async () => new Uint8Array(object.body) } };
      }
      case "PutObjectCommand": {
        const existing = bucket.get(input.Key);
        if (input.IfMatch && existing?.etag !== input.IfMatch) {
          throw Object.assign(new Error("PreconditionFailed"), { $metadata: { httpStatusCode: 412 } });
        }
        bucket.set(input.Key, {
          body: Buffer.from(input.Body),
          contentType: input.ContentType,
          metadata: Object.fromEntries(
            Object.entries(input.Metadata ?? {}).map(([key, value]) => [key.toLowerCase(), String(value)]),
          ),
          etag: `"etag-${++etags}"`,
        });
        return {};
      }
      case "DeleteObjectsCommand": {
        for (const { Key } of input.Delete.Objects) bucket.delete(Key);
        return { Errors: [] };
      }
      default:
        throw new Error(`unexpected ${command.constructor.name}`);
    }
  };
  try {
    return await run();
  } finally {
    S3Client.prototype.send = original;
    process.env = previous;
  }
}

const tickets = (alreadyVerified = false) => {
  const confirmed: string[] = [];
  return {
    confirmed,
    claimForVerification: async () => ({ alreadyVerified }),
    markVerified: async () => undefined,
    releaseVerification: async () => undefined,
    confirmCleanupMany: async (keys: string[]) => {
      confirmed.push(...keys);
    },
  };
};

test("a verified cover is kept with its two copies beside it", async () => {
  const bucket = new Map<string, StoredObject>();
  const key = "provider-cover/u1/550e8400-e29b-41d4-a716-446655440000.jpg";
  bucket.set(key, {
    body: await solid(2_000, 1_000).jpeg().toBuffer(),
    contentType: "image/jpeg",
    metadata: { owneruserid: "u1", purpose: "provider-cover" },
    etag: '"etag-0"',
  });
  await withBucket(bucket, async () => {
    const storage = new MediaStorageService(tickets() as never);
    const verified = await storage.verifyUpload({ id: "u1" } as never, key, "provider-cover");
    assert.equal(bucket.get(key)!.metadata.verified, "true");
    assert.equal(bucket.get(key)!.metadata.variants, "480,1080");
    const urls = imageVariantUrls(verified.publicUrl!);
    for (const [url, width] of [[urls.thumbUrl, 480], [urls.mediumUrl, 1_080]] as const) {
      const copy = bucket.get(url.replace("https://media.example.test/", ""));
      assert.ok(copy, url);
      assert.equal(copy.contentType, "image/webp");
      assert.equal((await sharp(copy.body).metadata()).width, width);
    }
  });
});

test("a cover verified before the copies existed gets them when verified again", async () => {
  const bucket = new Map<string, StoredObject>();
  const key = "provider-logo/u1/550e8400-e29b-41d4-a716-446655440001.png";
  bucket.set(key, {
    body: await solid(900, 900).png().toBuffer(),
    contentType: "image/png",
    metadata: { owneruserid: "u1", purpose: "provider-logo", verified: "true" },
    etag: '"etag-0"',
  });
  await withBucket(bucket, async () => {
    const storage = new MediaStorageService(tickets(true) as never);
    await storage.verifyUpload({ id: "u1" } as never, key, "provider-logo");
    assert.equal(bucket.get(key)!.metadata.variants, "480,1080");
    assert.ok(bucket.has(imageVariantKey(key, "thumb")));
    assert.ok(bucket.has(imageVariantKey(key, "medium")));
  });
});

test("a service image has no copies", async () => {
  const bucket = new Map<string, StoredObject>();
  const key = "service-image/u1/550e8400-e29b-41d4-a716-446655440002.jpg";
  bucket.set(key, {
    body: await solid(800, 600).jpeg().toBuffer(),
    contentType: "image/jpeg",
    metadata: { owneruserid: "u1", purpose: "service-image" },
    etag: '"etag-0"',
  });
  await withBucket(bucket, async () => {
    const storage = new MediaStorageService(tickets() as never);
    await storage.verifyUpload({ id: "u1" } as never, key, "service-image");
    assert.deepEqual([...bucket.keys()], [key]);
    assert.equal(bucket.get(key)!.metadata.variants, undefined);
  });
});

test("a deleted cover takes its copies with it", async () => {
  const cover = "provider-cover/u1/550e8400-e29b-41d4-a716-446655440003.jpg";
  const service = "service-image/u1/550e8400-e29b-41d4-a716-446655440004.jpg";
  const object = (contentType: string): StoredObject => ({
    body: Buffer.from("x"),
    contentType,
    metadata: {},
    etag: '"e"',
  });
  const bucket = new Map<string, StoredObject>([
    [cover, object("image/jpeg")],
    [imageVariantKey(cover, "thumb"), object("image/webp")],
    [imageVariantKey(cover, "medium"), object("image/webp")],
    [service, object("image/jpeg")],
  ]);
  await withBucket(bucket, async () => {
    const store = tickets();
    const storage = new MediaStorageService(store as never);
    assert.deepEqual(await storage.deleteScheduledObjects([cover, service]), {
      deleted: 2,
      failed: 0,
    });
    assert.equal(bucket.size, 0);
    assert.deepEqual(store.confirmed, [cover, service]);
  });
});

test("the marketplace sends the copies with the provider", () => {
  const provider = {
    logoUrl: "https://media.example.test/provider-logo/u1/a.png",
    coverUrl: "https://media.example.test/provider-cover/u1/b.jpg",
    logoThumbUrl: "https://media.example.test/provider-logo/u1/a-480.webp",
    logoMediumUrl: "https://media.example.test/provider-logo/u1/a-1080.webp",
    coverThumbUrl: "https://media.example.test/provider-cover/u1/b-480.webp",
    coverMediumUrl: "https://media.example.test/provider-cover/u1/b-1080.webp",
  };
  const listed = MarketplacePresenter.toProviderListResponse({
    ...provider,
    id: "p1",
    cityId: null,
    primaryCategoryId: null,
    businessName: "قاعة",
    ownerName: null,
    phone: null,
    whatsapp: null,
    email: null,
    description: null,
    address: null,
    latitude: null,
    longitude: null,
    status: "ACTIVE",
    featuredPeriods: [],
    ratingAverage: { toString: () => "0" },
    ratingCount: 0,
    city: null,
    primaryCategory: null,
    servicePreviews: [],
  } as never) as Record<string, unknown>;
  for (const field of Object.keys(provider)) {
    assert.equal(listed[field], provider[field as keyof typeof provider], field);
  }
  const presenter = MarketplacePresenter as any;
  const summary = presenter.toProviderSummary({
    ...provider,
    id: "p1",
    businessName: "قاعة",
    phone: "+967777000000",
    whatsapp: null,
    status: "ACTIVE",
    ratingAverage: { toString: () => "0" },
    ratingCount: 0,
    city: { id: "c1", nameAr: "صنعاء", nameEn: "Sanaa", slug: "sanaa" },
    primaryCategory: null,
  });
  assert.equal(summary.logoThumbUrl, provider.logoThumbUrl);
});
