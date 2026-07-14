import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { plainToInstance } from "class-transformer";
import { validate } from "class-validator";
import type { ThrottlerStorage } from "@nestjs/throttler";
import type { ThrottlerStorageRecord } from "@nestjs/throttler/dist/throttler-storage-record.interface";
import { PhoneNormalizer } from "../src/common/phone/phone-normalizer";
import {
  ResilientThrottlerStorage,
  throttlerStorageFailureType,
} from "../src/common/redis/resilient-throttler-storage";
import {
  endOfRiyadhDay,
  startOfRiyadhDay,
} from "../src/common/time/business-day";
import { UpdateProfileDto } from "../src/users/dto/update-profile.dto";
import {
  normalizeWeddingLocationInput,
  weddingLocationResponse,
} from "../src/wedding-plans/wedding-location";

test("backend image records the supplied Git revision in its OCI metadata", () => {
  const dockerfile = readFileSync(join(__dirname, "..", "Dockerfile"), "utf8");
  const pinnedNodeImage =
    "node@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2";
  assert.equal(
    dockerfile.match(new RegExp(`^FROM ${pinnedNodeImage}`, "gm"))?.length,
    2,
  );
  assert.doesNotMatch(dockerfile, /^FROM node:22-alpine/m);
  const runtimeStage = dockerfile.slice(
    dockerfile.lastIndexOf(`${pinnedNodeImage} AS runtime`),
  );

  assert.match(
    runtimeStage,
    /^ARG AARAST_GIT_REVISION=development-unversioned$/m,
  );
  assert.match(
    runtimeStage,
    /AARAST_GIT_REVISION" != "development-unversioned"/,
  );
  assert.match(runtimeStage, /\$\{#AARAST_GIT_REVISION\}.*-ne 40/);
  assert.match(runtimeStage, /\*\[!0-9a-f\]\*/);
  assert.match(
    runtimeStage,
    /^LABEL org\.opencontainers\.image\.revision="\$\{AARAST_GIT_REVISION\}"$/m,
  );
});

test("normalizes supported Yemeni phone formats", () => {
  const expected = "+967777758200";
  assert.equal(PhoneNormalizer.normalizeRequired("777758200"), expected);
  assert.equal(PhoneNormalizer.normalizeRequired("0777758200"), expected);
  assert.equal(PhoneNormalizer.normalizeRequired("+967777758200"), expected);
  assert.equal(PhoneNormalizer.normalizeRequired("00967777758200"), expected);
});

test("normalizes Arabic and Persian digits", () => {
  const expected = "+967777758200";
  assert.equal(PhoneNormalizer.normalizeRequired("٠٧٧٧٧٥٨٢٠٠"), expected);
  assert.equal(PhoneNormalizer.normalizeRequired("۰۷۷۷۷۵۸۲۰۰"), expected);
});

test("preserves valid non-Yemen international numbers", () => {
  assert.equal(
    PhoneNormalizer.normalizeRequired("+1 (202) 555-0123"),
    "+12025550123",
  );
  assert.equal(
    PhoneNormalizer.normalizeRequired("0044 20 7946 0958"),
    "+442079460958",
  );
});

test("provides legacy lookup variants for normalized Yemen phones", () => {
  assert.deepEqual(PhoneNormalizer.lookupVariants("+967777758200"), [
    "+967777758200",
    "00967777758200",
    "967777758200",
    "0777758200",
    "777758200",
  ]);
});

test("returns null for empty optional phone and rejects malformed input", () => {
  assert.equal(PhoneNormalizer.normalizeOptional("   "), null);
  assert.throws(() => PhoneNormalizer.normalizeRequired("+96712"));
});

test("normalizes structured location and emits legacy compatibility keys", () => {
  const location = normalizeWeddingLocationInput({
    governorate: " صنعاء ",
    cityOrDistrict: " أمانة العاصمة ",
    areaOrNeighborhood: " حدة ",
    street: " شارع صفر ",
    detailedAddress: " بجوار المعلم ",
  });
  assert.ok(location);
  assert.equal(location.governorate, "صنعاء");
  assert.equal(location.city, "أمانة العاصمة");
  assert.equal(location.district, "حدة");
  assert.equal(location.addressNote, "بجوار المعلم");
});

test("maps legacy city-only plans into structured location responses", () => {
  const location = weddingLocationResponse(null, "عدن");
  assert.equal(location?.cityOrDistrict, "عدن");
  assert.equal(location?.city, "عدن");
});

test("requires governorate and city for the structured location contract", () => {
  assert.throws(() =>
    normalizeWeddingLocationInput({
      cityOrDistrict: "صنعاء",
      detailedAddress: "وصف",
    }),
  );
});

test("rejects oversized structured location values", () => {
  assert.throws(() =>
    normalizeWeddingLocationInput({
      governorate: "صنعاء",
      cityOrDistrict: "أمانة العاصمة",
      detailedAddress: "x".repeat(501),
    }),
  );
});

test("validates app role and wedding persona profile values", async () => {
  const valid = plainToInstance(UpdateProfileDto, {
    appRole: "WEDDING_USER",
    persona: "BRIDE",
  });
  assert.equal((await validate(valid)).length, 0);

  const invalid = plainToInstance(UpdateProfileDto, {
    appRole: "RANDOM_ROLE",
    persona: "RANDOM_PERSONA",
  });
  assert.ok((await validate(invalid)).length >= 2);
});

test("uses Riyadh calendar-day boundaries independently of server timezone", () => {
  const start = startOfRiyadhDay(new Date("2026-06-25T22:30:00.000Z"));
  assert.equal(start.toISOString(), "2026-06-25T21:00:00.000Z");
  assert.equal(endOfRiyadhDay(start).toISOString(), "2026-06-26T20:59:59.999Z");
});

test("Redis throttle outage falls back to an enforcing in-process limiter", async () => {
  const unavailableRedis: ThrottlerStorage = {
    async increment(): Promise<ThrottlerStorageRecord> {
      throw new Error("redis://user:secret@internal.example unavailable");
    },
  };
  let fallbackHits = 0;
  const localFallback: ThrottlerStorage = {
    async increment(): Promise<ThrottlerStorageRecord> {
      fallbackHits += 1;
      return {
        totalHits: fallbackHits,
        timeToExpire: 60_000,
        isBlocked: fallbackHits > 1,
        timeToBlockExpire: fallbackHits > 1 ? 60_000 : 0,
      };
    },
  };
  const storage = new ResilientThrottlerStorage(
    unavailableRedis,
    localFallback,
  );

  const first = await storage.increment(
    "auth-client",
    60_000,
    1,
    60_000,
    "default",
  );
  const second = await storage.increment(
    "auth-client",
    60_000,
    1,
    60_000,
    "default",
  );

  assert.equal(first.isBlocked, false);
  assert.equal(second.isBlocked, true);
  assert.equal(fallbackHits, 2);
  assert.equal(
    throttlerStorageFailureType(
      new Error("redis://user:secret@internal.example unavailable"),
    ),
    "Error",
  );
});
