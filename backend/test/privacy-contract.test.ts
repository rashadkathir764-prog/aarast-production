import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { UserRole } from "@prisma/client";
import {
  toModeratedReviewIdentity,
  toReviewIdentity,
} from "../src/shared-kernel/privacy/review-identity";
import { safeTelemetryException } from "../src/platform/http/global-exception.filter";
import { usersService } from "./support/owner-ports";

test("review identity uses an allowlist that excludes contact details", () => {
  const rawReviewer = {
    id: "user-1",
    name: "Reviewer",
    appName: null,
    role: UserRole.USER,
    phone: "+967777123456",
    email: "private@example.com",
    reviewFirstNameOnly: false,
  };
  const response = toReviewIdentity(rawReviewer);

  assert.deepEqual(response, { id: "user-1", name: "Reviewer" });
  assert.equal("phone" in response, false);
  assert.equal("email" in response, false);
});

test("public review identity uses an administrator application name", () => {
  const response = toReviewIdentity({
    id: "admin-1",
    name: "Private Admin Identity",
    appName: "Wedding User",
    role: UserRole.ADMIN,
    reviewFirstNameOnly: false,
  });

  assert.deepEqual(response, { id: "admin-1", name: "Wedding User" });
});

test("D63 (w40): a reviewer who keeps the first name only is read by it; moderation reads the whole name", () => {
  const reviewer = {
    id: "user-2",
    name: "سلمان أحمد المنصور",
    appName: null,
    role: UserRole.USER,
    reviewFirstNameOnly: true,
  };
  assert.deepEqual(toReviewIdentity(reviewer), { id: "user-2", name: "سلمان" });
  assert.deepEqual(toModeratedReviewIdentity(reviewer), {
    id: "user-2",
    name: "سلمان أحمد المنصور",
  });
});

// The admin notification privacy mapper (redacted money notices, masked
// phones) served only the desk's notification routes; it was deleted with
// them (D56, B4), so no administrator reads anyone's notices at all
// (admin-mutation-authorization and admin-presenter prove the routes and
// the mapper are gone).

test("Sentry receives a synthetic error without the original sensitive message", () => {
  const original = new Error(
    "failed URL /api/v1/invites/raw-invite-secret?phone=+967777123456",
  );
  const telemetry = safeTelemetryException(500, original);

  assert.equal(telemetry.message, "HTTP 500 Error");
  assert.equal(telemetry.stack?.includes("raw-invite-secret"), false);
  assert.equal(telemetry.stack?.includes("967777123456"), false);
});

// RA-BE-11: no account learns whether a phone number has an account, or
// its name. The old lookup's plan guard proved nothing (anyone can own a
// plan), and no client used it; the route and its service are gone.
test("no route looks an account up by its phone", () => {
  const controller = readFileSync(
    join(__dirname, "..", "src", "modules", "identity", "api", "users.controller.ts"),
    "utf8",
  );
  assert.doesNotMatch(controller, /@Get\(["']lookup["']\)/);
  const service = usersService({} as any, {} as any, {} as any) as unknown as Record<string, unknown>;
  assert.equal(typeof service.lookupByPhone, "undefined");
});
