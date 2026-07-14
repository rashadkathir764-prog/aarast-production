import assert from "node:assert/strict";
import { test } from "node:test";
import { NotificationType } from "@prisma/client";
import {
  maskPhone,
  toAdminNotificationPrivacyView,
} from "../src/admin/admin-privacy";
import { toReviewIdentity } from "../src/common/privacy/review-identity";
import { safeTelemetryException } from "../src/common/filters/global-exception.filter";
import { UsersService } from "../src/users/users.service";

test("review identity uses an allowlist that excludes contact details", () => {
  const response = toReviewIdentity({
    id: "user-1",
    name: "Reviewer",
    phone: "+967777123456",
    email: "private@example.com",
  } as { id: string; name: string; phone: string; email: string });

  assert.deepEqual(response, { id: "user-1", name: "Reviewer" });
  assert.equal("phone" in response, false);
  assert.equal("email" in response, false);
});

test("known financial admin notifications disclose no amount or creditor", () => {
  const response = toAdminNotificationPrivacyView({
    type: NotificationType.PAYMENT_SCHEDULE_DUE_SOON,
    title: "قسط بقيمة 50000 ر.ي",
    body: "تبقى 25000 ر.ي للدائن أحمد",
    entityType: "payment_schedule",
    entityId: "schedule-secret-id",
    routeTarget: "/wedding-plans/plan-1/money/costs/cost-1/schedules",
    data: { amount: 50000, remaining: 25000, creditor: "أحمد" },
  });

  assert.equal(response.financialDetailsRedacted, true);
  assert.equal(response.title, "إشعار مالي");
  assert.equal(response.data, null);
  assert.equal(response.entityId, null);
  assert.equal(response.routeTarget, null);
  assert.equal(JSON.stringify(response).includes("50000"), false);
  assert.equal(JSON.stringify(response).includes("أحمد"), false);
});

test("financial data keys redact even a misclassified GENERAL notification", () => {
  const response = toAdminNotificationPrivacyView({
    type: NotificationType.GENERAL,
    title: "تنبيه",
    body: "محتوى خاص",
    entityType: null,
    entityId: null,
    routeTarget: null,
    data: { nested: { totalAmount: 1000 } },
  });

  assert.equal(response.financialDetailsRedacted, true);
  assert.equal(response.data, null);
});

test("non-financial operational notification remains useful to admins", () => {
  const response = toAdminNotificationPrivacyView({
    type: NotificationType.SHARING_UPDATED,
    title: "تحديث مشاركة",
    body: "تم تحديث صلاحية عضو",
    entityType: "shared_member",
    entityId: "member-1",
    routeTarget: "/sharing/member-1",
    data: { role: "VIEWER" },
  });

  assert.equal(response.financialDetailsRedacted, false);
  assert.equal(response.body, "تم تحديث صلاحية عضو");
});

test("admin notification phone references are masked", () => {
  assert.equal(maskPhone("+967 777 123 456"), "••••3456");
  assert.equal(maskPhone(null), null);
});

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
  const service = new UsersService(
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
