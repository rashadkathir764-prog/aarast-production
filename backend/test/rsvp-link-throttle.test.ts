import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { PublicRsvpController } from "../src/guests/guest-rsvp.controller";
import { rsvpLinkTracker } from "../src/guests/rsvp-throttle";

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
