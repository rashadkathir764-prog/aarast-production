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
  const mediaCalls: unknown[] = [];
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
    {
      verifyPublicMediaUrl: async (_user: unknown, value: string | null) => value,
      consumePublicMediaUrl: async (...args: unknown[]) => {
        mediaCalls.push(["consume", args[1], args[3]]);
      },
      scheduleTargetDeletion: async (target: unknown) => {
        mediaCalls.push(["delete", target]);
      },
    } as any,
  );
  // D83: the plan's lunch, which this guest is invited to as well.
  const lunch = await prisma.planEvent.create({
    data: {
      weddingPlanId: plan.id,
      type: "LUNCH",
      date: new Date("2027-02-18T00:00:00Z"),
      timeSlot: "DHUHR",
      placeLabel: "بيت العريس",
    },
  });
  await prisma.guestEventInvite.create({
    data: { guestId: guest.id, planEventId: lunch.id },
  });

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

    // D83: the lunch is answered on its own; the wedding reply stays.
    assert.deepEqual(
      view.events.map((event) => [event.label, event.attendanceStatus]),
      [["الغداء", "PENDING"]],
    );
    const lunchAnswered = await rsvp.respond(firstToken, "DECLINED", 0, lunch.id);
    assert.equal(lunchAnswered.events[0].attendanceStatus, "DECLINED");
    assert.equal(lunchAnswered.attendanceStatus, "CONFIRMED");
    const inviteRow = await prisma.guestEventInvite.findUniqueOrThrow({
      where: { guestId_planEventId: { guestId: guest.id, planEventId: lunch.id } },
    });
    assert.equal(inviteRow.attendanceStatus, "DECLINED");
    assert.ok(inviteRow.respondedAt);
    assert.match(notifications[notifications.length - 1]?.title?.masculine ?? "", /الغداء/);
    await assert.rejects(
      rsvp.respond(firstToken, "CONFIRMED", 0, "not-an-event"),
      (error: any) => error?.response?.code === "RSVP_EVENT_NOT_INVITED",
    );
    console.log("PASS - an event beyond the wedding is answered on its own");

    // D83: the card is one row per plan; the message and the page carry it.
    const card = await rsvp.setInvitationCard(owner as any, plan.id, {
      hostLine: "عبدالرحمن الحمدي",
      freeText: "يا مرحبا بالحاضرين",
      mapUrl: "https://maps.app.goo.gl/smoke",
      photoUrl: "https://media.example/guest-invitation-card/owner/a.jpg",
    });
    assert.equal(card.hostLine, "عبدالرحمن الحمدي");
    assert.deepEqual(mediaCalls, [
      ["consume", "https://media.example/guest-invitation-card/owner/a.jpg", { type: "GUEST_INVITATION_CARD", id: (await prisma.guestInvitationCard.findUniqueOrThrow({ where: { weddingPlanId: plan.id } })).id }],
    ]);
    const kept = await rsvp.setInvitationCard(owner as any, plan.id, { address: "شارع تعز" });
    assert.equal(kept.hostLine, "عبدالرحمن الحمدي");
    assert.equal(kept.address, "شارع تعز");
    assert.equal(await prisma.guestInvitationCard.count({ where: { weddingPlanId: plan.id } }), 1);
    const pageView = await rsvp.getInvitation(firstToken);
    assert.equal(pageView.card?.mapUrl, "https://maps.app.goo.gl/smoke");
    assert.equal(pageView.card?.photoUrl, "https://media.example/guest-invitation-card/owner/a.jpg");
    console.log("PASS - the plan's card is saved once and read by the guest");

    const second = await rsvp.createInvitationLink(owner as any, guest.id);
    assert.match(second.message, /يتشرف عبدالرحمن الحمدي بدعوتكم/);
    assert.match(second.message, /الغداء/);
    assert.match(second.message, /maps\.app\.goo\.gl\/smoke/);
    const reminder = await rsvp.createInvitationLink(owner as any, guest.id, { reminder: true });
    assert.match(reminder.message, /نذكرك ب/);
    console.log("PASS - the WhatsApp text is built by the server from the card and the events");
    await assert.rejects(rsvp.getInvitation(firstToken), /not valid/);
    assert.equal(
      (await rsvp.getInvitation(reminder.url.split("/rsvp/")[1])).attendanceStatus,
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
    await prisma.guestInvitationCard.deleteMany({ where: { weddingPlanId: plan.id } });
    await prisma.planEvent.deleteMany({ where: { weddingPlanId: plan.id } });
    await prisma.weddingPlan.deleteMany({ where: { id: plan.id } });
    await prisma.user.deleteMany({ where: { id: owner.id } });
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
