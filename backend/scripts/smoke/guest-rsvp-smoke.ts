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

const { assertManagedSmokeEnvironment, futureDay } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
  futureDay: (daysFromNow: number, now?: Date) => string;
};

assertManagedSmokeEnvironment(process.env);

// The wedding day is counted from the run's start, so the plan, its lunch and
// the assertion agree on the same day.
const weddingDay = futureDay(60, new Date());
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
      weddingDate: new Date(`${weddingDay}T00:00:00Z`),
      location: { governorate: "أمانة العاصمة", cityOrDistrict: "شعوب" },
    },
  });
  const guest = await prisma.guest.create({
    data: {
      weddingPlanId: plan.id,
      name: "عمي صالح",
      normalizedName: "عمي صالح",
      // Q-43 (أ): the owner sets the seats; four seats let him bring three.
      seatsCount: 4,
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
      // 6a: the private photo is read through a short signed link.
      createStoredMediaDownloadUrl: async (value: string) => ({
        downloadUrl: `https://signed.example/${encodeURIComponent(value)}`,
        expiresInSeconds: 120,
        expiresAt: new Date(Date.now() + 120_000),
      }),
    } as any,
  );
  // D83: the plan's lunch, which this guest is invited to as well.
  const lunch = await prisma.planEvent.create({
    data: {
      weddingPlanId: plan.id,
      type: "LUNCH",
      date: new Date(`${weddingDay}T00:00:00Z`),
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
    // D116: preparing is not sending; the person says it was sent.
    assert.equal(row.invitationStatus, "NOT_SENT");
    assert.notEqual(row.rsvpLinkHash, null);
    assert.notEqual(row.rsvpLinkHash, firstToken);
    const settled = await rsvp.settleInvitationSend(owner as any, first.sendId, { sent: true });
    assert.equal(settled.status, "SENT");
    row = await prisma.guest.findUniqueOrThrow({ where: { id: guest.id } });
    assert.equal(row.invitationStatus, "SENT");
    console.log("PASS - the owner prepares the guest's link; only its hash is kept; it counts once said sent");

    const view = await rsvp.getInvitation(firstToken);
    assert.equal(view.guestName, "عمي صالح");
    assert.equal(view.planTitle, "عرس أحمد");
    assert.equal(view.weddingDate, weddingDay);
    console.log("PASS - the guest reads the invitation without an account");

    await assert.rejects(
      rsvp.respond(firstToken, "CONFIRMED", 4),
      (error: any) => error?.response?.code === "RSVP_INVALID_COMPANIONS",
    );
    console.log("PASS - a guest brings no more companions than the seats the owner set (Q-43)");
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
    // 6a: the page reads the photo through the link, never the bucket address.
    assert.ok(pageView.card?.photoUrl?.endsWith(`/api/v1/public/rsvp/${firstToken}/card-photo`));
    assert.equal(
      await rsvp.cardPhotoDownloadUrl(firstToken),
      `https://signed.example/${encodeURIComponent("https://media.example/guest-invitation-card/owner/a.jpg")}`,
    );
    assert.match(card.photoReadUrl ?? "", /^https:\/\/signed\.example\//);
    assert.equal((await rsvp.invitationPreview(firstToken))?.title, "يتشرف عبدالرحمن الحمدي بدعوتكم لحضور " + plan.title);
    console.log("PASS - the plan's card is saved once and read by the guest");

    // D116: the wedding's map link is new since the guest confirmed: the
    // wedding row's version rose, and what the guest is due is the change.
    const due = await rsvp.createInvitationLink(owner as any, guest.id);
    assert.equal(due.kind, "CHANGE");
    assert.match(due.message, /تغيّر موعد أو مكان العرس/);
    console.log("PASS - a new map link for the wedding is told to the guest who confirmed before it");
    const second = await rsvp.createInvitationLink(owner as any, guest.id, {
      kind: "INVITATION",
    });
    assert.match(second.message, /يتشرف عبدالرحمن الحمدي بدعوتكم/);
    assert.match(second.message, /الغداء/);
    assert.match(second.message, /maps\.app\.goo\.gl\/smoke/);
    // 6b: the guest's link is the first link, so WhatsApp previews it.
    assert.equal(second.message.match(/https:\/\/\S+/)?.[0], second.url);
    const reminder = await rsvp.createInvitationLink(owner as any, guest.id, { reminder: true });
    assert.match(reminder.message, /نذكرك ب/);
    console.log("PASS - the WhatsApp text is built by the server from the card and the events");
    // D116: the link is the same on every send; replacing it retires it.
    assert.equal(reminder.url, first.url);
    assert.equal((await rsvp.getInvitation(firstToken)).attendanceStatus, "CONFIRMED");
    const replaced = await rsvp.replaceInvitationLink(owner as any, guest.id);
    await assert.rejects(rsvp.getInvitation(firstToken), /not valid/);
    assert.equal(
      (await rsvp.getInvitation(replaced.url.split("/rsvp/")[1])).attendanceStatus,
      "CONFIRMED",
    );
    console.log("PASS - the guest keeps one link; a replaced one retires and the answer stays");

    await prisma.weddingPlan.update({
      where: { id: plan.id },
      data: { status: "ARCHIVED" },
    });
    await assert.rejects(
      rsvp.getInvitation(replaced.url.split("/rsvp/")[1]),
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
