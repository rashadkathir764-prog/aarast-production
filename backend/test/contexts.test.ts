import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import {
  BadRequestException,
  ConflictException,
  NotFoundException,
  ValidationPipe,
} from "@nestjs/common";
import {
  ProviderStatus,
  SharedMemberRole,
  WeddingPlanStatus,
  WeddingPersona,
} from "@prisma/client";
import {
  AvailableContextRole,
  ContextsService,
} from "../src/contexts/contexts.service";
import { ValidateContextDto } from "../src/contexts/dto/validate-context.dto";
import { PermissionService } from "../src/sharing/permission.service";
import { UpdateProfileDto } from "../src/users/dto/update-profile.dto";
import { WeddingPlansService } from "../src/wedding-plans/wedding-plans.service";

const currentUser = { id: "user-1" } as any;
const now = new Date("2026-07-25T12:00:00.000Z");

function plan(
  id: string,
  ownerUserId: string,
  title: string,
  options: {
    status?: WeddingPlanStatus;
    updatedAt?: Date;
  } = {},
) {
  return {
    id,
    ownerUserId,
    title,
    city: null,
    location: null,
    weddingDate: null,
    priorities: [],
    estimatedBudget: null,
    currency: "YER",
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: null,
    importMigrationId: null,
    status: options.status ?? WeddingPlanStatus.PLANNING,
    createdAt: now,
    updatedAt: options.updatedAt ?? now,
  } as any;
}

function membership(
  weddingPlan: ReturnType<typeof plan>,
  options: {
    userId?: string;
    role?: SharedMemberRole;
    canViewMoney?: boolean;
    canEditPlan?: boolean;
    canManageTasks?: boolean;
    canManageGuests?: boolean;
    canManageProviders?: boolean;
    canInviteMembers?: boolean;
    canManageMoney?: boolean;
    authorityVersion?: number;
  } = {},
) {
  return {
    id: `member-${weddingPlan.id}`,
    weddingPlanId: weddingPlan.id,
    userId: options.userId ?? currentUser.id,
    role: options.role ?? SharedMemberRole.VIEWER,
    canViewMoney: options.canViewMoney ?? false,
    canEditPlan: options.canEditPlan ?? false,
    canManageTasks: options.canManageTasks ?? false,
    canManageGuests: options.canManageGuests ?? false,
    canManageProviders: options.canManageProviders ?? false,
    canInviteMembers: options.canInviteMembers ?? false,
    canManageMoney: options.canManageMoney ?? false,
    receiveNotifications: true,
    authorityVersion: options.authorityVersion ?? 1,
    createdAt: now,
    updatedAt: now,
    weddingPlan,
  };
}

function provider(
  id: string,
  userId = currentUser.id,
  status: ProviderStatus = ProviderStatus.PENDING,
) {
  return {
    id,
    userId,
    businessName: `Provider ${id}`,
    status,
  } as any;
}

class FakeContextsPrisma {
  plans: Array<ReturnType<typeof plan>> = [];
  memberships: Array<ReturnType<typeof membership>> = [];
  providers: Array<ReturnType<typeof provider>> = [];

  weddingPlan: any;

  constructor() {
    this.weddingPlan = {
      findMany: async ({ where }: any) =>
        this.plans.filter((item) => item.ownerUserId === where.ownerUserId),
      findFirst: async ({ where }: any) =>
        this.plans.find(
          (item) =>
            item.id === where.id && item.ownerUserId === where.ownerUserId,
        ) ?? null,
    };
  }

  sharedMember = {
    findMany: async ({ where }: any) =>
      this.memberships.filter((item) => item.userId === where.userId),
    findUnique: async ({ where }: any) => {
      const key = where.weddingPlanId_userId;
      return (
        this.memberships.find(
          (item) =>
            item.weddingPlanId === key.weddingPlanId &&
            item.userId === key.userId,
        ) ?? null
      );
    },
  };

  provider = {
    findUnique: async ({ where }: any) =>
      this.providers.find((item) => item.userId === where.userId) ?? null,
    findFirst: async ({ where }: any) =>
      this.providers.find(
        (item) => item.id === where.id && item.userId === where.userId,
      ) ?? null,
  };
}

function contextsHarness() {
  const prisma = new FakeContextsPrisma();
  const permissions = new PermissionService({} as any);
  return {
    prisma,
    service: new ContextsService(prisma as any, permissions),
  };
}

test("owner-only account exposes one trusted owner context", async () => {
  const { prisma, service } = contextsHarness();
  const ownedPlan = plan("plan-owner", currentUser.id, "My wedding");
  ownedPlan.persona = WeddingPersona.GROOM;
  prisma.plans.push(ownedPlan);

  const contexts = await service.list(currentUser);

  assert.equal(contexts.length, 1);
  assert.equal(contexts[0].contextKey, "plan:plan-owner:owner");
  assert.equal(contexts[0].role, AvailableContextRole.OWNER);
  assert.equal(contexts[0].weddingPlanId, "plan-owner");
  assert.equal(contexts[0].providerId, null);
  assert.equal(contexts[0].persona, WeddingPersona.GROOM);
  assert.equal(contexts[0].permissions.canManageMoney, true);
  assert.equal(contexts[0].permissions.canManageProviderProfile, false);
});

test("contributor-only account exposes current stored permissions", async () => {
  const { prisma, service } = contextsHarness();
  const sharedPlan = plan("plan-shared", "owner-2", "Shared wedding");
  prisma.memberships.push(
    membership(sharedPlan, {
      role: SharedMemberRole.FINANCE_MANAGER,
      canViewMoney: true,
      canManageMoney: true,
      canManageProviders: true,
    }),
  );

  const [context] = await service.list(currentUser);

  assert.equal(context.contextKey, "plan:plan-shared:contributor");
  assert.equal(context.role, AvailableContextRole.CONTRIBUTOR);
  assert.equal(context.membershipId, "member-plan-shared");
  assert.equal(context.membershipAuthorityVersion, 1);
  assert.equal(context.permissions.canViewMoney, true);
  assert.equal(context.permissions.canManageMoney, true);
  assert.equal(context.permissions.canManageProviders, true);
  assert.equal(context.permissions.canEditPlan, false);
});

test("FULL plan access mode never elevates stored contributor permissions", async () => {
  const { prisma, service } = contextsHarness();
  prisma.memberships.push(
    membership(plan("plan-viewer", "owner-2", "Viewer plan")),
  );

  const [context] = (await service.list(currentUser)) as Array<any>;

  assert.equal(context.lifecycle, WeddingPlanStatus.PLANNING);
  assert.equal(context.accessMode, "FULL");
  assert.equal(context.permissions.canViewPlan, true);
  assert.equal(context.permissions.canEditPlan, false);
  assert.equal(context.permissions.canManageTasks, false);
  assert.equal(context.permissions.canManageGuests, false);
  assert.equal(context.permissions.canManageProviders, false);
  assert.equal(context.permissions.canInviteMembers, false);
  assert.equal(context.permissions.canManageMoney, false);
});

test("provider-only account is derived from Provider.userId, not appRole", async () => {
  const { prisma, service } = contextsHarness();
  prisma.providers.push(provider("provider-1"));

  const contexts = await service.list({
    ...currentUser,
    role: "USER",
    appRole: "WEDDING_USER",
  });

  assert.deepEqual(contexts.map((item) => item.contextKey), [
    "provider:provider-1",
  ]);
  assert.equal(contexts[0].role, AvailableContextRole.PROVIDER);
  assert.equal(contexts[0].persona, null);
  assert.equal(contexts[0].permissions.canManageProviderProfile, true);
  assert.equal(contexts[0].permissions.canViewPlan, false);
});

test("owner and contributor contexts coexist for different plans", async () => {
  const { prisma, service } = contextsHarness();
  prisma.plans.push(plan("plan-owned", currentUser.id, "Owned"));
  prisma.memberships.push(
    membership(plan("plan-member", "owner-2", "Contributed")),
  );

  const contexts = await service.list(currentUser);

  assert.deepEqual(
    new Set(contexts.map((item) => item.role)),
    new Set([AvailableContextRole.OWNER, AvailableContextRole.CONTRIBUTOR]),
  );
});

test("owner and provider contexts coexist for one account", async () => {
  const { prisma, service } = contextsHarness();
  prisma.plans.push(plan("plan-owned", currentUser.id, "Owned"));
  prisma.providers.push(provider("provider-1"));

  const contexts = await service.list(currentUser);

  assert.deepEqual(contexts.map((item) => item.contextKey), [
    "plan:plan-owned:owner",
    "provider:provider-1",
  ]);
});

test("one account can expose owner, contributor, and provider contexts", async () => {
  const { prisma, service } = contextsHarness();
  prisma.plans.push(plan("plan-owned", currentUser.id, "Owned"));
  prisma.memberships.push(
    membership(plan("plan-member", "owner-2", "Contributed")),
  );
  prisma.providers.push(provider("provider-1"));

  const contexts = await service.list(currentUser);

  assert.deepEqual(contexts.map((item) => item.role), [
    AvailableContextRole.OWNER,
    AvailableContextRole.CONTRIBUTOR,
    AvailableContextRole.PROVIDER,
  ]);
});

test("owner, contributor, and provider contexts expose additive lifecycle-aware fields", async () => {
  const { prisma, service } = contextsHarness();
  prisma.plans.push(plan("plan-owned", currentUser.id, "Owned"));
  prisma.memberships.push(
    membership(plan("plan-member", "owner-2", "Contributed")),
  );
  prisma.providers.push(
    provider("provider-1", currentUser.id, ProviderStatus.ACTIVE),
  );

  const contexts = (await service.list(currentUser)) as Array<any>;

  assert.deepEqual(
    contexts.map(
      ({ contextKey, persona, lifecycle, accessMode, capabilities }) => ({
      contextKey,
      persona,
      lifecycle,
      accessMode,
      capabilities,
      }),
    ),
    [
      {
        contextKey: "plan:plan-owned:owner",
        persona: null,
        lifecycle: WeddingPlanStatus.PLANNING,
        accessMode: "FULL",
        capabilities: {
          canViewProviderProfile: false,
          canManageProviderProfile: false,
          canUseProviderOperations: false,
        },
      },
      {
        contextKey: "plan:plan-member:contributor",
        persona: null,
        lifecycle: WeddingPlanStatus.PLANNING,
        accessMode: "FULL",
        capabilities: {
          canViewProviderProfile: false,
          canManageProviderProfile: false,
          canUseProviderOperations: false,
        },
      },
      {
        contextKey: "provider:provider-1",
        persona: null,
        lifecycle: ProviderStatus.ACTIVE,
        accessMode: "FULL",
        capabilities: {
          canViewProviderProfile: true,
          canManageProviderProfile: true,
          canUseProviderOperations: true,
        },
      },
    ],
  );
});

test("every provider lifecycle reports truthful profile and operation capabilities", async () => {
  const expectations: Record<
    ProviderStatus,
    {
      accessMode: "FULL" | "LIMITED" | "READ_ONLY";
      canManageProviderProfile: boolean;
      canUseProviderOperations: boolean;
    }
  > = {
    [ProviderStatus.ACTIVE]: {
      accessMode: "FULL",
      canManageProviderProfile: true,
      canUseProviderOperations: true,
    },
    [ProviderStatus.PENDING]: {
      accessMode: "LIMITED",
      canManageProviderProfile: true,
      canUseProviderOperations: false,
    },
    [ProviderStatus.NEEDS_CHANGES]: {
      accessMode: "LIMITED",
      canManageProviderProfile: true,
      canUseProviderOperations: false,
    },
    [ProviderStatus.SUSPENDED]: {
      accessMode: "READ_ONLY",
      canManageProviderProfile: false,
      canUseProviderOperations: false,
    },
    [ProviderStatus.REJECTED]: {
      accessMode: "READ_ONLY",
      canManageProviderProfile: false,
      canUseProviderOperations: false,
    },
  };

  for (const status of Object.values(ProviderStatus)) {
    const { prisma, service } = contextsHarness();
    prisma.providers.push(provider(`provider-${status}`, currentUser.id, status));

    const [listed] = (await service.list(currentUser)) as Array<any>;
    const validated = (await service.validate(
      currentUser,
      listed.contextKey,
    )) as any;

    for (const context of [listed, validated]) {
      assert.equal(context.lifecycle, status);
      assert.equal(context.accessMode, expectations[status].accessMode);
      assert.deepEqual(context.capabilities, {
        canViewProviderProfile: true,
        canManageProviderProfile:
          expectations[status].canManageProviderProfile,
        canUseProviderOperations:
          expectations[status].canUseProviderOperations,
      });
      assert.equal(context.isAvailable, true);
      assert.equal(
        context.permissions.canManageProviderProfile,
        expectations[status].canManageProviderProfile,
      );
    }
  }
});

test("multiple contributor plans produce distinct canonical contexts", async () => {
  const { prisma, service } = contextsHarness();
  prisma.memberships.push(
    membership(plan("plan-a", "owner-a", "A")),
    membership(plan("plan-b", "owner-b", "B")),
  );

  const contexts = await service.list(currentUser);

  assert.deepEqual(
    new Set(contexts.map((item) => item.contextKey)),
    new Set(["plan:plan-a:contributor", "plan:plan-b:contributor"]),
  );
});

test("multiple owned plans produce distinct canonical contexts", async () => {
  const { prisma, service } = contextsHarness();
  prisma.plans.push(
    plan("plan-a", currentUser.id, "A"),
    plan("plan-b", currentUser.id, "B"),
  );

  const contexts = await service.list(currentUser);

  assert.deepEqual(
    new Set(contexts.map((item) => item.contextKey)),
    new Set(["plan:plan-a:owner", "plan:plan-b:owner"]),
  );
});

test("an accidental membership on an owned plan does not duplicate it", async () => {
  const { prisma, service } = contextsHarness();
  const owned = plan("plan-owned", currentUser.id, "Owned");
  prisma.plans.push(owned);
  prisma.memberships.push(membership(owned));

  const contexts = await service.list(currentUser);

  assert.deepEqual(contexts.map((item) => item.contextKey), [
    "plan:plan-owned:owner",
  ]);
});

test("validation returns server-owned context fields for every key type", async () => {
  const { prisma, service } = contextsHarness();
  const owned = plan("plan-owned", currentUser.id, "Trusted owned title");
  const shared = plan("plan-shared", "owner-2", "Trusted shared title");
  prisma.plans.push(owned);
  prisma.memberships.push(
    membership(shared, { canViewMoney: true, canManageProviders: true }),
  );
  prisma.providers.push(provider("provider-1"));

  const ownerContext = await service.validate(
    currentUser,
    "plan:plan-owned:owner",
  );
  const contributorContext = await service.validate(
    currentUser,
    "plan:plan-shared:contributor",
  );
  const providerContext = await service.validate(
    currentUser,
    "provider:provider-1",
  );

  assert.equal(ownerContext.displayName, "Trusted owned title");
  assert.equal(contributorContext.displayName, "Trusted shared title");
  assert.equal(contributorContext.permissions.canManageProviders, true);
  assert.equal(providerContext.displayName, "Provider provider-1");
});

test("validation rejects malformed, inaccessible plan, and foreign provider keys", async () => {
  const { prisma, service } = contextsHarness();
  prisma.plans.push(plan("plan-foreign", "owner-2", "Foreign"));
  prisma.providers.push(provider("provider-foreign", "user-2"));

  await assert.rejects(
    service.validate(currentUser, " plan:plan-foreign:owner"),
    BadRequestException,
  );
  await assert.rejects(
    service.validate(currentUser, "plan:plan-foreign:owner"),
    NotFoundException,
  );
  await assert.rejects(
    service.validate(currentUser, "provider:provider-foreign"),
    NotFoundException,
  );
});

test("removing a membership makes the same context key invalid immediately", async () => {
  const { prisma, service } = contextsHarness();
  const shared = plan("plan-shared", "owner-2", "Shared");
  prisma.memberships.push(membership(shared));

  assert.equal(
    (
      await service.validate(
        currentUser,
        "plan:plan-shared:contributor",
      )
    ).weddingPlanId,
    "plan-shared",
  );

  prisma.memberships.length = 0;

  await assert.rejects(
    service.validate(currentUser, "plan:plan-shared:contributor"),
    NotFoundException,
  );
});

test("archived plans stay discoverable but cannot validate as active contexts", async () => {
  const { prisma, service } = contextsHarness();
  prisma.plans.push(
    plan("plan-archived", currentUser.id, "Archived", {
      status: WeddingPlanStatus.ARCHIVED,
    }),
  );

  const [context] = (await service.list(currentUser)) as Array<any>;

  assert.equal(context.lifecycle, WeddingPlanStatus.ARCHIVED);
  assert.equal(context.accessMode, "READ_ONLY");
  assert.equal(context.isAvailable, false);
  assert.equal(context.unavailableReason, "PLAN_ARCHIVED");
  assert.equal(context.permissions.canEditPlan, false);
  assert.equal(context.permissions.canManageTasks, false);
  assert.equal(context.permissions.canManageMoney, false);
  await assert.rejects(
    service.validate(currentUser, "plan:plan-archived:owner"),
    ConflictException,
  );
});

test("findActive returns null when the stored plan no longer exists", async () => {
  let planQueries = 0;
  const prisma = {
    user: {
      findUnique: async () => ({ activeWeddingPlanId: "plan-missing" }),
    },
    weddingPlan: {
      findFirst: async () => {
        planQueries += 1;
        return null;
      },
    },
  };
  const service = new WeddingPlansService(
    prisma as any,
    {} as any,
    {} as any,
  );

  const active = await service.findActive(currentUser);

  assert.equal(active, null);
  assert.equal(planQueries, 1);
});

test("findActive never chooses another available plan after access loss", async () => {
  let planQueries = 0;
  const otherPlan = plan("plan-other", currentUser.id, "Other plan");
  const prisma = {
    user: {
      findUnique: async () => ({ activeWeddingPlanId: "plan-revoked" }),
    },
    weddingPlan: {
      findFirst: async () => {
        planQueries += 1;
        return planQueries === 1 ? null : otherPlan;
      },
    },
  };
  const permissions = {
    assertPlanReadable: async () => ({
      plan: otherPlan,
      isOwner: true,
      sharedMember: null,
    }),
    canViewMoney: () => true,
  };
  const service = new WeddingPlansService(
    prisma as any,
    permissions as any,
    {} as any,
  );

  const active = await service.findActive(currentUser);

  assert.equal(active, null);
  assert.equal(planQueries, 1);
});

test("public profile validation rejects appRole while preserving persona updates", async () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });
  const metadata = {
    type: "body" as const,
    metatype: ValidateContextDto,
    data: "",
  };

  await assert.rejects(
    pipe.transform(
      { contextKey: "provider:provider-1", appRole: "PROVIDER" },
      metadata,
    ),
    BadRequestException,
  );

  const profileMetadata = {
    type: "body" as const,
    metatype: UpdateProfileDto,
    data: "",
  };
  await assert.rejects(
    pipe.transform({ appRole: "PROVIDER" }, profileMetadata),
    BadRequestException,
  );
  const profile = await pipe.transform(
    { persona: WeddingPersona.BRIDE },
    profileMetadata,
  );
  assert.equal((profile as { persona: WeddingPersona }).persona, "BRIDE");
});

test("contexts routes are canonical, authenticated, and module-wired", () => {
  const root = join(__dirname, "..");
  const controller = readFileSync(
    join(root, "src/contexts/contexts.controller.ts"),
    "utf8",
  );
  const appModule = readFileSync(join(root, "src/app.module.ts"), "utf8");

  assert.match(controller, /@Controller\("api\/v1\/contexts"\)/);
  assert.match(controller, /@UseGuards\(JwtAuthGuard\)/);
  assert.match(controller, /@Get\(\)/);
  assert.match(controller, /@Post\("validate"\)/);
  assert.match(appModule, /ContextsModule/);
});
