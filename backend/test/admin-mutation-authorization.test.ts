import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

const adminDirectory = join(__dirname, "..", "src", "admin");

function source(file: string): string {
  return readFileSync(join(adminDirectory, file), "utf8");
}

function methodBlock(
  contents: string,
  method: string,
): string {
  const start = contents.indexOf(`  async ${method}(`);
  assert.notEqual(start, -1, `${method} must exist`);
  const nextAsync = contents.indexOf("\n  async ", start + 1);
  const nextPrivate = contents.indexOf("\n  private ", start + 1);
  const candidates = [nextAsync, nextPrivate].filter((index) => index >= 0);
  const end = candidates.length ? Math.min(...candidates) : contents.length;
  return contents.slice(start, end);
}

const mutations = [
  ["createService", "SERVICES_WRITE"],
  ["updateService", "SERVICES_WRITE"],
  ["deleteService", "SERVICES_WRITE"],
  ["updateReviewStatus", "REVIEWS_WRITE"],
  ["hideReview", "REVIEWS_WRITE"],
  ["updateConversationReportStatus", "CONVERSATION_REPORTS_WRITE"],
  ["markNotificationRead", "NOTIFICATIONS_WRITE"],
  ["archiveNotification", "NOTIFICATIONS_WRITE"],
  ["deleteNotification", "NOTIFICATIONS_WRITE"],
  ["createCategory", "CATALOG_WRITE"],
  ["updateCategory", "CATALOG_WRITE"],
  ["deleteCategory", "CATALOG_WRITE"],
  ["createCity", "CATALOG_WRITE"],
  ["updateCity", "CATALOG_WRITE"],
  ["deleteCity", "CATALOG_WRITE"],
] as const;

test("admin mutation controllers pass the authenticated actor to the service", () => {
  const controller = source("admin.controller.ts");
  for (const [method] of mutations) {
    const methodStart = controller.indexOf(`  ${method}(`);
    assert.notEqual(methodStart, -1, `${method} controller must exist`);
    const methodEnd = controller.indexOf("\n  }\n", methodStart);
    const block = controller.slice(methodStart, methodEnd);
    assert.match(block, /@CurrentUser\(\) currentUser: AuthenticatedUser/, method);
    assert.match(
      block,
      new RegExp(
        `adminService\\.${method}\\(\\s*currentUser(?:\\s*,|\\s*\\))`,
      ),
      method,
    );
  }
});

test("every affected admin mutation runs behind the live serializable gate", () => {
  const service = source("admin-mutation-executor.ts");
  for (const [method, permission] of mutations) {
    const block = methodBlock(service, method);
    assert.match(
      block,
      /currentUser: AuthenticatedUser/,
      `${method} must receive the actor`,
    );
    assert.match(
      block,
      /runAuthorizedAdminMutation\(/,
      `${method} must use the gate`,
    );
    assert.match(
      block,
      new RegExp(`AdminPermission\\.${permission}`),
      `${method} must recheck ${permission}`,
    );
  }
});

test("the gate locks and reauthorizes the actor before target helpers run", () => {
  const gate = source("../modules/backoffice/public/admin-mutation-gate.ts");
  assert.match(gate, /runSerializableTransaction/);
  assert.match(gate, /FROM "User"[\s\S]*FOR UPDATE/);
  assert.match(gate, /actor\.role !== UserRole\.ADMIN/);
  assert.match(gate, /actor\.status !== UserStatus\.ACTIVE/);
  assert.match(gate, /hasAdminPermission\(actor\.adminRole, permission\)/);

  const userStatus = source("admin-user-status.ts");
  const actorGate = userStatus.indexOf("authorizeAdminMutationActor");
  const targetLock = userStatus.indexOf('WHERE "id" = ${targetId}');
  assert.ok(actorGate >= 0 && targetLock > actorGate);
  assert.match(userStatus, /AdminPermission\.USERS_WRITE/);
  assert.match(userStatus, /FOR UPDATE/);
});
