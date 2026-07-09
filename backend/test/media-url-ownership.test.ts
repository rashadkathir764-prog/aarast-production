import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  BadRequestException,
  ServiceUnavailableException,
} from "@nestjs/common";
import {
  normalizeOwnedMediaUrl,
  requireOwnedMediaUrl,
} from "../src/media/media-upload-policy";
import { UsersService } from "../src/users/users.service";
import { ProviderDashboardService } from "../src/provider-dashboard/provider-dashboard.service";

const BASE = "https://cdn.example.test";
const owned = (purpose: string, userId: string) =>
  `${BASE}/${purpose}/${userId}/asset.webp`;

async function withMediaBase<T>(fn: () => T | Promise<T>): Promise<T> {
  const prev = process.env.AARAST_MEDIA_PUBLIC_BASE_URL;
  process.env.AARAST_MEDIA_PUBLIC_BASE_URL = BASE;
  try {
    return await fn();
  } finally {
    if (prev === undefined) delete process.env.AARAST_MEDIA_PUBLIC_BASE_URL;
    else process.env.AARAST_MEDIA_PUBLIC_BASE_URL = prev;
  }
}

const safeUserRow = (avatarUrl: string | null) => ({
  id: "u1",
  name: "T",
  phone: null,
  email: null,
  role: "USER",
  appRole: "WEDDING_USER",
  status: "ACTIVE",
  phoneVerifiedAt: null,
  lastLoginAt: null,
  avatarUrl,
  locale: "ar",
  activeWeddingPlanId: null,
  onboardingPath: null,
  persona: null,
  onboardingCompletedAt: null,
  createdAt: new Date(),
  updatedAt: new Date(),
});

// --- policy helpers -------------------------------------------------------

test("normalizeOwnedMediaUrl accepts owned, clears empty, rejects foreign", async () => {
  await withMediaBase(() => {
    assert.equal(
      normalizeOwnedMediaUrl(owned("user-avatar", "u1"), "user-avatar", "u1"),
      owned("user-avatar", "u1"),
    );
    assert.equal(normalizeOwnedMediaUrl("", "user-avatar", "u1"), null);
    assert.equal(normalizeOwnedMediaUrl(null, "user-avatar", "u1"), null);
    // external host
    assert.throws(
      () => normalizeOwnedMediaUrl("https://evil.test/x.webp", "user-avatar", "u1"),
      BadRequestException,
    );
    // owned bucket but a different user's path
    assert.throws(
      () => normalizeOwnedMediaUrl(owned("user-avatar", "u2"), "user-avatar", "u1"),
      BadRequestException,
    );
    // owned bucket but a different purpose
    assert.throws(
      () => normalizeOwnedMediaUrl(owned("provider-logo", "u1"), "user-avatar", "u1"),
      BadRequestException,
    );
    // http downgrade is rejected even on the owned host
    assert.throws(
      () =>
        normalizeOwnedMediaUrl(
          "http://cdn.example.test/user-avatar/u1/a.webp",
          "user-avatar",
          "u1",
        ),
      BadRequestException,
    );
  });
});

test("normalizeOwnedMediaUrl refuses a URL when media storage is unconfigured", () => {
  const prev = process.env.AARAST_MEDIA_PUBLIC_BASE_URL;
  delete process.env.AARAST_MEDIA_PUBLIC_BASE_URL;
  try {
    assert.throws(
      () =>
        normalizeOwnedMediaUrl(
          "https://cdn.example.test/user-avatar/u1/a.webp",
          "user-avatar",
          "u1",
        ),
      ServiceUnavailableException,
    );
  } finally {
    if (prev !== undefined) process.env.AARAST_MEDIA_PUBLIC_BASE_URL = prev;
  }
});

test("requireOwnedMediaUrl demands a non-empty owned URL", async () => {
  await withMediaBase(() => {
    assert.equal(
      requireOwnedMediaUrl(owned("service-image", "u1"), "service-image", "u1"),
      owned("service-image", "u1"),
    );
    assert.throws(
      () => requireOwnedMediaUrl("", "service-image", "u1"),
      BadRequestException,
    );
    assert.throws(
      () => requireOwnedMediaUrl(null, "service-image", "u1"),
      BadRequestException,
    );
    assert.throws(
      () => requireOwnedMediaUrl("https://evil.test/x.webp", "service-image", "u1"),
      BadRequestException,
    );
  });
});

// --- wiring: the write paths actually enforce ownership -------------------

test("profile update rejects an external avatar and stores an owned one", async () => {
  await withMediaBase(async () => {
    const prisma = {
      user: {
        findUnique: async () => null,
        update: async ({ data }: any) => safeUserRow(data.avatarUrl ?? null),
      },
    };
    const svc = new UsersService(prisma as any);
    const current = { id: "u1" } as any;

    await assert.rejects(
      () => svc.updateMe(current, { avatarUrl: "https://evil.test/pic.webp" } as any),
      BadRequestException,
    );

    const stored = await svc.updateMe(current, {
      avatarUrl: owned("user-avatar", "u1"),
    } as any);
    assert.equal(stored.avatarUrl, owned("user-avatar", "u1"));

    const cleared = await svc.updateMe(current, { avatarUrl: "" } as any);
    assert.equal(cleared.avatarUrl, null);
  });
});

test("service image creation rejects an external URL before persisting", async () => {
  await withMediaBase(async () => {
    const prisma = {
      providerService: {
        findFirst: async () => ({ id: "svc", provider: { userId: "u1" } }),
      },
      providerServiceImage: {
        create: async () => {
          throw new Error("must not persist an unowned URL");
        },
      },
    };
    const svc = new ProviderDashboardService(prisma as any, {} as any);
    const serviceId = "11111111-1111-4111-8111-111111111111";

    await assert.rejects(
      () =>
        svc.createServiceImage(
          { id: "u1" } as any,
          serviceId,
          { imageUrl: "https://evil.test/x.webp" } as any,
        ),
      BadRequestException,
    );
  });
});
