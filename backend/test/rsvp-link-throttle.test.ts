import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Reflector } from "@nestjs/core";
import { ThrottlerException, ThrottlerGuard, ThrottlerStorageService } from "@nestjs/throttler";
import { PublicRsvpController } from "../src/guests/guest-rsvp.controller";
import {
  RSVP_ADDRESS_LIMIT,
  rsvpAddressThrottler,
  rsvpLinkTracker,
} from "../src/guests/rsvp-throttle";

// RA-BE-172: the guest's routes count per link and address.

const tracker = (ip: string, token: string) =>
  rsvpLinkTracker({ ip, params: { token } }, {} as never);

test("two guests behind one address are counted apart, one link from two addresses too", async () => {
  assert.notEqual(await tracker("10.0.0.1", "A".repeat(43)), await tracker("10.0.0.1", "B".repeat(43)));
  assert.notEqual(await tracker("10.0.0.1", "A".repeat(43)), await tracker("10.0.0.2", "A".repeat(43)));
  assert.equal(await tracker("10.0.0.1", "A".repeat(43)), await tracker("10.0.0.1", "A".repeat(43)));
});

test("every public RSVP route that names a link counts by it", () => {
  const routes = ["getInvitation", "opened", "respond", "preview", "cardPhoto"] as const;
  for (const route of routes) {
    const handler = PublicRsvpController.prototype[route] as unknown as object;
    assert.equal(
      Reflect.getMetadata("THROTTLER:TRACKERdefault", handler),
      rsvpLinkTracker,
      `${route} must count per link and address`,
    );
    assert.ok(Reflect.getMetadata("THROTTLER:LIMITdefault", handler) > 0);
  }
});

// I-1: an address-wide ceiling beside the per-link window.

function guestRoute(route: "getInvitation" | "opened" | "respond" | "preview" | "cardPhoto") {
  return PublicRsvpController.prototype[route] as unknown as (...args: never[]) => unknown;
}

function contextFor(handler: (...args: never[]) => unknown, ip: string, token: string) {
  const headers = new Map<string, unknown>();
  const request = { ip, params: { token }, headers: {} };
  const response = { header: (name: string, value: unknown) => headers.set(name, value) };
  return {
    getHandler: () => handler,
    getClass: () => PublicRsvpController,
    switchToHttp: () => ({ getRequest: () => request, getResponse: () => response }),
  } as never;
}

async function appGuard() {
  const options = {
    throttlers: [{ ttl: 60_000, limit: 1_000 }, rsvpAddressThrottler],
  };
  const storage = new ThrottlerStorageService();
  const guard = new ThrottlerGuard(options, storage, new Reflector());
  await guard.onModuleInit();
  return { guard, storage };
}

const token = (n: number) => n.toString(16).padStart(43, "0");

test("one address trying many distinct well-formed links is refused past the address ceiling", async () => {
  const { guard, storage } = await appGuard();
  try {
    for (let n = 0; n < RSVP_ADDRESS_LIMIT; n += 1) {
      assert.equal(await guard.canActivate(contextFor(guestRoute("getInvitation"), "10.0.0.9", token(n))), true);
    }
    await assert.rejects(
      guard.canActivate(contextFor(guestRoute("getInvitation"), "10.0.0.9", token(RSVP_ADDRESS_LIMIT))),
      ThrottlerException,
    );
    // The ceiling is the address's, over the guest routes together.
    await assert.rejects(
      guard.canActivate(contextFor(guestRoute("preview"), "10.0.0.9", token(9_999))),
      ThrottlerException,
    );
    // Another address is not cut off.
    assert.equal(await guard.canActivate(contextFor(guestRoute("getInvitation"), "10.0.0.10", token(0))), true);
  } finally {
    storage.onApplicationShutdown();
  }
});

test("the per-link window still refuses one link's eleventh reply on a route", async () => {
  const { guard, storage } = await appGuard();
  try {
    for (let n = 0; n < 10; n += 1) {
      assert.equal(await guard.canActivate(contextFor(guestRoute("respond"), "10.0.0.1", token(1))), true);
    }
    await assert.rejects(
      guard.canActivate(contextFor(guestRoute("respond"), "10.0.0.1", token(1))),
      ThrottlerException,
    );
  } finally {
    storage.onApplicationShutdown();
  }
});

test("a route that is not a guest route is not counted by the address ceiling", async () => {
  const { guard, storage } = await appGuard();
  try {
    const other = function otherRoute() {} as (...args: never[]) => unknown;
    for (let n = 0; n < RSVP_ADDRESS_LIMIT + 5; n += 1) {
      assert.equal(await guard.canActivate(contextFor(other, "10.0.0.7", token(n))), true);
    }
  } finally {
    storage.onApplicationShutdown();
  }
});
