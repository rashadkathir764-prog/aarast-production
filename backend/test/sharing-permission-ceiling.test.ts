import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { HttpException } from "@nestjs/common";
import {
  PlanInviteDeliveryStatus,
  Prisma,
  SharedMemberRole,
} from "@prisma/client";
import { AuthenticatedUser } from "../src/auth/authenticated-user.interface";
import { NotificationsService } from "../src/notifications/notifications.service";
import {
  PermissionService,
  PlanAccessContext,
} from "../src/sharing/permission.service";
import { rolePermissionDefaults } from "../src/sharing/plan-permissions";
import { SharingService } from "../src/sharing/sharing.service";

const permissions = new PermissionService({} as any);
const sharing = new SharingService(
  {} as any,
  permissions,
  {} as any,
  {} as any,
);

function memberContext(
  role: SharedMemberRole,
  overrides: Record<string, boolean> = {},
): PlanAccessContext {
  return {
    plan: { id: "plan-1", ownerUserId: "owner-1" } as any,
    isOwner: false,
    sharedMember: {
      role,
      ...rolePermissionDefaults(role),
      ...overrides,
    } as any,
  };
}

function assertCeiling(
  inviter: PlanAccessContext,
  targetRole: SharedMemberRole,
  targetOverrides: Record<string, boolean> = {},
) {
  (sharing as any).assertPermissionCeiling(inviter, targetRole, {
    ...rolePermissionDefaults(targetRole),
    ...targetOverrides,
  });
}

test("owner may delegate every non-owner role", () => {
  assert.doesNotThrow(() =>
    assertCeiling(
      {
        plan: { id: "plan-1", ownerUserId: "owner-1" } as any,
        isOwner: true,
        sharedMember: null,
      },
      SharedMemberRole.FINANCE_MANAGER,
    ),
  );
});

test("manager and helper cannot mint finance authority they do not own", () => {
  for (const role of [SharedMemberRole.MANAGER, SharedMemberRole.HELPER]) {
    assert.throws(
      () =>
        assertCeiling(
          memberContext(role, { canInviteMembers: true }),
          SharedMemberRole.FINANCE_MANAGER,
        ),
      /canViewMoney|canManageMoney/,
    );
  }
});

test("manager may delegate an editor role inside the manager ceiling", () => {
  assert.doesNotThrow(() =>
    assertCeiling(
      memberContext(SharedMemberRole.MANAGER, { canInviteMembers: true }),
      SharedMemberRole.EDITOR,
    ),
  );
});

test("explicit finance plus invite delegation may be passed on but not enlarged", () => {
  assert.doesNotThrow(() =>
    assertCeiling(
      memberContext(SharedMemberRole.FINANCE_MANAGER, {
        canInviteMembers: true,
      }),
      SharedMemberRole.FINANCE_MANAGER,
    ),
  );

  assert.throws(
    () =>
      assertCeiling(
        memberContext(SharedMemberRole.FINANCE_MANAGER, {
          canInviteMembers: true,
        }),
        SharedMemberRole.MANAGER,
      ),
    /canEditPlan|canManageTasks/,
  );
});

test("viewer with invite delegation can only create another viewer", () => {
  const inviter = memberContext(SharedMemberRole.VIEWER, {
    canInviteMembers: true,
  });
  assert.doesNotThrow(() => assertCeiling(inviter, SharedMemberRole.VIEWER));
  assert.throws(
    () => assertCeiling(inviter, SharedMemberRole.HELPER),
    /canManageTasks|canManageGuests|canManageProviders/,
  );
});

type StoredInvite = Record<string, any>;

class MemorySharingPrisma {
  readonly plan = {
    id: "plan-1",
    ownerUserId: "owner-1",
    title: "خطة الاختبار",
    city: "صنعاء",
    weddingDate: new Date("2026-12-01T00:00:00.000Z"),
    estimatedBudget: null,
    currency: "YER",
    status: "PLANNING",
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
  };
  readonly users: Array<Record<string, any>>;
  invites: StoredInvite[] = [];
  transactionOptions: Array<Record<string, unknown>> = [];
  serializationFailuresRemaining = 0;
  finalDeliveryPersistenceFailuresRemaining = 0;
  finalDeliveryPersistenceError: unknown = null;
  private inviteSequence = 0;
  private transactionTail = Promise.resolve();

  constructor(users: Array<Record<string, any>>) {
    this.users = users;
  }

  user = {
    findUnique: async ({ where }: any) => {
      if (typeof where.id === "string") {
        return this.users.find((user) => user.id === where.id) ?? null;
      }
      if (typeof where.phone === "string") {
        return this.users.find((user) => user.phone === where.phone) ?? null;
      }
      return null;
    },
    findFirst: async ({ where }: any) => {
      if (where.phone?.in) {
        return (
          this.users.find((user) => where.phone.in.includes(user.phone)) ?? null
        );
      }
      if (where.email) {
        return this.users.find((user) => user.email === where.email) ?? null;
      }
      return null;
    },
  };

  sharedMember = {
    findUnique: async () => null,
    findMany: async () => [],
  };

  planInvite = {
    findMany: async ({ where }: any = {}) =>
      this.invites.filter((invite) => this.matchesListWhere(invite, where)),
    findUnique: async ({ where }: any) => this.findUniqueInvite(where),
    findFirst: async ({ where }: any) => this.findFirstInvite(where),
    updateMany: async ({ where, data }: any) =>
      this.updatePlanInvites(where, data),
  };

  $transaction = async (
    operation: (tx: Record<string, any>) => Promise<any>,
    options: Record<string, unknown> = {},
  ) => {
    const previous = this.transactionTail;
    let release!: () => void;
    this.transactionTail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;

    this.transactionOptions.push(options);
    const snapshot = structuredClone(this.invites);
    try {
      if (this.serializationFailuresRemaining > 0) {
        this.serializationFailuresRemaining -= 1;
        throw new Prisma.PrismaClientKnownRequestError(
          "serialization conflict",
          {
            code: "P2034",
            clientVersion: "test",
          },
        );
      }
      return await operation({
        __transaction: true,
        user: this.user,
        sharedMember: this.sharedMember,
        planInvite: {
          findFirst: async ({ where }: any) => this.findFirstInvite(where),
          findUnique: async ({ where }: any) => this.findUniqueInvite(where),
          create: async ({ data }: any) => this.createInvite(data),
          updateMany: async ({ where, data }: any) =>
            this.updatePlanInvites(where, data),
        },
      });
    } catch (error) {
      this.invites = snapshot;
      throw error;
    } finally {
      release();
    }
  };

  private findUniqueInvite(where: Record<string, unknown>) {
    if (typeof where.id === "string") {
      return this.invites.find((invite) => invite.id === where.id) ?? null;
    }
    if (typeof where.tokenHash === "string") {
      return (
        this.invites.find((invite) => invite.tokenHash === where.tokenHash) ??
        null
      );
    }
    return null;
  }

  private findFirstInvite(where: Record<string, any>) {
    if (where.id) {
      return (
        this.invites.find(
          (invite) =>
            invite.id === where.id &&
            (!where.weddingPlanId ||
              invite.weddingPlanId === where.weddingPlanId),
        ) ?? null
      );
    }
    return (
      this.invites.find((invite) => {
        if (invite.weddingPlanId !== where.weddingPlanId) return false;
        if (where.acceptedAt === null && invite.acceptedAt !== null)
          return false;
        if (where.declinedAt === null && invite.declinedAt !== null)
          return false;
        if (where.revokedAt === null && invite.revokedAt !== null) return false;
        if (
          where.expiresAt?.gt &&
          invite.expiresAt.getTime() <= where.expiresAt.gt.getTime()
        ) {
          return false;
        }
        return (where.OR ?? []).some((candidate: Record<string, unknown>) =>
          Object.entries(candidate).every(
            ([key, value]) => invite[key] === value,
          ),
        );
      }) ?? null
    );
  }

  private createInvite(data: Record<string, any>) {
    const now = new Date();
    const invitee =
      this.users.find((user) => user.id === data.inviteeUserId) ?? null;
    const inviter =
      this.users.find((user) => user.id === data.inviterUserId) ?? null;
    const invite = {
      ...data,
      id: `invite-${++this.inviteSequence}`,
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null,
      createdAt: now,
      updatedAt: now,
      weddingPlan: {
        id: this.plan.id,
        title: this.plan.title,
        city: this.plan.city,
        weddingDate: this.plan.weddingDate,
        status: this.plan.status,
      },
      inviter: inviter
        ? { id: inviter.id, name: inviter.name, phone: inviter.phone }
        : undefined,
      invitee: invitee
        ? { id: invitee.id, name: invitee.name, phone: invitee.phone }
        : null,
    };
    this.invites.push(invite);
    return invite;
  }

  private updateInvites(
    where: Record<string, any>,
    data: Record<string, unknown>,
  ) {
    const matching = this.invites.filter((invite) => {
      if (invite.id !== where.id) return false;
      if (invite.weddingPlanId !== where.weddingPlanId) return false;
      if (where.tokenHash && invite.tokenHash !== where.tokenHash) return false;
      if (
        where.deliveryAttemptedAt instanceof Date &&
        invite.deliveryAttemptedAt?.getTime() !==
          where.deliveryAttemptedAt.getTime()
      ) {
        return false;
      }
      if (
        where.deliveryStatus !== undefined &&
        invite.deliveryStatus !== where.deliveryStatus
      ) {
        return false;
      }
      if (where.acceptedAt === null && invite.acceptedAt !== null) return false;
      if (where.declinedAt === null && invite.declinedAt !== null) return false;
      if (where.revokedAt === null && invite.revokedAt !== null) return false;
      if (
        where.expiresAt?.gt &&
        invite.expiresAt.getTime() <= where.expiresAt.gt.getTime()
      ) {
        return false;
      }
      return true;
    });
    for (const invite of matching) {
      Object.assign(invite, data, { updatedAt: new Date() });
    }
    return { count: matching.length };
  }

  private updatePlanInvites(
    where: Record<string, any>,
    data: Record<string, unknown>,
  ) {
    if (
      data.deliveryStatus !== PlanInviteDeliveryStatus.PENDING &&
      this.finalDeliveryPersistenceFailuresRemaining > 0
    ) {
      this.finalDeliveryPersistenceFailuresRemaining -= 1;
      throw (
        this.finalDeliveryPersistenceError ??
        new Prisma.PrismaClientKnownRequestError(
          "delivery persistence unavailable",
          { code: "P2024", clientVersion: "test" },
        )
      );
    }
    return this.updateInvites(where, data);
  }

  private matchesListWhere(invite: StoredInvite, where: Record<string, any>) {
    if (where.weddingPlanId && invite.weddingPlanId !== where.weddingPlanId) {
      return false;
    }
    if (where.inviterUserId && invite.inviterUserId !== where.inviterUserId) {
      return false;
    }
    if (where.OR) {
      return where.OR.some((candidate: Record<string, unknown>) =>
        Object.entries(candidate).every(
          ([key, value]) => invite[key] === value,
        ),
      );
    }
    return true;
  }
}

function sharingUser(id: string, phone: string, name = id): AuthenticatedUser {
  const now = new Date();
  return {
    id,
    name,
    phone,
    email: null,
    role: "USER",
    adminRole: null,
    appRole: "WEDDING_USER",
    status: "ACTIVE",
    phoneVerifiedAt: now,
    lastLoginAt: now,
    avatarUrl: null,
    locale: "ar",
    activeWeddingPlanId: "plan-1",
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: now,
    createdAt: now,
    updatedAt: now,
  } as AuthenticatedUser;
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
}

function inviteHarness(
  options: {
    notificationFailure?: Error;
    delivery?: (
      phone: string | null,
      token: string,
    ) => Promise<{
      channel: "WHATSAPP";
      status: "DELIVERED" | "UNCERTAIN" | "UNAVAILABLE";
    }>;
    finalDeliveryPersistenceFailures?: number;
  } = {},
) {
  const owner = sharingUser("owner-1", "+967777000001", "المالك");
  const target = sharingUser("target-1", "+967777000002", "المشارك");
  const db = new MemorySharingPrisma([owner, target]);
  let currentAccess: PlanAccessContext = {
    plan: db.plan as any,
    isOwner: true,
    sharedMember: null,
  };
  let transactionalAccess = currentAccess;
  const permissionService = new PermissionService({} as any);
  (permissionService as any).assertPlanReadable = async () => currentAccess;
  (permissionService as any).assertMemberManageable = async () => currentAccess;
  (permissionService as any).assertMemberManageableInTransaction = async () => {
    if (!permissionService.canManageMembers(transactionalAccess)) {
      throw new Error("Wedding plan not found");
    }
    return transactionalAccess;
  };
  const notificationInputs: Array<Record<string, any>> = [];
  db.finalDeliveryPersistenceFailuresRemaining =
    options.finalDeliveryPersistenceFailures ?? 0;
  const notificationService = {
    createNotificationInTransaction: async (
      tx: Record<string, any>,
      input: Record<string, any>,
    ) => {
      assert.equal(tx.__transaction, true);
      if (options.notificationFailure) throw options.notificationFailure;
      notificationInputs.push(input);
      return { id: "notification-1" };
    },
  } as unknown as NotificationsService;
  const service = new SharingService(
    db as any,
    permissionService,
    notificationService,
    {
      deliver:
        options.delivery ??
        (async () => ({ channel: "WHATSAPP", status: "DELIVERED" })),
    } as any,
  );

  return {
    db,
    owner,
    target,
    service,
    notificationInputs,
    setAccess: (access: PlanAccessContext) => {
      currentAccess = access;
      transactionalAccess = access;
    },
    setTransactionalAccess: (access: PlanAccessContext) => {
      transactionalAccess = access;
    },
  };
}

test("invite creation returns one raw bearer while storage and lists expose no raw token", async () => {
  const harness = inviteHarness();

  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: harness.target.phone!,
    role: SharedMemberRole.VIEWER,
  });

  assert.match(created.token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(created.weddingPlan?.title, harness.db.plan.title);
  assert.equal(created.inviter?.id, harness.owner.id);
  assert.equal(created.invitee?.id, harness.target.id);
  assert.equal(harness.db.invites.length, 1);
  assert.equal(
    harness.db.invites[0].tokenHash,
    createHash("sha256").update(created.token).digest("hex"),
  );
  assert.equal(
    JSON.stringify(harness.db.invites[0]).includes(created.token),
    false,
  );
  assert.equal(harness.notificationInputs.length, 1);
  assert.equal(created.delivery.status, PlanInviteDeliveryStatus.DELIVERED);
  assert.ok(created.delivery.attemptedAt instanceof Date);
  assert.ok(created.delivery.retryAfterSeconds > 0);
  assert.ok(created.delivery.retryAfterSeconds <= 60);
  assert.equal(
    harness.db.invites[0].deliveryStatus,
    PlanInviteDeliveryStatus.DELIVERED,
  );

  const listed = await harness.service.findInvitesForPlan(
    harness.owner,
    "plan-1",
  );
  assert.equal(listed.length, 1);
  assert.equal(listed[0].token, listed[0].id);
  assert.notEqual(listed[0].token, created.token);
  assert.equal(listed[0].delivery.status, created.delivery.status);
  assert.deepEqual(
    listed[0].delivery.attemptedAt,
    created.delivery.attemptedAt,
  );
  assert.ok(listed[0].delivery.retryAfterSeconds > 0);
  assert.equal(
    harness.db.transactionOptions[0].isolationLevel,
    Prisma.TransactionIsolationLevel.Serializable,
  );
});

test("invite notification failure rolls back the invite and token fingerprint", async () => {
  const harness = inviteHarness({
    notificationFailure: new Error("outbox unavailable"),
  });

  await assert.rejects(
    () =>
      harness.service.createInvite(harness.owner, "plan-1", {
        phone: harness.target.phone!,
      }),
    /outbox unavailable/,
  );
  assert.equal(harness.db.invites.length, 0);
});

test("a failed final delivery write returns the raw link while the durable invite remains PENDING", async () => {
  const harness = inviteHarness({ finalDeliveryPersistenceFailures: 1 });

  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: harness.target.phone!,
  });

  assert.match(created.token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(created.delivery.status, PlanInviteDeliveryStatus.PENDING);
  assert.equal(harness.db.invites.length, 1);
  assert.equal(
    harness.db.invites[0].deliveryStatus,
    PlanInviteDeliveryStatus.PENDING,
  );
  const listed = await harness.service.findInvitesForPlan(
    harness.owner,
    "plan-1",
  );
  assert.equal(listed[0].delivery.status, PlanInviteDeliveryStatus.PENDING);
  assert.ok(listed[0].delivery.attemptedAt instanceof Date);
});

test("a failed final reissue write preserves the rotated raw link and PENDING recovery state", async () => {
  const harness = inviteHarness();
  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: harness.target.phone!,
  });
  harness.db.invites[0].deliveryAttemptedAt = new Date(Date.now() - 61_000);
  harness.db.finalDeliveryPersistenceFailuresRemaining = 1;

  const reissued = await harness.service.reissueInvite(
    harness.owner,
    "plan-1",
    created.id,
  );

  assert.match(reissued.token, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(reissued.token, created.token);
  assert.equal(reissued.delivery.status, PlanInviteDeliveryStatus.PENDING);
  assert.equal(
    harness.db.invites[0].deliveryStatus,
    PlanInviteDeliveryStatus.PENDING,
  );
  await assert.rejects(
    () => (harness.service as any).findInviteByTokenOrThrow(created.token),
    /Invite not found/,
  );
  const recovered = await (harness.service as any).findInviteByTokenOrThrow(
    reissued.token,
  );
  assert.equal(recovered.id, created.id);
});

for (const deliveryStatus of ["UNCERTAIN", "UNAVAILABLE"] as const) {
  test(`invite creation persists ${deliveryStatus} without claiming delivery`, async () => {
    const harness = inviteHarness({
      delivery: async () => ({
        channel: "WHATSAPP",
        status: deliveryStatus,
      }),
    });

    const created = await harness.service.createInvite(
      harness.owner,
      "plan-1",
      { phone: harness.target.phone! },
    );

    assert.equal(created.delivery.status, deliveryStatus);
    assert.equal(harness.db.invites[0].deliveryStatus, deliveryStatus);
  });
}

for (const persistenceError of [
  new Error("delivery persistence logic error"),
  new Prisma.PrismaClientKnownRequestError("delivery constraint mismatch", {
    code: "P2003",
    clientVersion: "test",
  }),
]) {
  test(`final delivery persistence does not hide ${persistenceError.constructor.name}`, async () => {
    const harness = inviteHarness();
    harness.db.finalDeliveryPersistenceFailuresRemaining = 1;
    harness.db.finalDeliveryPersistenceError = persistenceError;

    await assert.rejects(
      () =>
        harness.service.createInvite(harness.owner, "plan-1", {
          phone: harness.target.phone!,
        }),
      (error) => error === persistenceError,
    );
    assert.equal(
      harness.db.invites[0].deliveryStatus,
      PlanInviteDeliveryStatus.PENDING,
    );
  });
}

test("invite creation fails closed when delegation is revoked before commit", async () => {
  const harness = inviteHarness();
  harness.setTransactionalAccess(
    memberContext(SharedMemberRole.VIEWER, { canInviteMembers: false }),
  );

  await assert.rejects(
    () =>
      harness.service.createInvite(harness.owner, "plan-1", {
        phone: harness.target.phone!,
      }),
    /Wedding plan not found/,
  );
  assert.equal(harness.db.invites.length, 0);
  assert.equal(harness.notificationInputs.length, 0);
});

test("invite target lookup prefers the exact canonical phone identity", async () => {
  const harness = inviteHarness();
  const legacy = sharingUser("legacy-target", "777000099");
  const canonical = sharingUser("canonical-target", "+967777000099");
  harness.db.users.push(legacy, canonical);

  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: "777000099",
  });

  assert.equal(created.invitee?.id, canonical.id);
  assert.notEqual(created.invitee?.id, legacy.id);
});

test("invite creation retries a serialization abort without duplicating its notification", async () => {
  const harness = inviteHarness();
  harness.db.serializationFailuresRemaining = 1;

  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: harness.target.phone!,
  });

  assert.match(created.token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(harness.db.invites.length, 1);
  assert.equal(harness.notificationInputs.length, 1);
  assert.equal(harness.db.transactionOptions.length, 3);
  assert.ok(
    harness.db.transactionOptions.every(
      (options) =>
        options.isolationLevel ===
        Prisma.TransactionIsolationLevel.Serializable,
    ),
  );
});

test("concurrent creates for the same target leave exactly one pending invite", async () => {
  const harness = inviteHarness();
  const create = () =>
    harness.service.createInvite(harness.owner, "plan-1", {
      phone: "+967777000099",
    });

  const results = await Promise.allSettled([create(), create()]);
  assert.equal(
    results.filter((result) => result.status === "fulfilled").length,
    1,
  );
  assert.equal(
    results.filter((result) => result.status === "rejected").length,
    1,
  );
  assert.match(
    String(
      (
        results.find(
          (result) => result.status === "rejected",
        ) as PromiseRejectedResult
      ).reason?.message,
    ),
    /pending invitation already exists/,
  );
  assert.equal(harness.db.invites.length, 1);
  assert.equal(
    harness.db.transactionOptions.every(
      (options) =>
        options.isolationLevel ===
        Prisma.TransactionIsolationLevel.Serializable,
    ),
    true,
  );
});

test("reissue returns a stable 429 contract during the sixty-second delivery cooldown", async () => {
  const harness = inviteHarness();
  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: "+967777000099",
  });

  await assert.rejects(
    () => harness.service.reissueInvite(harness.owner, "plan-1", created.id),
    (error: unknown) => {
      assert.ok(error instanceof HttpException);
      assert.equal(error.getStatus(), 429);
      const body = error.getResponse() as Record<string, unknown>;
      assert.equal(body.statusCode, 429);
      assert.equal(body.code, "INVITE_REISSUE_COOLDOWN");
      assert.equal(
        body.message,
        "Invite delivery was attempted recently. Try again later.",
      );
      assert.equal(typeof body.retryAfterSeconds, "number");
      assert.ok(Number(body.retryAfterSeconds) > 0);
      assert.ok(Number(body.retryAfterSeconds) <= 60);
      return true;
    },
  );
});

test("reissuing a pending invite rotates the bearer atomically and invalidates the old token", async () => {
  const harness = inviteHarness();
  const participant = sharingUser(
    "future-participant",
    "+967777000099",
    "مشارك جديد",
  );
  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: participant.phone!,
  });

  const before = await harness.service.getInviteForCurrentUser(
    participant,
    created.token,
  );
  assert.equal(before.id, created.id);
  harness.db.invites[0].deliveryAttemptedAt = new Date(Date.now() - 61_000);

  const reissued = await harness.service.reissueInvite(
    harness.owner,
    "plan-1",
    created.id,
    {
      role: SharedMemberRole.FAMILY,
      canViewMoney: false,
      canEditPlan: false,
      canManageTasks: true,
      canManageGuests: true,
      canManageProviders: false,
      canInviteMembers: false,
      canManageMoney: false,
      receiveNotifications: true,
    },
  );
  assert.match(reissued.token, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(reissued.token, created.token);
  assert.equal(reissued.role, SharedMemberRole.FAMILY);
  assert.equal(reissued.canManageTasks, true);
  assert.equal(reissued.canManageGuests, true);
  assert.equal(reissued.canManageMoney, false);
  assert.equal(harness.db.invites.length, 1);
  await assert.rejects(
    () => harness.service.getInviteForCurrentUser(participant, created.token),
    /Invite not found/,
  );
  const after = await harness.service.getInviteForCurrentUser(
    participant,
    reissued.token,
  );
  assert.equal(after.id, created.id);
  assert.equal(after.token, created.id);
});

test("concurrent reissues rotate once and throttle the losing request", async () => {
  const harness = inviteHarness();
  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: "+967777000099",
  });
  harness.db.invites[0].deliveryAttemptedAt = new Date(Date.now() - 61_000);

  const reissue = () =>
    harness.service.reissueInvite(harness.owner, "plan-1", created.id);
  const results = await Promise.allSettled([reissue(), reissue()]);

  assert.equal(
    results.filter((result) => result.status === "fulfilled").length,
    1,
  );
  const rejected = results.find(
    (result) => result.status === "rejected",
  ) as PromiseRejectedResult;
  assert.ok(rejected.reason instanceof HttpException);
  assert.equal(rejected.reason.getStatus(), 429);
  assert.equal(
    (rejected.reason.getResponse() as Record<string, unknown>).code,
    "INVITE_REISSUE_COOLDOWN",
  );
  assert.equal(
    harness.db.invites[0].deliveryStatus,
    PlanInviteDeliveryStatus.DELIVERED,
  );
});

test("an old delivery completion cannot overwrite a newer rotated token attempt", async () => {
  const firstDelivery = deferred<{
    channel: "WHATSAPP";
    status: "UNCERTAIN";
  }>();
  let deliveryCalls = 0;
  const harness = inviteHarness({
    delivery: async () => {
      deliveryCalls += 1;
      if (deliveryCalls === 1) return firstDelivery.promise;
      return { channel: "WHATSAPP", status: "DELIVERED" };
    },
  });

  const creating = harness.service.createInvite(harness.owner, "plan-1", {
    phone: "+967777000099",
  });
  while (harness.db.invites.length === 0 || deliveryCalls === 0) {
    await new Promise<void>((resolve) => setImmediate(resolve));
  }

  const stored = harness.db.invites[0];
  stored.deliveryAttemptedAt = new Date(Date.now() - 61_000);
  const reissued = await harness.service.reissueInvite(
    harness.owner,
    "plan-1",
    stored.id,
  );
  assert.equal(reissued.delivery.status, PlanInviteDeliveryStatus.DELIVERED);

  firstDelivery.resolve({ channel: "WHATSAPP", status: "UNCERTAIN" });
  await assert.rejects(creating, (error: unknown) => {
    assert.ok(error instanceof HttpException);
    assert.equal(error.getStatus(), 409);
    assert.equal(
      (error.getResponse() as Record<string, unknown>).code,
      "INVITE_DELIVERY_ATTEMPT_SUPERSEDED",
    );
    return true;
  });

  assert.equal(
    harness.db.invites[0].deliveryStatus,
    PlanInviteDeliveryStatus.DELIVERED,
  );
});

test("cancelling during external delivery supersedes finalization and never re-presents the raw bearer", async () => {
  const deliveryStarted = deferred<void>();
  const deliveryFinished = deferred<{
    channel: "WHATSAPP";
    status: "DELIVERED";
  }>();
  let deliveredToken: string | null = null;
  let deliveryCalls = 0;
  const harness = inviteHarness({
    delivery: async (_phone, token) => {
      deliveryCalls += 1;
      deliveredToken = token;
      deliveryStarted.resolve();
      return deliveryFinished.promise;
    },
  });

  const creating = harness.service.createInvite(harness.owner, "plan-1", {
    phone: "+967777000099",
  });
  await deliveryStarted.promise;

  const pending = harness.db.invites[0];
  assert.ok(pending);
  const cancelled = await harness.service.cancelInvite(
    harness.owner,
    "plan-1",
    pending.id,
  );
  assert.equal(cancelled.status, "CANCELLED");
  assert.equal(cancelled.token, pending.id);

  deliveryFinished.resolve({
    channel: "WHATSAPP",
    status: "DELIVERED",
  });
  await assert.rejects(creating, (error: unknown) => {
    assert.ok(error instanceof HttpException);
    assert.equal(error.getStatus(), 409);
    assert.equal(
      (error.getResponse() as Record<string, unknown>).code,
      "INVITE_DELIVERY_ATTEMPT_SUPERSEDED",
    );
    return true;
  });

  assert.equal(deliveryCalls, 1);
  assert.match(deliveredToken ?? "", /^[A-Za-z0-9_-]{43}$/);
  assert.ok(pending.revokedAt instanceof Date);
  assert.equal(
    pending.deliveryStatus,
    PlanInviteDeliveryStatus.PENDING,
    "a terminal invite must not be finalized by the stale delivery attempt",
  );
  const terminalResponse = (harness.service as any).toInviteResponse(
    pending,
    deliveredToken,
  );
  assert.equal(
    terminalResponse.token,
    pending.id,
    "a terminal invite response must never expose the raw bearer",
  );
});

test("cancelling an invite claims only the still-pending row", async () => {
  const harness = inviteHarness();
  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: "+967777000099",
  });

  const cancelled = await harness.service.cancelInvite(
    harness.owner,
    "plan-1",
    created.id,
  );

  assert.equal(cancelled.status, "CANCELLED");
  assert.ok(harness.db.invites[0].revokedAt instanceof Date);
  const finalTransactionOptions =
    harness.db.transactionOptions[harness.db.transactionOptions.length - 1];
  assert.equal(
    finalTransactionOptions?.isolationLevel,
    Prisma.TransactionIsolationLevel.Serializable,
  );
});

test("cancelling loses safely when acceptance wins between read and claim", async () => {
  const harness = inviteHarness();
  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: "+967777000099",
  });
  const pending = harness.db.invites[0];

  (harness.db as any).$transaction = async (
    operation: (tx: Record<string, any>) => Promise<any>,
    options: Record<string, unknown>,
  ) => {
    harness.db.transactionOptions.push(options);
    return operation({
      __transaction: true,
      sharedMember: harness.db.sharedMember,
      planInvite: {
        findFirst: async () => pending,
        updateMany: async () => ({ count: 0 }),
        findUnique: async () => pending,
      },
    });
  };

  await assert.rejects(
    () => harness.service.cancelInvite(harness.owner, "plan-1", created.id),
    /Invite is no longer pending/,
  );
  assert.equal(pending.revokedAt, null);
});

test("raw invite claims stay bound to the current token fingerprint", () => {
  const harness = inviteHarness();
  const rawToken = "abcdefghijklmnopqrstuvwxyzABCDEFGH123456789";
  const invite = { id: "invite-1" } as any;

  assert.deepEqual(
    (harness.service as any).inviteClaimTokenFilter(invite, rawToken),
    { tokenHash: createHash("sha256").update(rawToken).digest("hex") },
  );
  assert.deepEqual(
    (harness.service as any).inviteClaimTokenFilter(invite, invite.id),
    {},
  );
});

test("current-user invite context requires one live membership batch without rewriting accepted history", async () => {
  const user = sharingUser(
    "context-user",
    "+967777000088",
    "context participant",
  );
  const acceptedAt = new Date("2026-07-20T10:00:00.000Z");
  const makeInvite = (id: string, weddingPlanId: string) =>
    ({
      id,
      weddingPlanId,
      inviterUserId: "owner-1",
      inviteeUserId: user.id,
      name: user.name,
      phone: user.phone,
      normalizedPhone: user.phone,
      email: null,
      tokenHash: createHash("sha256").update(id).digest("hex"),
      role: SharedMemberRole.VIEWER,
      ...rolePermissionDefaults(SharedMemberRole.VIEWER),
      acceptedAt,
      declinedAt: null,
      revokedAt: null,
      expiresAt: new Date("2026-12-01T00:00:00.000Z"),
      deliveryStatus: PlanInviteDeliveryStatus.DELIVERED,
      deliveryAttemptedAt: new Date("2026-07-19T10:00:00.000Z"),
      createdAt: new Date("2026-07-19T10:00:00.000Z"),
      updatedAt: acceptedAt,
      inviter: sharingUser("owner-1", "+967777000001", "owner"),
      invitee: user,
    }) as any;
  const liveInvite = makeInvite("accepted-live", "plan-live");
  const removedInvite = makeInvite("accepted-removed", "plan-removed");
  const membershipListQueries: Array<Record<string, any>> = [];
  const membershipDetailQueries: Array<Record<string, any>> = [];
  const prisma = {
    planInvite: {
      findMany: async () => [liveInvite, removedInvite],
      findUnique: async ({ where }: any) => {
        if (where.tokenHash) return null;
        return [liveInvite, removedInvite].find(
          (invite) => invite.id === where.id,
        );
      },
    },
    sharedMember: {
      findMany: async (query: Record<string, any>) => {
        membershipListQueries.push(query);
        return [{ weddingPlanId: "plan-live" }];
      },
      findUnique: async (query: Record<string, any>) => {
        membershipDetailQueries.push(query);
        return query.where.weddingPlanId_userId.weddingPlanId === "plan-live"
          ? { id: "member-live" }
          : null;
      },
    },
  };
  const service = new SharingService(
    prisma as any,
    {} as any,
    {} as any,
    {} as any,
  );

  const listed = await service.findInvitesForCurrentUser(user);
  const listedLive = listed.find((invite) => invite.id === liveInvite.id);
  const listedRemoved = listed.find((invite) => invite.id === removedInvite.id);
  assert.equal(
    listedLive?.contextKey,
    "plan:plan-live:contributor",
    "an accepted invite with a live member retains its contributor context",
  );
  assert.equal(
    listedRemoved?.contextKey,
    undefined,
    "historical acceptance cannot recreate a removed contributor context",
  );
  assert.equal(
    listedRemoved?.acceptedAt,
    acceptedAt,
    "membership removal must not rewrite accepted invitation history",
  );
  assert.equal(
    membershipListQueries.length,
    1,
    "the current-user list must batch all membership validation",
  );
  assert.deepEqual(membershipListQueries[0]?.where, {
    userId: user.id,
    weddingPlanId: { in: ["plan-live", "plan-removed"] },
  });

  const liveDetail = await service.getInviteForCurrentUser(
    user,
    liveInvite.id,
  );
  const removedDetail = await service.getInviteForCurrentUser(
    user,
    removedInvite.id,
  );
  assert.equal(liveDetail.contextKey, "plan:plan-live:contributor");
  assert.equal(removedDetail.contextKey, undefined);
  assert.equal(removedDetail.acceptedAt, acceptedAt);
  assert.equal(membershipDetailQueries.length, 2);
});

test("a lost invite-accept response can be retried without changing newer membership or duplicating notification", async () => {
  const harness = inviteHarness();
  const outsider = sharingUser(
    "accept-replay-outsider",
    "+967777000077",
    "outsider",
  );
  harness.target.activeWeddingPlanId = "already-selected-plan";
  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: harness.target.phone!,
    role: SharedMemberRole.FINANCE_MANAGER,
    canViewMoney: true,
    canManageProviders: true,
    canManageMoney: true,
  });
  const storedInvite = harness.db.invites[0];
  const newerMembershipAt = new Date(storedInvite.updatedAt.getTime() + 1_000);
  let currentMembership = {
    id: "member-newer-than-invite",
    weddingPlanId: "plan-1",
    userId: harness.target.id,
    role: SharedMemberRole.VIEWER,
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
    receiveNotifications: true,
    createdAt: newerMembershipAt,
    updatedAt: newerMembershipAt,
    user: harness.target,
  };
  (harness.db.sharedMember as any).findMany = async () => [
    currentMembership,
  ];
  let providerParticipationWrites = 0;

  (harness.db as any).$transaction = async (
    operation: (tx: Record<string, any>) => Promise<any>,
    options: Record<string, unknown> = {},
  ) => {
    harness.db.transactionOptions.push(options);
    return operation({
      __transaction: true,
      $queryRaw: async (query: any) => {
        const sql = Array.isArray(query?.strings)
          ? query.strings.join(" ")
          : String(query);
        if (sql.includes('FROM "User"')) {
          return [harness.owner, harness.target, outsider].map(
            ({ id, status }) => ({
              id,
              status,
            }),
          );
        }
        if (sql.includes('FROM "PlanInvite"')) {
          return [{ id: storedInvite.id }];
        }
        return [{ id: "plan-1" }];
      },
      weddingPlan: {
        findUnique: async () => harness.db.plan,
      },
      planInvite: {
        findFirst: harness.db.planInvite.findFirst,
        findUnique: harness.db.planInvite.findUnique,
        updateMany: async ({ where, data }: any) =>
          harness.db.planInvite.updateMany({
            where: {
              weddingPlanId: storedInvite.weddingPlanId,
              ...where,
            },
            data,
          }),
      },
      sharedMember: {
        findUnique: async () => currentMembership,
        upsert: async ({ update }: any) => {
          currentMembership = {
            ...currentMembership,
            ...update,
            updatedAt: new Date(),
            user: harness.target,
          };
          return currentMembership;
        },
      },
      conversation: {
        findMany: async () => [
          {
            id: "conversation-for-newer-member",
            provider: { userId: "provider-user" },
            weddingPlan: { ownerUserId: harness.owner.id },
          },
        ],
      },
      conversationParticipant: {
        updateMany: async () => {
          providerParticipationWrites += 1;
          return { count: 1 };
        },
        createMany: async () => {
          providerParticipationWrites += 1;
          return { count: 1 };
        },
      },
    });
  };

  const accepted = await harness.service.acceptInvite(
    harness.target,
    created.id,
  );
  const acceptedNotificationCount = harness.notificationInputs.filter(
    (input) => input.type === "SHARING_INVITE_ACCEPTED",
  ).length;
  assert.equal(acceptedNotificationCount, 1);
  const replayed = await harness.service.acceptInvite(
    harness.target,
    created.id,
  );
  harness.db.plan.status = "ARCHIVED";
  await assert.rejects(
    () => harness.service.acceptInvite(outsider, created.id),
    (error: unknown) =>
      error instanceof HttpException && error.getStatus() === 404,
    "another account must not learn the accepted invitation's archived plan state",
  );
  harness.db.plan.status = "PLANNING";
  const expectedMembership = {
    role: SharedMemberRole.VIEWER,
    canViewMoney: false,
    canManageProviders: false,
    canManageMoney: false,
  };

  assert.deepEqual(
    {
      returned: {
        role: accepted.member.role,
        canViewMoney: accepted.member.canViewMoney,
        canManageProviders: accepted.member.canManageProviders,
        canManageMoney: accepted.member.canManageMoney,
      },
      stored: {
        role: currentMembership.role,
        canViewMoney: currentMembership.canViewMoney,
        canManageProviders: currentMembership.canManageProviders,
        canManageMoney: currentMembership.canManageMoney,
      },
      providerParticipationWrites,
    },
    {
      returned: expectedMembership,
      stored: expectedMembership,
      providerParticipationWrites: 0,
    },
    "the newer membership must remain authoritative over the stale invite snapshot",
  );
  assert.equal(
    (accepted as any).contextKey,
    "plan:plan-1:contributor",
    "invite acceptance must return the canonical additive context key",
  );
  assert.deepEqual(
    {
      inviteId: replayed.invite.id,
      status: replayed.invite.status,
      memberId: replayed.member.id,
      contextKey: replayed.contextKey,
    },
    {
      inviteId: accepted.invite.id,
      status: "ACCEPTED",
      memberId: accepted.member.id,
      contextKey: accepted.contextKey,
    },
    "retrying after a lost success response must replay the accepted result",
  );
  assert.equal(
    harness.notificationInputs.filter(
      (input) => input.type === "SHARING_INVITE_ACCEPTED",
    ).length,
    acceptedNotificationCount,
    "an accepted replay must not create a second owner notification",
  );
  const acceptedInvites = await harness.service.findInvitesForCurrentUser(
    harness.target,
  );
  assert.equal(
    acceptedInvites[0]?.contextKey,
    "plan:plan-1:contributor",
    "the current user's accepted invite must retain its backend context key",
  );
  assert.equal(
    harness.target.activeWeddingPlanId,
    "already-selected-plan",
    "invite acceptance must not replace an already selected plan",
  );
});

test("decline is concurrent and lost-response idempotent only for the verified invitee", async () => {
  const harness = inviteHarness();
  const outsider = sharingUser(
    "decline-replay-outsider",
    "+967777000078",
    "outsider",
  );
  harness.db.users.push(outsider);
  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: harness.target.phone!,
    role: SharedMemberRole.VIEWER,
  });
  const storedInvite = harness.db.invites[0];
  let transactionTail = Promise.resolve();

  (harness.db as any).$transaction = async (
    operation: (tx: Record<string, any>) => Promise<any>,
    options: Record<string, unknown> = {},
  ) => {
    const previous = transactionTail;
    let release!: () => void;
    transactionTail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;
    harness.db.transactionOptions.push(options);
    try {
      return await operation({
        __transaction: true,
        $queryRaw: async (query: any) => {
          const sql = Array.isArray(query?.strings)
            ? query.strings.join(" ")
            : String(query);
          if (sql.includes('FROM "User"')) {
            return [harness.owner, harness.target, outsider].map(
              ({ id, status }) => ({ id, status }),
            );
          }
          if (sql.includes('FROM "PlanInvite"')) {
            return [{ id: storedInvite.id }];
          }
          return [{ id: "plan-1" }];
        },
        weddingPlan: {
          findUnique: async () => harness.db.plan,
        },
        planInvite: {
          findUnique: harness.db.planInvite.findUnique,
          updateMany: async ({ where, data }: any) =>
            harness.db.planInvite.updateMany({
              where: {
                weddingPlanId: storedInvite.weddingPlanId,
                ...where,
              },
              data,
            }),
        },
      });
    } finally {
      release();
    }
  };

  const concurrent = await Promise.all([
    harness.service.declineInvite(harness.target, created.token),
    harness.service.declineInvite(harness.target, created.token),
  ]);
  const replayedById = await harness.service.declineInvite(
    harness.target,
    created.id,
  );
  await assert.rejects(
    () => harness.service.declineInvite(outsider, created.id),
    (error: unknown) =>
      error instanceof HttpException && error.getStatus() === 404,
    "decline replay must not reveal invitation lifecycle to another account",
  );

  assert.deepEqual(
    [...concurrent, replayedById].map((invite) => ({
      id: invite.id,
      status: invite.status,
      declinedAt: invite.declinedAt,
    })),
    Array.from({ length: 3 }, () => ({
      id: storedInvite.id,
      status: "DECLINED",
      declinedAt: storedInvite.declinedAt,
    })),
  );
  assert.equal(
    harness.notificationInputs.filter(
      (input) => input.type === "SHARING_INVITE_DECLINED",
    ).length,
    1,
    "concurrent and lost-response retries must create one decline notification",
  );
});

test("member removal locks pending invitations before the target member and revokes every live identity match", async () => {
  const owner = sharingUser("remove-owner", "+967777000001", "owner");
  const target = sharingUser("remove-target", "+967777000002", "target");
  const targetMember = {
    id: "member-remove-target",
    weddingPlanId: "plan-remove",
    userId: target.id,
    role: SharedMemberRole.VIEWER,
    ...rolePermissionDefaults(SharedMemberRole.VIEWER),
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
  };
  const lockOrder: string[] = [];
  const revokedWrites: Array<Record<string, any>> = [];
  let memberDeleted = false;
  const permissionService = new PermissionService({} as any);
  (permissionService as any).assertMemberManageableInTransaction = async () => {
    lockOrder.push("Plan");
    return {
      plan: {
        id: "plan-remove",
        ownerUserId: owner.id,
        status: "PLANNING",
      },
      isOwner: true,
      sharedMember: null,
    };
  };
  const prisma = {
    sharedMember: {
      findFirst: async () =>
        memberDeleted ? null : { ...targetMember, userId: target.id },
    },
    $transaction: async (
      operation: (tx: Record<string, any>) => Promise<any>,
    ) =>
      operation({
        __transaction: true,
        user: {
          findUnique: async () => ({ id: target.id, phone: target.phone }),
        },
        $queryRaw: async (query: any) => {
          const sql = Array.isArray(query?.strings)
            ? query.strings.join(" ")
            : String(query);
          if (sql.includes('FROM "PlanInvite"')) {
            lockOrder.push("PlanInvite");
            return [{ id: "pending-by-user" }, { id: "pending-by-phone" }];
          }
          if (sql.includes('FROM "SharedMember"')) {
            lockOrder.push("SharedMember");
            return [{ id: targetMember.id }];
          }
          return [];
        },
        planInvite: {
          updateMany: async (query: Record<string, any>) => {
            revokedWrites.push(query);
            return { count: 2 };
          },
        },
        sharedMember: {
          findFirst: async () =>
            memberDeleted ? null : { ...targetMember, userId: target.id },
          delete: async () => {
            memberDeleted = true;
            return targetMember;
          },
        },
        conversation: {
          findMany: async () => [],
        },
      }),
  };
  const notifications = {
    purgeMoneyForMember: async () => undefined,
  };
  const service = new SharingService(
    prisma as any,
    permissionService,
    notifications as any,
    {} as any,
  );

  const removed = await service.removeMemberFromPlan(
    owner,
    "plan-remove",
    targetMember.id,
  );

  assert.deepEqual(removed, { id: targetMember.id, deleted: true });
  assert.deepEqual(
    lockOrder,
    ["Plan", "PlanInvite", "SharedMember"],
    "the anti-resurrection boundary must lock Plan, matching PlanInvite rows, then SharedMember",
  );
  assert.equal(revokedWrites.length, 1);
  assert.deepEqual(revokedWrites[0]?.where.id, {
    in: ["pending-by-user", "pending-by-phone"],
  });
  assert.equal(revokedWrites[0]?.where.acceptedAt, null);
  assert.equal(revokedWrites[0]?.where.declinedAt, null);
  assert.equal(revokedWrites[0]?.where.revokedAt, null);
  assert.equal(revokedWrites[0]?.data.revokedAt instanceof Date, true);
  assert.equal(memberDeleted, true);
});

test("reissue rejects historical invitations and delegated authority above the inviter ceiling", async () => {
  for (const state of ["acceptedAt", "declinedAt", "revokedAt", "expired"]) {
    const harness = inviteHarness();
    const created = await harness.service.createInvite(
      harness.owner,
      "plan-1",
      { phone: "+967777000099" },
    );
    const invite = harness.db.invites[0];
    if (state === "expired") {
      invite.expiresAt = new Date(Date.now() - 1);
    } else {
      invite[state] = new Date();
    }
    await assert.rejects(
      () => harness.service.reissueInvite(harness.owner, "plan-1", created.id),
      /Invite is no longer pending/,
    );
  }

  const harness = inviteHarness();
  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: "+967777000099",
    role: SharedMemberRole.FINANCE_MANAGER,
  });
  const delegatedUser = sharingUser("delegate-1", "+967777000003", "المفوّض");
  harness.setAccess({
    plan: harness.db.plan as any,
    isOwner: false,
    sharedMember: {
      id: "member-delegate",
      weddingPlanId: "plan-1",
      userId: delegatedUser.id,
      role: SharedMemberRole.VIEWER,
      ...rolePermissionDefaults(SharedMemberRole.VIEWER),
      canInviteMembers: true,
    } as any,
  });
  await assert.rejects(
    () => harness.service.reissueInvite(delegatedUser, "plan-1", created.id),
    /Invite not found/,
  );

  harness.db.invites[0].inviterUserId = delegatedUser.id;
  await assert.rejects(
    () => harness.service.reissueInvite(delegatedUser, "plan-1", created.id),
    /Cannot grant permission above inviter ceiling/,
  );
});

test("reissue cannot raise a pending invite above a delegated inviter ceiling", async () => {
  const harness = inviteHarness();
  const created = await harness.service.createInvite(harness.owner, "plan-1", {
    phone: "+967777000099",
    role: SharedMemberRole.VIEWER,
  });
  const invite = harness.db.invites[0];
  const delegatedUser = sharingUser(
    "delegate-reissue",
    "+967777000004",
    "المفوّض",
  );
  invite.inviterUserId = delegatedUser.id;
  harness.setAccess({
    plan: harness.db.plan as any,
    isOwner: false,
    sharedMember: {
      id: "member-delegate-reissue",
      weddingPlanId: "plan-1",
      userId: delegatedUser.id,
      role: SharedMemberRole.VIEWER,
      ...rolePermissionDefaults(SharedMemberRole.VIEWER),
      canInviteMembers: true,
    } as any,
  });
  const originalTokenHash = invite.tokenHash;

  await assert.rejects(
    () =>
      harness.service.reissueInvite(delegatedUser, "plan-1", created.id, {
        canManageTasks: true,
      }),
    /Cannot grant permission above inviter ceiling/,
  );
  assert.equal(invite.tokenHash, originalTokenHash);
  assert.equal(invite.canManageTasks, false);
});

test("invite create and reissue source contract stays transactional and authenticated", () => {
  const serviceSource = readFileSync(
    join(process.cwd(), "src/sharing/sharing.service.ts"),
    "utf8",
  );
  const controllerSource = readFileSync(
    join(process.cwd(), "src/sharing/sharing.controller.ts"),
    "utf8",
  );
  const createBlock = serviceSource.slice(
    serviceSource.indexOf("async createInvite("),
    serviceSource.indexOf("async findInvitesForCurrentUser("),
  );
  const reissueBlock = serviceSource.slice(
    serviceSource.indexOf("async reissueInvite("),
    serviceSource.indexOf("async acceptInvite("),
  );

  assert.match(createBlock, /runSerializableTransaction/);
  assert.match(createBlock, /assertMemberManageableInTransaction/);
  assert.match(createBlock, /createNotificationInTransaction\(tx/);
  assert.doesNotMatch(createBlock, /createNotification\(/);
  assert.match(createBlock, /planInvite\.findFirst/);
  assert.match(createBlock, /planInvite\.create/);
  assert.match(reissueBlock, /runSerializableTransaction/);
  assert.match(reissueBlock, /assertMemberManageableInTransaction/);
  assert.match(reissueBlock, /permissionDataForUpdate/);
  assert.match(reissueBlock, /assertPermissionCeiling/);
  assert.match(reissueBlock, /tokenHash:\s*invite\.tokenHash/);
  assert.match(reissueBlock, /acceptedAt:\s*null/);
  assert.match(reissueBlock, /expiresAt:\s*\{\s*gt:\s*now/);
  assert.match(
    controllerSource,
    /@Post\(":inviteId\/reissue"\)[\s\S]*?reissueInvite\(/,
  );
  assert.match(
    controllerSource,
    /@Controller\("api\/v1\/wedding-plans\/:weddingPlanId\/invites"\)[\s\S]*?@UseGuards\(JwtAuthGuard\)/,
  );
});

test("direct member creation persists its notification in the same transaction", () => {
  const serviceSource = readFileSync(
    join(process.cwd(), "src/sharing/sharing.service.ts"),
    "utf8",
  );
  const createBlock = serviceSource.slice(
    serviceSource.indexOf("async create("),
    serviceSource.indexOf("async findSharedPlans("),
  );

  assert.match(createBlock, /runSerializableTransaction/);
  assert.match(createBlock, /assertMemberManageableInTransaction/);
  assert.match(createBlock, /createNotificationInTransaction\(tx/);
  assert.doesNotMatch(createBlock, /createNotification\(/);
});

test("invite delivery migration preserves unknown historical outcomes", () => {
  const migration = readFileSync(
    join(
      process.cwd(),
      "prisma/migrations/20260718120000_persist_plan_invite_delivery/migration.sql",
    ),
    "utf8",
  );

  assert.match(migration, /'UNKNOWN'/);
  assert.match(migration, /deliveryStatus"[^;]+NOT NULL DEFAULT 'UNKNOWN'/s);
});
