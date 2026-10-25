import assert from "node:assert/strict";
import { test } from "node:test";
import { UserRole } from "@prisma/client";
import { toReviewIdentity } from "../src/shared-kernel/privacy/review-identity";
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
  });

  assert.deepEqual(response, { id: "admin-1", name: "Wedding User" });
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

test("user lookup checks invite authority before querying an account", async () => {
  let userQueries = 0;
  const service = usersService(
    {
      user: {
        findFirst: async () => {
          userQueries += 1;
          return null;
        },
      },
    } as any,
    {
      assertMemberManageable: async () => {
        throw new Error("forbidden");
      },
    } as any,
    {} as any,
  );

  await assert.rejects(() =>
    service.lookupByPhone({ id: "viewer-1" } as any, "plan-1", "+967777123456"),
  );
  assert.equal(userQueries, 0);
});
