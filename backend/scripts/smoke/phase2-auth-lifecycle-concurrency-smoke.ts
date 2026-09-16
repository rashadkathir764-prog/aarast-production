import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { UnauthorizedException } from "@nestjs/common";
import {
  AuthSessionScope,
  OtpPurpose,
  PrismaClient,
  UserStatus,
} from "@prisma/client";
import * as bcryptjs from "bcryptjs";
import { AuthErrorCode } from "../../src/modules/identity/public/auth-error";
import { AuthService } from "../../src/modules/identity/internal/auth/auth.service";
import {
  createRefreshTokenValue,
  hashRefreshToken,
} from "../../src/modules/identity/internal/auth/refresh-token-policy";
import { InviteAccessService } from "../../src/modules/collaboration/internal/invite-access.service";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { ownerPorts } from "./support/owner-ports";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => {
    runId: string;
  };
};
const { createPermissionRevocationFixture, withFixture } =
  require("../../test/support/phase0-postgres-support.js") as {
    createPermissionRevocationFixture: (
      prisma: unknown,
      environment?: NodeJS.ProcessEnv,
    ) => Promise<any>;
    withFixture: (
      createFixture: (environment: NodeJS.ProcessEnv) => Promise<any>,
      callback: (fixture: any) => Promise<void>,
      environment?: NodeJS.ProcessEnv,
    ) => Promise<void>;
  };

assertManagedSmokeEnvironment(process.env);

const prisma = new PrismaClient();
const auth = new AuthService(
  prisma as any,
  { sign: () => "test-access-token" } as any,
  {
    reserveAttempt: async () => undefined,
    clear: async () => undefined,
  } as any,
  { consume: async () => undefined } as any,
  {
    disconnectUser: () => undefined,
    disconnectSession: () => undefined,
  } as any,
  new PermissionService(prisma as any, ownerPorts.plans),
);
const inviteAccess = new InviteAccessService(prisma as any, auth);

function deferred(): {
  promise: Promise<void>;
  resolve: () => void;
} {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

async function waitForBlocked(
  operation: Promise<unknown>,
  label: string,
): Promise<void> {
  const state = await Promise.race([
    operation.then(
      () => "settled",
      () => "settled",
    ),
    new Promise<"blocked">((resolve) =>
      setTimeout(() => resolve("blocked"), 75),
    ),
  ]);
  assert.equal(state, "blocked", `${label} must wait for its row lock`);
}

async function configurePassword(userId: string, password: string) {
  await prisma.user.update({
    where: { id: userId },
    data: {
      passwordHash: await bcryptjs.hash(password, 4),
      appPasswordConfiguredAt: new Date(),
      status: UserStatus.ACTIVE,
      phoneVerifiedAt: new Date(),
    },
  });
}

function fixturePassword(scope: string, label: string): string {
  const digest = createHash("sha256")
    .update(`${scope}:${label}`)
    .digest("hex")
    .slice(0, 24);
  return `Phase2!${digest}`;
}

async function assertResetWinsBeforeOldPasswordLogin(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const oldPassword = fixturePassword(fixture.scope, "reset-old");
      const newPassword = fixturePassword(fixture.scope, "reset-new");
      await configurePassword(fixture.member.id, oldPassword);
      const changed = deferred();
      const commitRequested = deferred();
      const reset = prisma.$transaction(
        async (tx) => {
          await tx.user.update({
            where: { id: fixture.member.id },
            data: {
              passwordHash: await bcryptjs.hash(newPassword, 4),
            },
          });
          await tx.refreshToken.updateMany({
            where: { userId: fixture.member.id, revokedAt: null },
            data: { revokedAt: new Date() },
          });
          changed.resolve();
          await commitRequested.promise;
        },
        { timeout: 20_000 },
      );
      await changed.promise;
      const login = auth.login({
        phone: fixture.member.phone,
        password: oldPassword,
      });

      try {
        await waitForBlocked(login, "old-password login during reset");
        commitRequested.resolve();
        await reset;
        const [result] = await Promise.allSettled([login]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          assert.equal(result.reason?.getStatus?.(), 401);
          assert.equal(
            result.reason?.getResponse?.().code,
            "INVALID_CREDENTIALS",
          );
        }
        assert.equal(
          await prisma.refreshToken.count({
            where: { userId: fixture.member.id, revokedAt: null },
          }),
          0,
        );
      } finally {
        commitRequested.resolve();
        await Promise.allSettled([reset, login]);
      }
    },
  );
}

async function assertDisableWinsBeforeLogin(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const password = fixturePassword(fixture.scope, "disable-race");
      await configurePassword(fixture.member.id, password);
      const disabled = deferred();
      const commitRequested = deferred();
      const disable = prisma.$transaction(
        async (tx) => {
          await tx.user.update({
            where: { id: fixture.member.id },
            data: { status: UserStatus.DISABLED },
          });
          disabled.resolve();
          await commitRequested.promise;
        },
        { timeout: 20_000 },
      );
      await disabled.promise;
      const login = auth.login({
        phone: fixture.member.phone,
        password,
      });

      try {
        await waitForBlocked(login, "login during account disable");
        commitRequested.resolve();
        await disable;
        const [result] = await Promise.allSettled([login]);
        assert.equal(result?.status, "rejected");
        assert.equal(
          await prisma.refreshToken.count({
            where: { userId: fixture.member.id },
          }),
          0,
        );
      } finally {
        commitRequested.resolve();
        await Promise.allSettled([disable, login]);
      }
    },
  );
}

async function assertDisableWinsBeforeRefresh(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const password = fixturePassword(fixture.scope, "refresh-race");
      await configurePassword(fixture.member.id, password);
      const login = await auth.login({
        phone: fixture.member.phone,
        password,
      });
      const baseline = await prisma.refreshToken.count({
        where: { userId: fixture.member.id },
      });
      const disabled = deferred();
      const commitRequested = deferred();
      const disable = prisma.$transaction(
        async (tx) => {
          await tx.user.update({
            where: { id: fixture.member.id },
            data: { status: UserStatus.DISABLED },
          });
          disabled.resolve();
          await commitRequested.promise;
        },
        { timeout: 20_000 },
      );
      await disabled.promise;
      const refresh = auth.refresh({ refreshToken: login.refreshToken });

      try {
        await waitForBlocked(refresh, "refresh during account disable");
        commitRequested.resolve();
        await disable;
        const [result] = await Promise.allSettled([refresh]);
        assert.equal(result?.status, "rejected");
        assert.equal(
          await prisma.refreshToken.count({
            where: { userId: fixture.member.id },
          }),
          baseline,
          "a rejected refresh must not create a replacement session",
        );
      } finally {
        commitRequested.resolve();
        await Promise.allSettled([disable, refresh]);
      }
    },
  );
}

async function assertRefreshFamiliesStayScoped(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const password = fixturePassword(fixture.scope, "refresh-family");
      await configurePassword(fixture.member.id, password);

      const firstLogin = await auth.login({
        phone: fixture.member.phone,
        password,
      });
      const replayWinner = await auth.refresh({
        refreshToken: firstLogin.refreshToken,
      });
      await assert.rejects(
        () => auth.refresh({ refreshToken: firstLogin.refreshToken }),
        UnauthorizedException,
      );
      const replayWinnerRow = await prisma.refreshToken.findUniqueOrThrow({
        where: { tokenHash: hashRefreshToken(replayWinner.refreshToken) },
      });
      assert.ok(
        replayWinnerRow.revokedAt,
        "an immediate old-token replay must revoke the winning descendant",
      );

      const logoutResult = await auth.logout(fixture.member.id, {
        refreshToken: firstLogin.refreshToken,
      });
      assert.deepEqual(logoutResult, { revoked: 0 });
      assert.ok(
        (
          await prisma.refreshToken.findUniqueOrThrow({
            where: { id: replayWinnerRow.id },
          })
        ).revokedAt,
        "logout with the old token must keep its revoked replacement closed",
      );

      const replayedLogin = await auth.login({
        phone: fixture.member.phone,
        password,
      });
      const replayedWinner = await auth.refresh({
        refreshToken: replayedLogin.refreshToken,
      });
      await prisma.refreshToken.update({
        where: { tokenHash: hashRefreshToken(replayedLogin.refreshToken) },
        data: { revokedAt: new Date(Date.now() - 10_000) },
      });
      const independentLogin = await auth.login({
        phone: fixture.member.phone,
        password,
      });

      await assert.rejects(
        () => auth.refresh({ refreshToken: replayedLogin.refreshToken }),
        UnauthorizedException,
      );
      assert.ok(
        (
          await prisma.refreshToken.findUniqueOrThrow({
            where: { tokenHash: hashRefreshToken(replayedWinner.refreshToken) },
          })
        ).revokedAt,
        "an old-token replay must revoke its descendant",
      );
      const independentRow = await prisma.refreshToken.findUniqueOrThrow({
        where: { tokenHash: hashRefreshToken(independentLogin.refreshToken) },
      });
      assert.equal(
        independentRow.revokedAt,
        null,
        "replay must not revoke an independent login family",
      );
      await assert.rejects(
        () => auth.refresh({ refreshToken: replayedLogin.refreshToken }),
        UnauthorizedException,
      );
      assert.equal(
        (
          await prisma.refreshToken.findUniqueOrThrow({
            where: { id: independentRow.id },
          })
        ).revokedAt,
        null,
        "repeated replay must remain scoped to the original family",
      );

      const adminCurrentToken = createRefreshTokenValue("admin");
      const adminCurrent = await prisma.refreshToken.create({
        data: {
          userId: fixture.member.id,
          tokenHash: hashRefreshToken(adminCurrentToken),
          scope: AuthSessionScope.ADMIN,
          expiresAt: new Date(Date.now() + 60_000),
        },
      });
      const adminOldToken = createRefreshTokenValue("admin");
      await prisma.refreshToken.create({
        data: {
          userId: fixture.member.id,
          tokenHash: hashRefreshToken(adminOldToken),
          scope: AuthSessionScope.ADMIN,
          expiresAt: new Date(Date.now() + 60_000),
          revokedAt: new Date(),
          replacedById: adminCurrent.id,
        },
      });
      assert.deepEqual(await auth.logoutAdminRefreshToken(adminOldToken), {
        revoked: 1,
      });
      assert.ok(
        (
          await prisma.refreshToken.findUniqueOrThrow({
            where: { id: adminCurrent.id },
          })
        ).revokedAt,
        "admin logout must follow the same replacement chain",
      );

      const overflowDepth = 4_097;
      const overflowIds = Array.from(
        { length: overflowDepth },
        (_, index) => `auth-overflow-${fixture.member.id}-${index}`,
      );
      const overflowOldToken = createRefreshTokenValue("application");
      const overflowExpiresAt = new Date(Date.now() + 60_000);
      const overflowRevokedAt = new Date();
      await prisma.refreshToken.createMany({
        data: overflowIds.map((id, index) => ({
          id,
          userId: fixture.member.id,
          tokenHash: hashRefreshToken(
            index === 0
              ? overflowOldToken
              : createRefreshTokenValue("application"),
          ),
          scope: AuthSessionScope.APPLICATION,
          expiresAt: overflowExpiresAt,
          revokedAt:
            index === overflowDepth - 1 ? null : overflowRevokedAt,
          replacedById:
            index === overflowDepth - 1 ? null : overflowIds[index + 1],
        })),
      });
      const overflowIndependent = await auth.login({
        phone: fixture.member.phone,
        password,
      });
      const adminRealmSentinel = await prisma.refreshToken.create({
        data: {
          userId: fixture.member.id,
          tokenHash: hashRefreshToken(createRefreshTokenValue("admin")),
          scope: AuthSessionScope.ADMIN,
          expiresAt: new Date(Date.now() + 60_000),
        },
      });
      await assert.rejects(
        () => auth.refresh({ refreshToken: overflowOldToken }),
        UnauthorizedException,
      );
      assert.ok(
        (
          await prisma.refreshToken.findUniqueOrThrow({
            where: { id: overflowIds[overflowDepth - 1] },
          })
        ).revokedAt,
        "production-depth family overflow must revoke the active descendant",
      );
      assert.ok(
        (
          await prisma.refreshToken.findUniqueOrThrow({
            where: {
              tokenHash: hashRefreshToken(
                overflowIndependent.refreshToken,
              ),
            },
          })
        ).revokedAt,
        "family overflow must fail closed for the application realm",
      );
      assert.equal(
        (
          await prisma.refreshToken.findUniqueOrThrow({
            where: { id: adminRealmSentinel.id },
          })
        ).revokedAt,
        null,
        "application overflow must not revoke the administrator realm",
      );
    },
  );
}

async function assertInviteOtpContextsStayIsolated(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      await configurePassword(
        fixture.member.id,
        fixturePassword(fixture.scope, "invite-otp-context"),
      );
      const phone = fixture.member.phone;
      const tokenA = "A".repeat(43);
      const tokenB = "B".repeat(43);
      const expiresAt = new Date(Date.now() + 60_000);
      const [inviteA, inviteB] = await Promise.all([
        prisma.planInvite.create({
          data: {
            weddingPlanId: fixture.plan.id,
            inviterUserId: fixture.owner.id,
            inviteeUserId: fixture.member.id,
            phone,
            normalizedPhone: phone,
            tokenHash: createHash("sha256").update(tokenA).digest("hex"),
            expiresAt,
          },
        }),
        prisma.planInvite.create({
          data: {
            weddingPlanId: fixture.plan.id,
            inviterUserId: fixture.owner.id,
            inviteeUserId: fixture.member.id,
            phone,
            normalizedPhone: phone,
            tokenHash: createHash("sha256").update(tokenB).digest("hex"),
            expiresAt,
          },
        }),
      ]);

      await auth.requestOtp({ phone, purpose: OtpPurpose.LOGIN });
      await Promise.all([
        auth.requestInviteOtp(phone, inviteA.id, inviteA.tokenHash),
        auth.requestInviteOtp(phone, inviteA.id, inviteA.tokenHash),
      ]);
      await auth.requestInviteOtp(phone, inviteB.id, inviteB.tokenHash);

      const active = await prisma.otpCode.findMany({
        where: { phone, consumedAt: null },
      });
      assert.equal(active.length, 3);
      const loginOtp = active.find(
        (otp) =>
          otp.purpose === OtpPurpose.LOGIN && otp.planInviteId === null,
      );
      const inviteAOtp = active.find(
        (otp) => otp.planInviteId === inviteA.id,
      );
      const inviteBOtp = active.find(
        (otp) => otp.planInviteId === inviteB.id,
      );
      assert.ok(loginOtp);
      assert.ok(inviteAOtp);
      assert.ok(inviteBOtp);

      await Promise.all([
        prisma.otpCode.update({
          where: { id: loginOtp.id },
          data: { codeHash: await bcryptjs.hash("333333", 4) },
        }),
        prisma.otpCode.update({
          where: { id: inviteAOtp.id },
          data: { codeHash: await bcryptjs.hash("111111", 4) },
        }),
        prisma.otpCode.update({
          where: { id: inviteBOtp.id },
          data: { codeHash: await bcryptjs.hash("222222", 4) },
        }),
      ]);

      await assert.rejects(
        () =>
          auth.verifyInviteOtp({
            token: tokenA,
            phone,
            code: "222222",
          }),
        (error: any) =>
          error?.getStatus?.() === 400 &&
          error?.getResponse?.().code === AuthErrorCode.OTP_INVALID_OR_EXPIRED,
      );
      assert.equal(
        (
          await prisma.otpCode.findUniqueOrThrow({
            where: { id: inviteBOtp.id },
          })
        ).consumedAt,
        null,
        "using invite B's code with invite A must not consume invite B",
      );

      const inviteResult = await auth.verifyInviteOtp({
        token: tokenB,
        phone,
        code: "222222",
      });
      assert.equal(inviteResult.purpose, OtpPurpose.INVITE_ACCESS);

      const loginResult = await auth.verifyOtp({
        phone,
        purpose: OtpPurpose.LOGIN,
        code: "333333",
      });
      assert.equal(loginResult.purpose, OtpPurpose.LOGIN);
    },
  );
}

function assertInviteContextConstraint(error: any): boolean {
  const details = `${error?.message ?? ""} ${JSON.stringify(error?.meta ?? {})}`;
  return (
    details.includes("23514") &&
    details.includes("OtpCode_invite_access_context_check")
  );
}

async function assertInviteOtpDatabaseContextConstraint(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const invite = await prisma.planInvite.create({
        data: {
          weddingPlanId: fixture.plan.id,
          inviterUserId: fixture.owner.id,
          inviteeUserId: fixture.member.id,
          phone: fixture.member.phone,
          normalizedPhone: fixture.member.phone,
          tokenHash: createHash("sha256").update("C".repeat(43)).digest("hex"),
          expiresAt: new Date(Date.now() + 60_000),
        },
      });
      const terminalOtp = {
        phone: fixture.member.phone,
        codeHash: "phase2-invite-context-check",
        expiresAt: new Date(Date.now() + 60_000),
        consumedAt: new Date(),
      };

      await assert.rejects(
        () =>
          prisma.otpCode.create({
            data: {
              ...terminalOtp,
              purpose: OtpPurpose.INVITE_ACCESS,
              planInviteId: null,
            },
          }),
        assertInviteContextConstraint,
      );
      await assert.rejects(
        () =>
          prisma.otpCode.create({
            data: {
              ...terminalOtp,
              purpose: OtpPurpose.LOGIN,
              planInviteId: invite.id,
            },
          }),
        assertInviteContextConstraint,
      );
    },
  );
}

async function assertReissueWinsBeforeOldTokenOtp(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const oldToken = "D".repeat(43);
      const newToken = "E".repeat(43);
      const invite = await prisma.planInvite.create({
        data: {
          weddingPlanId: fixture.plan.id,
          inviterUserId: fixture.owner.id,
          inviteeUserId: fixture.member.id,
          phone: fixture.member.phone,
          normalizedPhone: fixture.member.phone,
          tokenHash: createHash("sha256").update(oldToken).digest("hex"),
          expiresAt: new Date(Date.now() + 60_000),
        },
      });
      const changed = deferred();
      const commitRequested = deferred();
      const reissue = prisma.$transaction(
        async (tx) => {
          await tx.planInvite.update({
            where: { id: invite.id },
            data: {
              tokenHash: createHash("sha256").update(newToken).digest("hex"),
            },
          });
          changed.resolve();
          await commitRequested.promise;
        },
        { timeout: 20_000 },
      );
      await changed.promise;
      const staleRequest = inviteAccess.requestOtp(
        oldToken,
        { phone: fixture.member.phone },
        { ip: "127.0.0.1" },
      );

      try {
        await waitForBlocked(
          staleRequest,
          "old-token OTP request during invite reissue",
        );
        commitRequested.resolve();
        await reissue;
        const [result] = await Promise.allSettled([staleRequest]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          if (result.reason?.getStatus?.() !== 404) throw result.reason;
          assert.equal(result.reason?.getStatus?.(), 404);
          assert.equal(
            result.reason?.getResponse?.().code,
            AuthErrorCode.INVITE_NOT_FOUND_FOR_PHONE,
          );
        }
        assert.equal(
          await prisma.otpCode.count({
            where: { planInviteId: invite.id },
          }),
          0,
          "a bearer invalidated by reissue must not create an OTP",
        );
      } finally {
        commitRequested.resolve();
        await Promise.allSettled([reissue, staleRequest]);
      }
    },
  );
}

async function assertDeletionWinsBeforeInviteOtp(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const token = "F".repeat(43);
      const tokenHash = createHash("sha256").update(token).digest("hex");
      const invite = await prisma.planInvite.create({
        data: {
          weddingPlanId: fixture.plan.id,
          inviterUserId: fixture.owner.id,
          inviteeUserId: fixture.member.id,
          phone: fixture.member.phone,
          normalizedPhone: fixture.member.phone,
          tokenHash,
          expiresAt: new Date(Date.now() + 60_000),
        },
      });
      await auth.requestInviteOtp(fixture.member.phone, invite.id, tokenHash);

      const deleted = deferred();
      const commitRequested = deferred();
      const deletion = prisma.$transaction(
        async (tx) => {
          await tx.planInvite.delete({ where: { id: invite.id } });
          deleted.resolve();
          await commitRequested.promise;
        },
        { timeout: 20_000 },
      );
      await deleted.promise;
      const requestDuringDeletion = inviteAccess.requestOtp(
        token,
        { phone: fixture.member.phone },
        { ip: "127.0.0.1" },
      );

      try {
        await waitForBlocked(
          requestDuringDeletion,
          "invite OTP request during invite deletion",
        );
        commitRequested.resolve();
        await deletion;
        const [result] = await Promise.allSettled([requestDuringDeletion]);
        assert.equal(result?.status, "rejected");
        if (result?.status === "rejected") {
          if (result.reason?.getStatus?.() !== 404) throw result.reason;
          assert.equal(result.reason?.getStatus?.(), 404);
          assert.equal(
            result.reason?.getResponse?.().code,
            AuthErrorCode.INVITE_NOT_FOUND_FOR_PHONE,
          );
        }
        assert.equal(
          await prisma.otpCode.count({
            where: { planInviteId: invite.id },
          }),
          0,
          "invite deletion must cascade every bound OTP",
        );
      } finally {
        commitRequested.resolve();
        await Promise.allSettled([deletion, requestDuringDeletion]);
      }
    },
  );
}

async function main(): Promise<void> {
  try {
    await assertResetWinsBeforeOldPasswordLogin();
    await assertDisableWinsBeforeLogin();
    await assertDisableWinsBeforeRefresh();
    await assertRefreshFamiliesStayScoped();
    await assertInviteOtpContextsStayIsolated();
    await assertInviteOtpDatabaseContextConstraint();
    await assertReissueWinsBeforeOldTokenOtp();
    await assertDeletionWinsBeforeInviteOtp();
    console.log(
      "PASS - Authentication lifecycle serializes account changes, scopes refresh-token families, and enforces isolated invite OTP contexts across concurrent issue, reissue, and deletion.",
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
