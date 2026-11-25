import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import { assertOwnedMediaKey } from "../src/media/media-upload-policy";
import { MediaStorageService } from "../src/media/media-storage.service";

// RA-BE-178 (rest): a receipt or a chat attachment outlives its uploader
// (D112: an erased member's receipt stays on the owner's cost), so its path
// must not carry who uploaded it. A new private upload is stored under an
// opaque segment; who owns it is its upload ticket's (`MediaUploadTicket`).
// Objects stored before keep their `<purpose>/<userId>/` path.

const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/;

async function withStorage<T>(
  run: (storage: MediaStorageService) => Promise<T>,
  publicBaseUrl?: string,
) {
  const names = [
    "AARAST_MEDIA_ENDPOINT",
    "AARAST_MEDIA_SIGNED_ENDPOINT",
    "AARAST_MEDIA_BUCKET",
    "AARAST_MEDIA_PUBLIC_BASE_URL",
    "AARAST_MEDIA_ACCESS_KEY_ID",
    "AARAST_MEDIA_SECRET_ACCESS_KEY",
  ] as const;
  const previous = Object.fromEntries(names.map((name) => [name, process.env[name]]));
  Object.assign(process.env, {
    AARAST_MEDIA_ENDPOINT: "https://storage.example.test",
    AARAST_MEDIA_SIGNED_ENDPOINT: "https://signed.example.test",
    AARAST_MEDIA_BUCKET: "aarast-media",
    AARAST_MEDIA_ACCESS_KEY_ID: "test-access-key",
    AARAST_MEDIA_SECRET_ACCESS_KEY: "test-secret-key",
  });
  if (publicBaseUrl) process.env.AARAST_MEDIA_PUBLIC_BASE_URL = publicBaseUrl;
  else delete process.env.AARAST_MEDIA_PUBLIC_BASE_URL;
  const reserved: Array<{ key: string; userId: string }> = [];
  try {
    const storage = new MediaStorageService({
      reserveUpload: async (input: { key: string; userId: string }) => {
        reserved.push({ key: input.key, userId: input.userId });
      },
      discardReservation: async () => undefined,
    } as never);
    await run(storage);
    return reserved;
  } finally {
    for (const name of names) {
      const value = previous[name];
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  }
}

for (const purpose of ["cost-receipt", "chat-image"] as const) {
  test(`RA-BE-178: a new ${purpose} is stored under an opaque segment, not its uploader's id`, async () => {
    let key = "";
    const reserved = await withStorage(async (storage) => {
      const ticket = await storage.createUpload({ id: "user-1" } as never, {
        purpose,
        fileName: "receipt.jpg",
        contentType: "image/jpeg",
        byteSize: 2048,
      });
      key = ticket.key;
    });
    assert.doesNotMatch(key, /user-1/);
    assert.match(
      key,
      new RegExp(`^${purpose}/${UUID.source}/${UUID.source}\\.jpg$`),
    );
    // The ticket still names the uploader: ownership is its, not the path's.
    assert.deepEqual(reserved, [{ key, userId: "user-1" }]);
    // The key the server handed out is the one it accepts back from him.
    assert.doesNotThrow(() => assertOwnedMediaKey(key, purpose, "user-1"));
  });
}

test("RA-BE-178: a private key is the opaque shape and nothing else", () => {
  const segment = "550e8400-e29b-41d4-a716-446655440000";
  const file = "0b1c2d3e-4f50-4a61-8b72-938495a6b7c8.webp";
  for (const refused of [
    // The old shape, with an id in the path, is no longer handed out.
    `chat-image/user-1/${file}`,
    `https://cdn.example.test/chat-image/${segment}/${file}`,
    `chat-image/${segment}/../${file}`,
    `cost-receipt/${segment}/${file}`,
    `chat-image/${segment}/${file}?x=1`,
  ]) {
    assert.throws(
      () => assertOwnedMediaKey(refused, "chat-image", "user-1"),
      BadRequestException,
      refused,
    );
  }
});

test("RA-BE-178: a public image keeps its owner-checked path", async () => {
  // Public images are checked by their address alone (`ownedMediaKeyFromUrl`);
  // they are the person's own and leave with the account.
  let key = "";
  await withStorage(async (storage) => {
    const ticket = await storage.createUpload({ id: "user-1" } as never, {
      purpose: "user-avatar",
      fileName: "me.jpg",
      contentType: "image/jpeg",
      byteSize: 2048,
    });
    key = ticket.key;
  }, "https://aarast-media.example.test");
  assert.match(key, new RegExp(`^user-avatar/user-1/${UUID.source}\\.jpg$`));
});
