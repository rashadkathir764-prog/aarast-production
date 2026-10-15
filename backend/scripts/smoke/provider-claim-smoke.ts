import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  AdminRole,
  PrismaClient,
  ProviderStatus,
  UserRole,
  UserStatus,
} from "@prisma/client";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { OutboxService } from "../../src/platform/outbox/outbox.service";
import {
  adminService,
  notificationsService,
  ownerPorts,
  providerDashboardService,
} from "./support/owner-ports";

// A provider the back office lists before its owner has an account, then
// claimed by the account that signs in with the same phone (V1 checklist
// 4.18), on a real database.

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const label = `Provider claim ${runId}`;

/** A Yemeni mobile number unique to this run and role. */
function scopedPhone(role: string): string {
  const digits = createHash("sha256")
    .update(`${runId}:${role}`)
    .digest("hex")
    .split("")
    .map((character) => String(Number.parseInt(character, 16) % 10))
    .join("")
    .slice(0, 8);
  return `+9677${digits}`;
}

function code(error: any): string | undefined {
  return error?.response?.code;
}

async function main(): Promise<void> {
  const ownerPhone = scopedPhone("owner");
  const [admin, owner, stranger, city, category] = await Promise.all([
    prisma.user.create({
      data: {
        name: `${label} admin`,
        passwordHash: "managed-smoke-not-a-credential",
        role: UserRole.ADMIN,
        adminRole: AdminRole.OPERATIONS,
        status: UserStatus.ACTIVE,
      },
    }),
    prisma.user.create({
      data: {
        name: `${label} owner`,
        phone: ownerPhone,
        phoneVerifiedAt: new Date(),
        passwordHash: "managed-smoke-not-a-credential",
        role: UserRole.USER,
        status: UserStatus.ACTIVE,
      },
    }),
    prisma.user.create({
      data: {
        name: `${label} stranger`,
        phone: scopedPhone("stranger"),
        phoneVerifiedAt: new Date(),
        passwordHash: "managed-smoke-not-a-credential",
        role: UserRole.USER,
        status: UserStatus.ACTIVE,
      },
    }),
    prisma.city.create({ data: { nameAr: `${label} city`, countryCode: "YE" } }),
    prisma.providerCategory.create({
      data: { nameAr: `${label} category`, slug: `claim-${runId}`.replace(/_/g, "-") },
    }),
  ]);

  const notifications = notificationsService(
    prisma,
    new PermissionService(prisma as any, ownerPorts.plans),
    new OutboxService(),
  );
  const admins = adminService(prisma, { revokeConversationAccess: () => {} }, notifications);
  const dashboard = providerDashboardService(prisma, notifications, {}, {});
  const adminActor = { ...admin, adminMfa: true, sessionScope: "admin" } as any;
  const asUser = (user: typeof owner) => ({ ...user, sessionScope: "application" }) as any;
  let listingId: string | null = null;

  try {
    // The admin writes the number the way people type it locally.
    const listed = await admins.createListedProvider(adminActor, {
      businessName: `${label} الفنان`,
      phone: `0${ownerPhone.slice(4)}`,
      cityId: city.id,
      categoryId: category.id,
    });
    listingId = listed.id;
    const row = await prisma.provider.findUniqueOrThrow({ where: { id: listed.id } });
    assert.equal(row.status, ProviderStatus.ACTIVE);
    assert.equal(row.userId, null);
    assert.equal(row.phone, ownerPhone);
    console.log("PASS - the admin lists a provider without an account, active at once");

    await assert.rejects(
      admins.createListedProvider(adminActor, {
        businessName: `${label} مكرر`,
        phone: ownerPhone,
        cityId: city.id,
        categoryId: category.id,
      }),
      (error: any) => code(error) === "PROVIDER_PHONE_TAKEN",
    );
    console.log("PASS - a second listing with the same phone is refused");

    assert.deepEqual(await dashboard.findClaimableListing(asUser(stranger)), { listing: null });
    await assert.rejects(dashboard.claimListing(asUser(stranger), listed.id), /not found/i);
    console.log("PASS - another account neither sees nor claims the listing");

    const offered = await dashboard.findClaimableListing(asUser(owner));
    assert.equal(offered.listing?.id, listed.id);
    await assert.rejects(
      dashboard.apply(asUser(owner), {
        businessName: "طلب جديد",
        phone: ownerPhone,
        cityId: city.id,
        categoryIds: [category.id],
      } as any),
      (error: any) => code(error) === "PROVIDER_LISTING_CLAIMABLE",
    );
    console.log("PASS - the phone's owner is offered the listing and cannot apply twice");

    const claimed = await dashboard.claimListing(asUser(owner), listed.id);
    assert.equal(claimed.userId, owner.id);
    const promoted = await prisma.user.findUniqueOrThrow({ where: { id: owner.id } });
    assert.equal(promoted.role, UserRole.PROVIDER);
    assert.deepEqual(await dashboard.findClaimableListing(asUser(owner)), { listing: null });
    await assert.rejects(dashboard.claimListing(asUser(owner), listed.id), /already exists/i);
    console.log("PASS - claiming makes the account the listing's provider, once");
  } finally {
    if (listingId) await prisma.provider.deleteMany({ where: { id: listingId } });
    await prisma.providerCategory.deleteMany({ where: { id: category.id } });
    await prisma.city.deleteMany({ where: { id: city.id } });
    await prisma.user.deleteMany({
      where: { id: { in: [admin.id, owner.id, stranger.id] } },
    });
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
