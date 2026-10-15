import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { GuestRsvpService } from "../../src/guests/guest-rsvp.service";
import { ContributorScopeService } from "../../src/modules/collaboration/internal/contributor-scope.service";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { contributionHistoryService, ownerPorts } from "./support/owner-ports";

// Guest invitation links and RSVP (V1 checklist 4.7) on a real database: the
// owner issues a personal link, the guest reads and answers it without an
// account, the guest list updates, and a new link retires the old one.

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const label = `RSVP smoke ${runId}`;

async function main(): Promise<void> {
  const owner = await prisma.user.create({
    data: {
      name: `${label} owner`,
      passwordHash: createHash("sha256").update(`${runId}:owner`).digest("hex"),
    },
  });
  const plan = await prisma.weddingPlan.create({
    data: {
      ownerUserId: owner.id,
      title: "عرس أحمد",
      weddingDate: new Date("2027-02-18T00:00:00Z"),
      location: { governorate: "أمانة العاصمة", cityOrDistrict: "شعوب" },
    },
  });
  const guest = await prisma.guest.create({
    data: {
      weddingPlanId: plan.id,
      name: "عمي صالح",
      normalizedName: "عمي صالح",
    },
  });

  const notifications: any[] = [];
  const permissions = new PermissionService(prisma as any, ownerPorts.plans);
  const scope = new ContributorScopeService(
    contributionHistoryService(prisma, permissions),
  );
  const rsvp = new GuestRsvpService(
    prisma as any,
    permissions,
    scope,
    ownerPorts.plans,
    {
      createNotificationInTransaction: async (_tx: unknown, input: any) => {
        notifications.push(input);
        return null;
      },
    } as any,
  );

  try {
    const first = await rsvp.createInvitationLink(owner as any, guest.id);
    const firstToken = first.url.split("/rsvp/")[1];
    assert.match(firstToken, /^[A-Za-z0-9_-]{43}$/);
    let row = await prisma.guest.findUniqueOrThrow({ where: { id: guest.id } });
    assert.equal(row.invitationStatus, "SENT");
    assert.notEqual(row.rsvpTokenHash, null);
    assert.notEqual(row.rsvpTokenHash, firstToken);
    console.log("PASS - the owner issues a personal link; only its hash is stored");

    const view = await rsvp.getInvitation(firstToken);
    assert.equal(view.guestName, "عمي صالح");
    assert.equal(view.planTitle, "عرس أحمد");
    assert.equal(view.weddingDate, "2027-02-18");
    console.log("PASS - the guest reads the invitation without an account");

    const answered = await rsvp.respond(firstToken, "CONFIRMED", 3);
    assert.equal(answered.attendanceStatus, "CONFIRMED");
    row = await prisma.guest.findUniqueOrThrow({ where: { id: guest.id } });
    assert.equal(row.attendanceStatus, "CONFIRMED");
    assert.equal(row.status, "CONFIRMED");
    assert.equal(row.companionsCount, 3);
    assert.ok(row.respondedAt);
    assert.equal(notifications[notifications.length - 1]?.userId, owner.id);
    console.log("PASS - the answer updates the guest list and tells the owner");

    const second = await rsvp.createInvitationLink(owner as any, guest.id);
    await assert.rejects(rsvp.getInvitation(firstToken), /not valid/);
    assert.equal(
      (await rsvp.getInvitation(second.url.split("/rsvp/")[1])).attendanceStatus,
      "CONFIRMED",
    );
    console.log("PASS - a new link retires the old one and keeps the answer");

    await prisma.weddingPlan.update({
      where: { id: plan.id },
      data: { status: "ARCHIVED" },
    });
    await assert.rejects(
      rsvp.getInvitation(second.url.split("/rsvp/")[1]),
      /not valid/,
    );
    console.log("PASS - an archived plan closes its links");
  } finally {
    await prisma.guest.deleteMany({ where: { weddingPlanId: plan.id } });
    await prisma.weddingPlan.deleteMany({ where: { id: plan.id } });
    await prisma.user.deleteMany({ where: { id: owner.id } });
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
