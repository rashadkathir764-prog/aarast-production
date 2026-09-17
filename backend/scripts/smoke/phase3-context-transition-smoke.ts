import type { ConversationLifecyclePort } from "../../src/modules/messaging/public/conversation-lifecycle.port";
import { findConversationProviderId, lockConversationForShare, lockConversationForUpdate } from "../../src/conversations/conversation-lifecycle";

const lifecycle: ConversationLifecyclePort = {
  ensureConversationContext: async () => { throw new Error("Unexpected ensureConversationContext"); },
  recordConversationEvent: async () => { throw new Error("Unexpected recordConversationEvent"); },
  lockConversationForUpdateInTransaction: lockConversationForUpdate,
  lockConversationForShareInTransaction: lockConversationForShare,
  findConversationProviderId,
};
import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  AdminRole,
  AppRole,
  AuthSessionScope,
  OnboardingPath,
  PrismaClient,
  ProviderStatus,
  SharedMemberRole,
  UserRole,
  UserStatus,
  WeddingPersona,
  WeddingPlanStatus,
} from "@prisma/client";
import { JwtService } from "@nestjs/jwt";
import { AdminService } from "../../src/admin/admin.service";
import { ContextsService } from "../../src/modules/identity/internal/profile/contexts.service";
import { ProviderDashboardService } from "../../src/provider-dashboard/provider-dashboard.service";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { ownerPorts, providerDashboardService } from "./support/owner-ports";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const permissions = new PermissionService(prisma as any, ownerPorts.plans);
const contexts = new ContextsService(
  prisma as any,
  permissions,
  ownerPorts.plans,
  ownerPorts.providers,
);
const notifications = {
  createNotificationInTransaction: async () => ({ id: "phase3-notification" }),
};
const providerDashboard = providerDashboardService(
  prisma,
  notifications,
  {},
  lifecycle,
);
const admin = new AdminService(prisma as any, {
  disconnectUser: () => undefined,
  revokeConversationAccess: () => undefined,
} as any, {
  createNotificationInTransaction: async () => null,
} as any);

function phone(label: string): string {
  const digits = createHash("sha256")
    .update(`${runId}:${label}`)
    .digest("hex")
    .split("")
    .map((character) => String(Number.parseInt(character, 16) % 10))
    .join("");
  return `+9677${digits.slice(0, 7)}`;
}

function authenticated(user: Record<string, unknown>) {
  return {
    ...user,
    adminMfa: user.role === UserRole.ADMIN,
    sessionScope:
      user.role === UserRole.ADMIN ? "admin" : "application",
  } as any;
}

async function requestJson(
  method: "GET" | "POST",
  path: string,
  token: string,
  body?: Record<string, unknown>,
): Promise<{ status: number; body: any }> {
  const response = await fetch(`${process.env.SMOKE_BASE_URL}${path}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      ...(body ? { "content-type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return {
    status: response.status,
    body: await response.json(),
  };
}

async function assertWeddingContextsPreserved(
  userId: string,
  expectedProviderStatus: ProviderStatus,
  expectedAccessMode: "FULL" | "LIMITED" | "READ_ONLY",
  expectedProfileWrite: boolean,
  expectedOperations: boolean,
): Promise<void> {
  const available = await contexts.list({ id: userId } as any);
  const contextKeys = new Set(available.map((context) => context.contextKey));
  assert.ok(contextKeys.has("plan:phase3-owned:owner"));
  assert.ok(contextKeys.has("plan:phase3-contributed:contributor"));
  assert.ok(contextKeys.has("plan:phase3-archived:contributor"));

  const providerContext = available.find(
    (context) => context.role === "PROVIDER",
  );
  assert.ok(providerContext);
  assert.equal(providerContext.lifecycle, expectedProviderStatus);
  assert.equal(providerContext.accessMode, expectedAccessMode);
  assert.deepEqual(providerContext.capabilities, {
    canViewProviderProfile: true,
    canManageProviderProfile: expectedProfileWrite,
    canUseProviderOperations: expectedOperations,
  });

  const persisted = await prisma.user.findUniqueOrThrow({
    where: { id: userId },
    select: {
      role: true,
      appRole: true,
      onboardingPath: true,
      persona: true,
      onboardingCompletedAt: true,
      activeWeddingPlanId: true,
    },
  });
  assert.equal(persisted.role, UserRole.PROVIDER);
  assert.equal(persisted.appRole, AppRole.PROVIDER);
  assert.equal(persisted.onboardingPath, OnboardingPath.USER);
  assert.equal(persisted.persona, WeddingPersona.BRIDE);
  assert.ok(persisted.onboardingCompletedAt);
  assert.equal(persisted.activeWeddingPlanId, "phase3-owned");
}

async function main(): Promise<void> {
  const [account, contributorOwner, inviteOwner, adminUser, city] =
    await prisma.$transaction(async (tx) => {
      const accountRow = await tx.user.create({
        data: {
          name: `Phase 3 account ${runId}`,
          phone: phone("account"),
          passwordHash: "managed-smoke-not-a-credential",
          appPasswordConfiguredAt: new Date(),
          phoneVerifiedAt: new Date(),
          role: UserRole.USER,
          appRole: AppRole.WEDDING_USER,
          onboardingPath: OnboardingPath.USER,
          persona: WeddingPersona.BRIDE,
          onboardingCompletedAt: new Date("2026-07-26T00:00:00.000Z"),
          status: UserStatus.ACTIVE,
        },
      });
      const contributorOwnerRow = await tx.user.create({
        data: {
          name: `Phase 3 contributor owner ${runId}`,
          phone: phone("contributor-owner"),
          passwordHash: "managed-smoke-not-a-credential",
          phoneVerifiedAt: new Date(),
          status: UserStatus.ACTIVE,
        },
      });
      const inviteOwnerRow = await tx.user.create({
        data: {
          name: `Phase 3 invite owner ${runId}`,
          phone: phone("invite-owner"),
          passwordHash: "managed-smoke-not-a-credential",
          phoneVerifiedAt: new Date(),
          status: UserStatus.ACTIVE,
        },
      });
      const adminRow = await tx.user.create({
        data: {
          name: `Phase 3 admin ${runId}`,
          phone: phone("admin"),
          passwordHash: "managed-smoke-not-a-credential",
          phoneVerifiedAt: new Date(),
          role: UserRole.ADMIN,
          adminRole: AdminRole.OPERATIONS,
          status: UserStatus.ACTIVE,
        },
      });
      const cityRow = await tx.city.create({
        data: {
          nameAr: `Phase 3 city ${runId}`,
          countryCode: "YE",
        },
      });
      await tx.weddingPlan.create({
        data: {
          id: "phase3-owned",
          ownerUserId: accountRow.id,
          title: "Phase 3 owned",
        },
      });
      await tx.weddingPlan.create({
        data: {
          id: "phase3-contributed",
          ownerUserId: contributorOwnerRow.id,
          title: "Phase 3 contributed",
        },
      });
      await tx.weddingPlan.create({
        data: {
          id: "phase3-invited",
          ownerUserId: inviteOwnerRow.id,
          title: "Phase 3 invited",
        },
      });
      await tx.weddingPlan.create({
        data: {
          id: "phase3-archived",
          ownerUserId: contributorOwnerRow.id,
          title: "Phase 3 archived",
          status: WeddingPlanStatus.ARCHIVED,
        },
      });
      await tx.sharedMember.create({
        data: {
          weddingPlanId: "phase3-contributed",
          userId: accountRow.id,
          role: SharedMemberRole.CONTRIBUTOR,
          canManageTasks: true,
        },
      });
      await tx.sharedMember.create({
        data: {
          weddingPlanId: "phase3-archived",
          userId: accountRow.id,
          role: SharedMemberRole.MANAGER,
          canViewMoney: true,
          canEditPlan: true,
          canManageTasks: true,
          canManageMoney: true,
        },
      });
      await tx.user.update({
        where: { id: accountRow.id },
        data: { activeWeddingPlanId: "phase3-owned" },
      });
      return [
        accountRow,
        contributorOwnerRow,
        inviteOwnerRow,
        adminRow,
        cityRow,
      ] as const;
    });

  assert.deepEqual(
    new Set(
      (await contexts.list(authenticated(account))).map(
        (context) => context.contextKey,
      ),
    ),
    new Set([
      "plan:phase3-owned:owner",
      "plan:phase3-contributed:contributor",
      "plan:phase3-archived:contributor",
    ]),
  );

  const application = await providerDashboard.apply(authenticated(account), {
    businessName: `Phase 3 provider ${runId}`,
    phone: phone("provider"),
    cityId: city.id,
  });
  await assertWeddingContextsPreserved(
    account.id,
    ProviderStatus.PENDING,
    "LIMITED",
    true,
    false,
  );

  await admin.requestProviderChanges(
    authenticated(adminUser),
    application.id,
    { note: "Phase 3 managed smoke" },
  );
  await assertWeddingContextsPreserved(
    account.id,
    ProviderStatus.NEEDS_CHANGES,
    "LIMITED",
    true,
    false,
  );

  await admin.rejectProvider(authenticated(adminUser), application.id, {
    reason: "Phase 3 managed smoke",
  });
  await assertWeddingContextsPreserved(
    account.id,
    ProviderStatus.REJECTED,
    "READ_ONLY",
    false,
    false,
  );

  await admin.approveProvider(authenticated(adminUser), application.id);
  await assertWeddingContextsPreserved(
    account.id,
    ProviderStatus.ACTIVE,
    "FULL",
    true,
    true,
  );

  await admin.suspendProvider(authenticated(adminUser), application.id, {
    reason: "Phase 3 managed smoke",
  });
  await assertWeddingContextsPreserved(
    account.id,
    ProviderStatus.SUSPENDED,
    "READ_ONLY",
    false,
    false,
  );

  await admin.activateProvider(authenticated(adminUser), application.id);
  await assertWeddingContextsPreserved(
    account.id,
    ProviderStatus.ACTIVE,
    "FULL",
    true,
    true,
  );

  const legacy = await prisma.user.findUniqueOrThrow({
    where: { id: account.id },
    select: {
      role: true,
      appRole: true,
      onboardingPath: true,
      persona: true,
      onboardingCompletedAt: true,
      activeWeddingPlanId: true,
    },
  });
  assert.deepEqual(legacy, {
    role: UserRole.PROVIDER,
    appRole: AppRole.PROVIDER,
    onboardingPath: OnboardingPath.USER,
    persona: WeddingPersona.BRIDE,
    onboardingCompletedAt: new Date("2026-07-26T00:00:00.000Z"),
    activeWeddingPlanId: "phase3-owned",
  });

  const refresh = await prisma.refreshToken.create({
    data: {
      userId: account.id,
      tokenHash: createHash("sha256")
        .update(`${runId}:refresh`)
        .digest("hex"),
      scope: AuthSessionScope.APPLICATION,
      expiresAt: new Date(Date.now() + 60_000),
    },
  });
  const jwt = new JwtService({ secret: process.env.JWT_SECRET }).sign({
    sub: account.id,
    scope: "application",
    sid: refresh.id,
  });

  const listed = await requestJson("GET", "/api/v1/contexts", jwt);
  assert.equal(listed.status, 200);
  const archivedContext = listed.body.find(
    (context: any) =>
      context.contextKey === "plan:phase3-archived:contributor",
  );
  assert.deepEqual(
    {
      lifecycle: archivedContext?.lifecycle,
      accessMode: archivedContext?.accessMode,
      isAvailable: archivedContext?.isAvailable,
      unavailableReason: archivedContext?.unavailableReason,
      canEditPlan: archivedContext?.permissions?.canEditPlan,
      canManageTasks: archivedContext?.permissions?.canManageTasks,
      canManageGuests: archivedContext?.permissions?.canManageGuests,
      canManageProviders: archivedContext?.permissions?.canManageProviders,
      canInviteMembers: archivedContext?.permissions?.canInviteMembers,
      canManageMoney: archivedContext?.permissions?.canManageMoney,
    },
    {
      lifecycle: WeddingPlanStatus.ARCHIVED,
      accessMode: "READ_ONLY",
      isAvailable: false,
      unavailableReason: "PLAN_ARCHIVED",
      canEditPlan: false,
      canManageTasks: false,
      canManageGuests: false,
      canManageProviders: false,
      canInviteMembers: false,
      canManageMoney: false,
    },
  );

  const providerContextKey = `provider:${application.id}`;
  const validatedProvider = await requestJson(
    "POST",
    "/api/v1/contexts/validate",
    jwt,
    { contextKey: providerContextKey },
  );
  assert.equal(validatedProvider.status, 201);
  assert.deepEqual(
    {
      contextKey: validatedProvider.body.contextKey,
      lifecycle: validatedProvider.body.lifecycle,
      accessMode: validatedProvider.body.accessMode,
      capabilities: validatedProvider.body.capabilities,
    },
    {
      contextKey: providerContextKey,
      lifecycle: ProviderStatus.ACTIVE,
      accessMode: "FULL",
      capabilities: {
        canViewProviderProfile: true,
        canManageProviderProfile: true,
        canUseProviderOperations: true,
      },
    },
  );

  const archivedValidation = await requestJson(
    "POST",
    "/api/v1/contexts/validate",
    jwt,
    { contextKey: "plan:phase3-archived:contributor" },
  );
  assert.equal(archivedValidation.status, 409);
  assert.equal(archivedValidation.body.code, "CONTEXT_UNAVAILABLE");
  assert.equal(archivedValidation.body.unavailableReason, "PLAN_ARCHIVED");

  const invite = await prisma.planInvite.create({
    data: {
      weddingPlanId: "phase3-invited",
      inviterUserId: inviteOwner.id,
      inviteeUserId: account.id,
      phone: account.phone,
      normalizedPhone: account.phone,
      tokenHash: createHash("sha256")
        .update(`${runId}:invite`)
        .digest("hex"),
      role: SharedMemberRole.CONTRIBUTOR,
      expiresAt: new Date(Date.now() + 60_000),
    },
  });
  const accepted = await requestJson(
    "POST",
    `/api/v1/invites/${invite.id}/accept`,
    jwt,
  );
  assert.equal(accepted.status, 201);
  assert.equal(
    accepted.body.contextKey,
    "plan:phase3-invited:contributor",
  );
  assert.equal(accepted.body.member.weddingPlanId, "phase3-invited");
  assert.equal(
    (
      await prisma.user.findUniqueOrThrow({
        where: { id: account.id },
        select: { activeWeddingPlanId: true },
      })
    ).activeWeddingPlanId,
    "phase3-owned",
  );

  const finalContexts = await contexts.list(authenticated(account));
  assert.deepEqual(
    new Set(finalContexts.map((context) => context.contextKey)),
    new Set([
      "plan:phase3-owned:owner",
      "plan:phase3-contributed:contributor",
      "plan:phase3-archived:contributor",
      "plan:phase3-invited:contributor",
      `provider:${application.id}`,
    ]),
  );

  console.log(
    "PASS - Phase 3 provider application, every provider lifecycle decision, and invite acceptance preserve simultaneous wedding contexts and the selected active plan.",
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
