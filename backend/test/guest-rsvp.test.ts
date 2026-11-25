import "reflect-metadata";

import assert from "node:assert/strict";
import { mock, test } from "node:test";
import { HEADERS_METADATA } from "@nestjs/common/constants";
import {
  buildRsvpMessage,
  GuestRsvpService,
  rsvpLinkToken,
  rsvpPublicOrigin,
  rsvpTokenHash,
  RSVP_MESSAGE_SOFT_LIMIT,
} from "../src/guests/guest-rsvp.service";
import { assertWeddingPlanWritable } from "../src/modules/collaboration/public/collaboration-permission.port";
import { PublicRsvpController } from "../src/guests/guest-rsvp.controller";
import { renderRsvpPreviewHead } from "../src/guests/rsvp-preview";

// Personal invitation links and RSVP (V1 checklist 4.7), and D116: one
// stable link per guest, a record of every send and the occasions it named,
// sent only when the person says so, and each occasion's own place and
// version.

const owner = { id: "owner-1" } as any;
const member = { id: "member-1" } as any;

// D83: the plan's events, as planning lists them; the wedding row among
// them. D116: each with its own map link, address and version.
function planEventRows() {
  return [
    {
      id: "event-wedding",
      weddingPlanId: "plan-1",
      type: "WEDDING",
      title: null,
      date: null,
      timeSlot: "AFTER_ISHA",
      exactTime: null,
      placeLabel: "قاعة سبأ",
      mapUrl: null as string | null,
      address: null as string | null,
      version: 1,
    },
    {
      id: "event-lunch",
      weddingPlanId: "plan-1",
      type: "LUNCH",
      title: null,
      date: new Date("2027-02-18T00:00:00Z"),
      timeSlot: "DHUHR",
      exactTime: null,
      placeLabel: "بيت العريس",
      mapUrl: "https://maps.app.goo.gl/lunch" as string | null,
      address: null as string | null,
      version: 1,
    },
    {
      id: "event-aqd",
      weddingPlanId: "plan-1",
      type: "AQD",
      title: "عقد القران",
      date: new Date("2027-02-11T00:00:00Z"),
      timeSlot: null,
      exactTime: "20:30",
      placeLabel: null,
      mapUrl: null as string | null,
      address: null as string | null,
      version: 1,
    },
  ];
}

function fakeDatabase() {
  const guests = new Map<string, any>([
    [
      "guest-1",
      {
        id: "guest-1",
        weddingPlanId: "plan-1",
        name: "عمي صالح",
        normalizedPhone: "+967777000111",
        invitationStatus: "NOT_SENT",
        attendanceStatus: "PENDING",
        status: "INVITED",
        // RA-BE-173 (Q-43): the owner set four seats: the guest and three.
        seatsCount: 4,
        companionsCount: 0,
        respondedAt: null,
        rsvpTokenHash: null,
        rsvpLinkHash: null,
        rsvpLinkVersion: 0,
        linkOpenedAt: null,
        weddingAnsweredVersion: null,
      },
    ],
  ]);
  // D83: guest-1 is invited to the lunch as well; the wedding needs no row.
  const eventInvites: any[] = [
    {
      id: "invite-1",
      guestId: "guest-1",
      planEventId: "event-lunch",
      attendanceStatus: "PENDING",
      companionsCount: 0,
      respondedAt: null,
      answeredVersion: null,
    },
  ];
  const events = planEventRows();
  const cards = new Map<string, any>();
  const sends: any[] = [];
  const notifications: any[] = [];
  const matches = (row: any, where: any) =>
    Object.entries(where).every(([key, value]) =>
      value && typeof value === "object" && "in" in (value as object)
        ? (value as any).in.includes(row[key])
        : row[key] === value,
    );
  const tx: any = {
    $queryRaw: async (query: { values: unknown[] }) =>
      guests.has(query.values[0] as string) ? [{ id: query.values[0] }] : [],
    guest: {
      findUnique: async ({ where }: any) => guests.get(where.id) ?? null,
      // D116: a link opens by its stable hash or by the last random one.
      findFirst: async ({ where }: any) =>
        [...guests.values()].find((row) =>
          where.OR.some((condition: any) =>
            Object.entries(condition).every(([key, value]) => value && row[key] === value),
          ),
        ) ?? null,
      update: async ({ where, data }: any) => {
        const row = { ...guests.get(where.id), ...data };
        guests.set(where.id, row);
        return row;
      },
      // RA-BE-190: the guests of a plan who answered since an instant, by the
      // wedding or by any occasion.
      count: async ({ where }: any) => {
        const since = where.OR[0].respondedAt.gte as Date;
        return [...guests.values()].filter(
          (row) =>
            row.weddingPlanId === where.weddingPlanId &&
            ((row.respondedAt && row.respondedAt >= since) ||
              eventInvites.some(
                (invite) =>
                  invite.guestId === row.id && invite.respondedAt && invite.respondedAt >= since,
              )),
        ).length;
      },
      updateMany: async ({ where, data }: any) => {
        const row = guests.get(where.id);
        if (row && row.linkOpenedAt === where.linkOpenedAt) {
          guests.set(where.id, { ...row, ...data });
          return { count: 1 };
        }
        return { count: 0 };
      },
    },
    guestEventInvite: {
      findMany: async ({ where }: any) => eventInvites.filter((row) => matches(row, where)),
      findFirst: async ({ where }: any) => eventInvites.find((row) => matches(row, where)) ?? null,
      update: async ({ where, data }: any) => {
        const row = eventInvites.find(
          (candidate) =>
            candidate.guestId === where.guestId_planEventId.guestId &&
            candidate.planEventId === where.guestId_planEventId.planEventId,
        );
        Object.assign(row, data);
        return row;
      },
    },
    guestInvitationCard: {
      findUnique: async ({ where }: any) => cards.get(where.weddingPlanId) ?? null,
      upsert: async ({ where, create, update }: any) => {
        const current = cards.get(where.weddingPlanId);
        const row = current
          ? { ...current, ...update, updatedAt: new Date() }
          : { id: `card-${where.weddingPlanId}`, photoKind: "PHOTO", ...create, updatedAt: new Date() };
        cards.set(where.weddingPlanId, row);
        return row;
      },
    },
    guestInvitationSend: {
      create: async ({ data }: any) => {
        const row = {
          id: `send-${sends.length + 1}`,
          status: "PREPARED",
          settledAt: null,
          createdAt: new Date(Date.UTC(2026, 10, 16, 9, sends.length)),
          ...data,
        };
        sends.push(row);
        return row;
      },
      findUnique: async ({ where }: any) => sends.find((row) => row.id === where.id) ?? null,
      update: async ({ where, data }: any) => {
        const row = sends.find((candidate) => candidate.id === where.id);
        Object.assign(row, data);
        return row;
      },
      findMany: async ({ where }: any) =>
        sends.filter((row) => where.guestId.in.includes(row.guestId)),
    },
  };
  const prisma: any = {
    ...tx,
    $transaction: async (operation: (client: any) => Promise<unknown>) => operation(tx),
  };
  return {
    prisma,
    guests,
    eventInvites,
    events,
    cards,
    sends,
    notifications,
    media: [] as any[],
    signed: [] as any[],
  };
}

function service(
  db: ReturnType<typeof fakeDatabase>,
  options: {
    contributorOwns?: string[];
    planStatus?: string;
    deletionRequestedAt?: Date | null;
    persona?: string;
    signingFails?: boolean;
    weddingDate?: Date | null;
  } = {},
) {
  const context = (user: any) => ({
    isOwner: user.id === "owner-1",
    sharedMember: user.id === "owner-1" ? null : { userId: user.id },
  });
  const permissions: any = {
    // As the real ones: every member reads the plan; writing its guests
    // needs a plan that is not archived (PLAN_ARCHIVED_READ_ONLY).
    assertPlanReadableInTransaction: async (_tx: unknown, _plan: string, user: any) => context(user),
    assertGuestManageableInTransaction: async (_tx: unknown, _plan: string, user: any) => {
      assertWeddingPlanWritable({ status: (options.planStatus ?? "PLANNING") as any });
      return context(user);
    },
  };
  const scope: any = {
    qualifyingEntityIdsInTransaction: async () => options.contributorOwns ?? [],
  };
  const plans: any = {
    getPlan: async () => ({
      id: "plan-1",
      ownerUserId: "owner-1",
      title: "عرس أحمد",
      persona: options.persona ?? "GROOM",
      status: options.planStatus ?? "PLANNING",
      deletionRequestedAt: options.deletionRequestedAt ?? null,
      weddingDate:
        options.weddingDate === undefined ? new Date("2027-02-18T00:00:00Z") : options.weddingDate,
      city: null,
      location: { governorate: "أمانة العاصمة", cityOrDistrict: "شعوب" },
    }),
    listPlanEvents: async () => db.events.map((event) => ({ ...event })),
    // D116: the wedding's map link and address are its row's.
    setWeddingEventPlace: async (_tx: unknown, _plan: string, place: any) => {
      const wedding = db.events.find((event) => event.type === "WEDDING")!;
      if (place.mapUrl !== undefined && place.mapUrl !== wedding.mapUrl) wedding.version += 1;
      if (place.mapUrl !== undefined) wedding.mapUrl = place.mapUrl;
      if (place.address !== undefined) wedding.address = place.address;
    },
  };
  const notifications: any = {
    // As the real one: a merged notice replaces the one under its key.
    createNotificationInTransaction: async (_tx: unknown, input: any) => {
      const existing = input.mergeIntoExisting
        ? db.notifications.findIndex((notice: any) => notice.dedupeKey === input.dedupeKey)
        : -1;
      if (existing >= 0) db.notifications[existing] = input;
      else db.notifications.push(input);
      return null;
    },
  };
  const media: any = {
    verifyPublicMediaUrl: async (_user: unknown, value: string | null | undefined) => {
      db.media.push(["verify", value]);
      return value?.trim() || null;
    },
    consumePublicMediaUrl: async (_user: unknown, value: string, purpose: string, target: unknown) => {
      db.media.push(["consume", value, purpose, target]);
    },
    scheduleTargetDeletion: async (target: unknown) => {
      db.media.push(["delete", target]);
    },
    // 6a: the bucket keeps the card photo private; a read is a short-lived
    // signed link of the saved address.
    createStoredMediaDownloadUrl: async (value: string, purpose: string) => {
      if (options.signingFails) throw new Error("the photo cannot be signed");
      db.signed.push([value, purpose]);
      return {
        downloadUrl: `https://signed.example/${encodeURIComponent(value)}?X-Amz-Expires=120`,
        expiresInSeconds: 120,
        expiresAt: new Date(Date.now() + 120_000),
      };
    },
  };
  return new GuestRsvpService(db.prisma, permissions, scope, plans, notifications, media);
}

function tokenOf(url: string): string {
  return url.split("/rsvp/")[1];
}

test("the owner gets the guest's link and a WhatsApp text; only the hash is kept, and nothing is sent yet", async () => {
  process.env.INVITE_PUBLIC_ORIGIN = "https://3-121-198-183.sslip.io";
  const db = fakeDatabase();
  const link = await service(db).createInvitationLink(owner, "guest-1");

  assert.match(link.url, /^https:\/\/3-121-198-183\.sslip\.io\/rsvp\/[A-Za-z0-9_-]{43}$/);
  assert.equal(link.phone, "+967777000111");
  assert.match(link.message, /عرس أحمد/);
  assert.match(link.message, /18\/2\/2027/);
  assert.ok(link.message.includes(link.url));
  const stored = db.guests.get("guest-1");
  assert.equal(stored.rsvpLinkHash, rsvpTokenHash(tokenOf(link.url)));
  assert.ok(!JSON.stringify(stored).includes(tokenOf(link.url)));
  // D116: preparing a send is not sending it.
  assert.equal(stored.invitationStatus, "NOT_SENT");
  assert.equal(link.kind, "INVITATION");
  assert.deepEqual(link.events, [
    { planEventId: "event-wedding", version: 1 },
    { planEventId: "event-lunch", version: 1 },
  ]);
  assert.equal(db.sends.length, 1);
  assert.equal(db.sends[0].status, "PREPARED");
});

// Changed on purpose (D116): before, every send made a new random link and
// the one in the first message died; a reminder or an invitation to one
// more occasion then opened «الرابط ما يشتغل» from the first message.
test("D116: the link is the same on every send; replacing it is what retires the old one", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const first = await rsvp.createInvitationLink(owner, "guest-1");
  const again = await rsvp.createInvitationLink(owner, "guest-1", { reminder: true });
  assert.equal(again.url, first.url);
  assert.equal((await rsvp.getInvitation(tokenOf(first.url))).guestName, "عمي صالح");

  const replaced = await rsvp.replaceInvitationLink(owner, "guest-1");
  assert.notEqual(replaced.url, first.url);
  await assert.rejects(rsvp.getInvitation(tokenOf(first.url)), /not valid/);
  assert.equal((await rsvp.getInvitation(tokenOf(replaced.url))).guestName, "عمي صالح");
  // The next send carries the new link.
  assert.equal((await rsvp.createInvitationLink(owner, "guest-1")).url, replaced.url);
});

test("D116: the last random link sent before stable links keeps opening until the link is replaced", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const legacy = "L".repeat(43);
  db.guests.set("guest-1", { ...db.guests.get("guest-1"), rsvpTokenHash: rsvpTokenHash(legacy) });

  assert.equal((await rsvp.getInvitation(legacy)).guestName, "عمي صالح");
  // A send gives the stable link and leaves the old one opening.
  const link = await rsvp.createInvitationLink(owner, "guest-1");
  assert.notEqual(tokenOf(link.url), legacy);
  assert.equal((await rsvp.getInvitation(legacy)).guestName, "عمي صالح");

  await rsvp.replaceInvitationLink(owner, "guest-1");
  await assert.rejects(rsvp.getInvitation(legacy), /not valid/);
});

test("D116: the stable link is the guest's and its version's alone", () => {
  const environment = { JWT_SECRET: "a".repeat(64) } as NodeJS.ProcessEnv;
  const token = rsvpLinkToken("guest-1", 0, environment);
  assert.match(token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(rsvpLinkToken("guest-1", 0, environment), token);
  assert.notEqual(rsvpLinkToken("guest-1", 1, environment), token);
  assert.notEqual(rsvpLinkToken("guest-2", 0, environment), token);
  assert.notEqual(
    rsvpLinkToken("guest-1", 0, { JWT_SECRET: "b".repeat(64) } as NodeJS.ProcessEnv),
    token,
  );
  // A production server without its secret makes no link at all.
  assert.throws(() =>
    rsvpLinkToken("guest-1", 0, { NODE_ENV: "production" } as NodeJS.ProcessEnv),
  );
});

test("D116: a send counts only once the person says it was sent", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const link = await rsvp.createInvitationLink(owner, "guest-1");

  const notSent = await rsvp.settleInvitationSend(owner, link.sendId, { sent: false });
  assert.equal(notSent.status, "NOT_SENT");
  assert.equal(db.guests.get("guest-1").invitationStatus, "NOT_SENT");
  // Not sent: the guest is still due the invitation.
  const retry = await rsvp.createInvitationLink(owner, "guest-1");
  assert.equal(retry.kind, "INVITATION");

  const sent = await rsvp.settleInvitationSend(owner, retry.sendId, { sent: true, channel: "SMS" });
  assert.equal(sent.status, "SENT");
  assert.ok(sent.settledAt instanceof Date);
  assert.equal(db.sends[1].channel, "SMS");
  // An app from before D116 reads the guest as invited.
  assert.equal(db.guests.get("guest-1").invitationStatus, "SENT");
  // Told of every occasion and silent: what is due now is a reminder.
  assert.equal((await rsvp.createInvitationLink(owner, "guest-1")).kind, "REMINDER");
});

test("D116: only whoever may send to the guest settles their send", async () => {
  const db = fakeDatabase();
  const link = await service(db).createInvitationLink(owner, "guest-1");
  await assert.rejects(
    service(db).settleInvitationSend(member, link.sendId, { sent: true }),
    /not found/i,
  );
  await assert.rejects(
    service(db).settleInvitationSend(owner, "send-none", { sent: true }),
    /not found/i,
  );
});

test("D116: an occasion added after the invitation is what the guest is told next, alone", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  db.eventInvites.length = 0; // invited to the wedding only
  const first = await rsvp.createInvitationLink(owner, "guest-1");
  assert.deepEqual(first.events, [{ planEventId: "event-wedding", version: 1 }]);
  await rsvp.settleInvitationSend(owner, first.sendId, { sent: true });

  db.eventInvites.push({
    id: "invite-2",
    guestId: "guest-1",
    planEventId: "event-lunch",
    attendanceStatus: "PENDING",
    companionsCount: 0,
    respondedAt: null,
    answeredVersion: null,
  });
  const addition = await rsvp.createInvitationLink(owner, "guest-1");
  assert.equal(addition.kind, "ADDITION");
  assert.deepEqual(addition.events, [{ planEventId: "event-lunch", version: 1 }]);
  assert.match(addition.message, /ويسعدنا حضورك أيضًا في الغداء، ضمن عرس أحمد\./);
  assert.doesNotMatch(addition.message, /قاعة سبأ/);
  assert.match(addition.message, /https:\/\/maps\.app\.goo\.gl\/lunch/);
});

test("D116: a changed occasion is told to the guests who hold the old one, and a confirmation before it asks again", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const first = await rsvp.createInvitationLink(owner, "guest-1");
  await rsvp.settleInvitationSend(owner, first.sendId, { sent: true });
  const token = tokenOf(first.url);
  await rsvp.respond(token, "CONFIRMED", 2, "event-lunch");
  assert.equal(db.eventInvites[0].answeredVersion, 1);

  // The lunch moves: its version rises.
  const lunch = db.events.find((event) => event.id === "event-lunch")!;
  lunch.timeSlot = "AFTER_ASR";
  lunch.version = 2;

  const view = await rsvp.getInvitation(token);
  assert.equal(view.events[0].needsReconfirm, true);
  assert.equal(view.events[0].attendanceStatus, "CONFIRMED", "the confirmation is kept");
  assert.equal(view.wedding?.needsReconfirm, false);

  const change = await rsvp.createInvitationLink(owner, "guest-1");
  assert.equal(change.kind, "CHANGE");
  assert.deepEqual(change.events, [{ planEventId: "event-lunch", version: 2 }]);
  assert.match(change.message, /تغيّر موعد أو مكان الغداء في عرس أحمد/);
  assert.match(change.message, /نرجو تأكيد حضورك من جديد من الرابط:/);
  assert.match(change.message, /بعد العصر/);

  // Confirming again, with the same figures, is news to the owner (a day
  // later here: within the hour it merges into the first, RA-BE-174).
  const before = db.notifications.length;
  mock.timers.enable({ apis: ["Date"], now: new Date(Date.now() + 24 * 3_600_000) });
  let again;
  try {
    again = await rsvp.respond(token, "CONFIRMED", 2, "event-lunch");
  } finally {
    mock.timers.reset();
  }
  assert.equal(again.events[0].needsReconfirm, false);
  assert.equal(db.eventInvites[0].answeredVersion, 2);
  assert.equal(db.notifications.length, before + 1);
});

test("D116: an invitation of its own for one occasion names that occasion, within the wedding", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  await rsvp.setInvitationCard(owner, "plan-1", { hostLine: "أبو أحمد" });
  const lunch = await rsvp.createInvitationLink(owner, "guest-1", { planEventId: "event-lunch" });
  assert.equal(lunch.kind, "INVITATION");
  assert.deepEqual(lunch.events, [{ planEventId: "event-lunch", version: 1 }]);
  assert.match(lunch.message, /يتشرف أبو أحمد بدعوتكم لحضور الغداء في عرس أحمد\./);
  assert.doesNotMatch(lunch.message, /قاعة سبأ/);
  // The same link: one page holds every occasion of the guest.
  const unified = await rsvp.createInvitationLink(owner, "guest-1");
  assert.equal(unified.url, lunch.url);
  // An occasion the guest is not invited to is refused.
  await assert.rejects(
    rsvp.createInvitationLink(owner, "guest-1", { planEventId: "event-aqd" }),
    (error: any) => error?.response?.code === "GUEST_EVENT_NOT_INVITED",
  );
});

test("D116: the page drawn in a browser marks the link opened, once; the head a crawler reads does not", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);

  await rsvp.invitationPreview(token);
  await rsvp.getInvitation(token);
  assert.equal(db.guests.get("guest-1").linkOpenedAt, null);

  await rsvp.markInvitationOpened(token);
  const first = db.guests.get("guest-1").linkOpenedAt;
  assert.ok(first instanceof Date);
  await rsvp.markInvitationOpened(token);
  assert.equal(db.guests.get("guest-1").linkOpenedAt, first);
  await assert.rejects(rsvp.markInvitationOpened("Z".repeat(43)), /not valid/);
});

test("a contributor sends links only for the guests they added", async () => {
  const db = fakeDatabase();
  await assert.rejects(service(db).createInvitationLink(member, "guest-1"), /not found/i);
  const link = await service(db, { contributorOwns: ["guest-1"] }).createInvitationLink(member, "guest-1");
  assert.ok(link.url);
});

test("the guest confirms with companions; the list updates and the owner is told", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);

  const view = await rsvp.getInvitation(token);
  assert.equal(view.planTitle, "عرس أحمد");
  assert.equal(view.weddingDate, "2027-02-18");
  assert.ok(view.locationLabel?.includes("شعوب"));
  assert.equal(view.attendanceStatus, "PENDING");
  assert.equal(view.persona, "GROOM");

  const answered = await rsvp.respond(token, "CONFIRMED", 2);
  assert.equal(answered.attendanceStatus, "CONFIRMED");
  assert.equal(answered.companionsCount, 2);
  const row = db.guests.get("guest-1");
  assert.equal(row.status, "CONFIRMED");
  assert.equal(row.weddingAnsweredVersion, 1);
  assert.ok(row.respondedAt instanceof Date);
  // Answering is the proof the invitation arrived.
  assert.equal(row.invitationStatus, "SENT");
  assert.equal(db.notifications.length, 1);
  assert.equal(db.notifications[0].userId, "owner-1");
  assert.equal(db.notifications[0].type, "GUEST_RESPONDED");
  // D55: the guest is named in the plan's form (its owner's); B-19: the
  // notice opens the guest.
  assert.match(db.notifications[0].body.masculine, /ومعه 2/);
  assert.match(db.notifications[0].body.feminine, /ومعها 2/);
  assert.match(db.notifications[0].routeTarget, /\/guests\/view\/guest-1$/);

  const declined = await rsvp.respond(token, "DECLINED", 5);
  assert.equal(declined.attendanceStatus, "DECLINED");
  assert.equal(declined.companionsCount, 0);
  // The wedding's own id answers the wedding, as no id does.
  const viaId = await rsvp.respond(token, "CONFIRMED", 1, "event-wedding");
  assert.equal(viaId.attendanceStatus, "CONFIRMED");
});

test("bad tokens, too many companions and archived plans are refused", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  await assert.rejects(rsvp.getInvitation("short"), /not valid/);
  await assert.rejects(rsvp.getInvitation("A".repeat(43)), /not valid/);
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);
  await assert.rejects(rsvp.respond(token, "CONFIRMED", 4), (error: any) =>
    error?.response?.code === "RSVP_INVALID_COMPANIONS");
  await assert.rejects(
    service(db, { planStatus: "ARCHIVED" }).getInvitation(token),
    /not valid/,
  );
});

// M-1 (Q-45, D124): a plan the owner asked to delete closes its links like an archived one.
test("a plan pending deletion closes every guest link the way an archived plan does", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);
  const pending = service(db, { deletionRequestedAt: new Date("2026-11-20T00:00:00Z") });
  const archived = service(db, { planStatus: "ARCHIVED" });
  const refusal = async (promise: Promise<unknown>) => {
    try {
      await promise;
    } catch (error: any) {
      return [error.getStatus(), error.response];
    }
    return null;
  };

  const archivedRefusal = await refusal(archived.getInvitation(token));
  assert.equal(archivedRefusal?.[0], 404);
  assert.deepEqual(await refusal(pending.getInvitation(token)), archivedRefusal);
  assert.deepEqual(await refusal(pending.respond(token, "CONFIRMED", 1)), archivedRefusal);
  assert.deepEqual(await refusal(pending.markInvitationOpened(token)), archivedRefusal);
  assert.deepEqual(await refusal(pending.cardPhotoDownloadUrl(token)), archivedRefusal);
  assert.equal(await pending.invitationPreview(token), null);
});

// D83: the events beyond the wedding, one reply each.
test("the guest reads the events they are invited to and answers each one on its own", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);

  const view = await rsvp.getInvitation(token);
  assert.deepEqual(
    view.events.map((event) => [event.id, event.label, event.attendanceStatus]),
    [["event-lunch", "الغداء", "PENDING"]],
  );
  assert.equal(view.events[0].date, "2027-02-18");
  assert.equal(view.events[0].timeSlot, "DHUHR");
  assert.equal(view.events[0].placeLabel, "بيت العريس");
  // D116: each occasion carries its own map link.
  assert.equal(view.events[0].mapUrl, "https://maps.app.goo.gl/lunch");
  // The wedding row's time, venue and place reach the page too.
  assert.deepEqual(view.wedding, {
    id: "event-wedding",
    timeSlot: "AFTER_ISHA",
    exactTime: null,
    timeLabel: "بعد العشاء",
    placeLabel: "قاعة سبأ",
    mapUrl: null,
    address: null,
    needsReconfirm: false,
  });
  assert.equal(view.events[0].timeLabel, "الظهر");
  assert.equal(view.hostPhrase, null);

  const answered = await rsvp.respond(token, "CONFIRMED", 1, "event-lunch");
  assert.equal(answered.events[0].attendanceStatus, "CONFIRMED");
  assert.equal(answered.events[0].companionsCount, 1);
  assert.ok(answered.events[0].respondedAt instanceof Date);
  // The wedding reply is its own and stays untouched.
  assert.equal(answered.attendanceStatus, "PENDING");
  assert.equal(db.guests.get("guest-1").attendanceStatus, "PENDING");
  assert.equal(db.notifications.length, 1);
  assert.match(db.notifications[0].title.masculine, /الغداء/);

  // An event the guest was not invited to cannot be answered.
  await assert.rejects(rsvp.respond(token, "CONFIRMED", 0, "event-aqd"), (error: any) =>
    error?.response?.code === "RSVP_EVENT_NOT_INVITED");
});

// RA-BE-74: the link still works when the hosts take an event out of the
// invitation; only that reply is refused, as a change, not as a dead link.
test("a reply to an event taken out of the invitation is a conflict the page can reload from", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);
  // The guest opened the page; then the hosts took them off the lunch.
  db.eventInvites.length = 0;

  await assert.rejects(rsvp.respond(token, "CONFIRMED", 1, "event-lunch"), (error: any) => {
    assert.equal(error.getStatus(), 409);
    assert.equal(error.response.code, "RSVP_EVENT_NOT_INVITED");
    assert.match(error.response.message, /[؀-ۿ]/);
    return true;
  });
  // The link itself still opens, with the invitation as it is now.
  assert.deepEqual((await rsvp.getInvitation(token)).events, []);
  // A link that does not exist stays a 404.
  await assert.rejects(rsvp.respond("B".repeat(43), "CONFIRMED", 0, "event-lunch"), (error: any) =>
    error.getStatus() === 404 && error.response.code === "RSVP_LINK_NOT_FOUND");
});

// RA-BE-87: the owner hears of a reply when it changed what the guest said.
// RA-BE-174: and the changes one guest makes in one hour are one notice,
// saying the last of them.
test("the owner is told once per change of reply, never for the same reply again", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);
  const hour = (time: string) => new Date(`2026-12-01T${time}:00Z`);
  const at = async (time: string, answer: () => Promise<unknown>) => {
    mock.timers.enable({ apis: ["Date"], now: hour(time) });
    try {
      await answer();
    } finally {
      mock.timers.reset();
    }
  };

  await at("10:05", () => rsvp.respond(token, "CONFIRMED", 2));
  await at("10:06", () => rsvp.respond(token, "CONFIRMED", 2));
  assert.equal(db.notifications.length, 1, "the same reply again tells nothing new");
  const key = db.notifications[0].dedupeKey;
  assert.match(key, /^owner-1:guest-responded:plan-1:hour-/);
  assert.equal(db.notifications[0].mergeIntoExisting, true);

  await at("10:20", () => rsvp.respond(token, "CONFIRMED", 3));
  await at("10:40", () => rsvp.respond(token, "DECLINED", 0));
  await at("10:41", () => rsvp.respond(token, "DECLINED", 4)); // declining keeps no companions
  assert.equal(db.notifications.length, 1, "one guest's changes in one hour are one notice");
  assert.equal(db.notifications[0].dedupeKey, key);
  assert.match(db.notifications[0].title.masculine, /اعتذر/);

  // The same guest's answer to another occasion in that hour merges too.
  await at("10:50", () => rsvp.respond(token, "DECLINED", 0, "event-lunch"));
  await at("10:51", () => rsvp.respond(token, "DECLINED", 0, "event-lunch"));
  assert.equal(db.notifications.length, 1);
  assert.match(db.notifications[0].title.masculine, /اعتذر عن الغداء/);

  // The next hour is a new notice.
  await at("11:02", () => rsvp.respond(token, "CONFIRMED", 0, "event-lunch"));
  assert.equal(db.notifications.length, 2);
  assert.notEqual(db.notifications[1].dedupeKey, key);
  assert.match(db.notifications[1].title.masculine, /أكّد حضوره في الغداء/);
});

// RA-BE-190: 300 guests answering in an evening were 300 rows in the owner's
// inbox. The replies of one hour are one notice for the plan: the first
// names the guest; once a second guest has answered it says that replies
// came and opens the attendance screen; the next hour starts a new one.
test("RA-BE-190: the replies of every guest in one hour are one notice for the plan", async () => {
  const db = fakeDatabase();
  db.guests.set("guest-2", {
    ...db.guests.get("guest-1"),
    id: "guest-2",
    name: "خالي أحمد",
    normalizedPhone: "+967777000222",
    rsvpTokenHash: null,
    rsvpLinkHash: null,
  });
  const rsvp = service(db);
  const first = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);
  const second = tokenOf((await rsvp.createInvitationLink(owner, "guest-2")).url);
  const at = async (time: string, answer: () => Promise<unknown>) => {
    mock.timers.enable({ apis: ["Date"], now: new Date(`2026-12-01T${time}:00Z`) });
    try {
      await answer();
    } finally {
      mock.timers.reset();
    }
  };

  await at("10:05", () => rsvp.respond(first, "CONFIRMED", 2));
  assert.equal(db.notifications.length, 1);
  assert.match(db.notifications[0].title.masculine, /عمي صالح أكّد حضوره/);
  assert.match(db.notifications[0].routeTarget, /\/guests\/view\/guest-1$/);
  const key = db.notifications[0].dedupeKey;

  // A second guest in the same hour: the same row, now about replies.
  await at("10:30", () => rsvp.respond(second, "DECLINED", 0));
  assert.equal(db.notifications.length, 1, "one notice for the plan's hour");
  assert.equal(db.notifications[0].dedupeKey, key);
  assert.equal(db.notifications[0].mergeIntoExisting, true);
  assert.match(db.notifications[0].title, /ردود/);
  assert.equal(db.notifications[0].entityType, "wedding_plan");
  assert.equal(db.notifications[0].entityId, "plan-1");
  assert.equal(db.notifications[0].routeTarget, "/wedding-plans/plan-1/guests/attendance");
  // It names no guest and counts none: the lock screen and the inbox stay clean.
  assert.doesNotMatch(JSON.stringify(db.notifications[0]), /عمي صالح|خالي أحمد/);

  // The first guest changes their answer: still the one plural notice.
  await at("10:50", () => rsvp.respond(first, "DECLINED", 0));
  assert.equal(db.notifications.length, 1);
  assert.equal(db.notifications[0].routeTarget, "/wedding-plans/plan-1/guests/attendance");

  // The next hour starts again with the guest's name.
  await at("11:02", () => rsvp.respond(second, "CONFIRMED", 1));
  assert.equal(db.notifications.length, 2);
  assert.notEqual(db.notifications[1].dedupeKey, key);
  assert.match(db.notifications[1].title.masculine, /خالي أحمد أكّد حضوره/);
});

// RA-BE-174: a week after the wedding the link stops opening: it names the
// guest and the place, and a family group keeps it forever.
test("RA-BE-174: the link closes seven days after the wedding, and a plan with no date keeps it", async () => {
  const db = fakeDatabase();
  const wedding = new Date("2026-11-10T00:00:00Z");
  const token = tokenOf((await service(db).createInvitationLink(owner, "guest-1")).url);
  const expired = (error: any) =>
    error?.getStatus?.() === 410 &&
    error.response.code === "RSVP_LINK_EXPIRED" &&
    /[؀-ۿ]/u.test(error.response.message);
  const on = async (instant: string, check: (rsvp: GuestRsvpService) => Promise<void>) => {
    mock.timers.enable({ apis: ["Date"], now: new Date(instant) });
    try {
      await check(service(db, { weddingDate: wedding }));
    } finally {
      mock.timers.reset();
    }
  };

  // The seventh day after, to its end in Aden, still opens.
  await on("2026-11-17T20:59:00Z", async (rsvp) => {
    assert.equal((await rsvp.getInvitation(token)).guestName, "عمي صالح");
    assert.ok(await rsvp.invitationPreview(token));
  });
  await on("2026-11-17T21:00:00Z", async (rsvp) => {
    await assert.rejects(rsvp.getInvitation(token), expired);
    await assert.rejects(rsvp.respond(token, "CONFIRMED", 0), expired);
    await assert.rejects(rsvp.respond(token, "CONFIRMED", 0, "event-lunch"), expired);
    await assert.rejects(rsvp.markInvitationOpened(token), expired);
    await assert.rejects(rsvp.cardPhotoDownloadUrl(token), expired);
    assert.equal(await rsvp.invitationPreview(token), null);
  });
  assert.equal(db.guests.get("guest-1").attendanceStatus, "PENDING");

  mock.timers.enable({ apis: ["Date"], now: new Date("2030-01-01T00:00:00Z") });
  try {
    assert.equal((await service(db, { weddingDate: null }).getInvitation(token)).guestName, "عمي صالح");
  } finally {
    mock.timers.reset();
  }
});

// RA-BE-86: reading the card is a read of the plan, like its guest list.
test("the card of an archived plan still reads; only writing it is refused", async () => {
  const db = fakeDatabase();
  await service(db).setInvitationCard(owner, "plan-1", { hostLine: "أبو أحمد" });

  const archived = service(db, { planStatus: "ARCHIVED" });
  assert.equal((await archived.getInvitationCard(owner, "plan-1")).hostLine, "أبو أحمد");
  assert.equal((await archived.getInvitationCard(member, "plan-1")).hostLine, "أبو أحمد");
  await assert.rejects(
    archived.setInvitationCard(owner, "plan-1", { hostLine: "غيره" }),
    (error: any) => error?.response?.code === "PLAN_ARCHIVED_READ_ONLY",
  );
});

// D83: one card per plan, kept in the account. D116: its map link and
// address are the wedding row's.
test("the card is saved once per plan, read by the guest, and spoken in the message", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);

  const empty = await rsvp.getInvitationCard(owner, "plan-1");
  assert.deepEqual(empty, {
    weddingPlanId: "plan-1",
    hostLine: null,
    freeText: null,
    photoUrl: null,
    photoKind: "PHOTO",
    photoReadUrl: null,
    mapUrl: null,
    address: null,
    updatedAt: null,
  });

  const saved = await rsvp.setInvitationCard(owner, "plan-1", {
    hostLine: " عبدالرحمن الحمدي ",
    freeText: "يا مرحبا بالحاضرين",
    mapUrl: "https://maps.app.goo.gl/abc",
    address: " ",
  });
  assert.equal(saved.hostLine, "عبدالرحمن الحمدي");
  assert.equal(saved.freeText, "يا مرحبا بالحاضرين");
  assert.equal(saved.mapUrl, "https://maps.app.goo.gl/abc");
  assert.equal(saved.address, null);
  assert.ok(saved.updatedAt instanceof Date);
  // The map link is the wedding row's, and a new one raises its version.
  const wedding = db.events.find((event) => event.type === "WEDDING")!;
  assert.equal(wedding.mapUrl, "https://maps.app.goo.gl/abc");
  assert.equal(wedding.version, 2);
  assert.equal(db.cards.get("plan-1").mapUrl, undefined, "the card keeps no copy");
  // A later save of one field keeps the others.
  const kept = await rsvp.setInvitationCard(owner, "plan-1", { address: "شارع تعز، جوار الجامع" });
  assert.equal(kept.hostLine, "عبدالرحمن الحمدي");
  assert.equal(kept.address, "شارع تعز، جوار الجامع");
  assert.equal(wedding.version, 2, "an address alone changes nothing a guest was told");
  assert.equal((await rsvp.getInvitationCard(owner, "plan-1")).address, "شارع تعز، جوار الجامع");

  const link = await rsvp.createInvitationLink(owner, "guest-1");
  assert.match(link.message, /يتشرف عبدالرحمن الحمدي بدعوتكم لحضور عرس أحمد/);
  assert.match(link.message, /يا مرحبا بالحاضرين/);
  assert.match(link.message, /\*الغداء\*/);
  assert.match(link.message, /بيت العريس/);
  assert.match(link.message, /https:\/\/maps\.app\.goo\.gl\/abc/);
  assert.match(link.message, /العنوان: شارع تعز، جوار الجامع/);
  assert.match(link.message, /قاعة سبأ/);

  const view = await rsvp.getInvitation(tokenOf(link.url));
  assert.equal(view.card?.hostLine, "عبدالرحمن الحمدي");
  assert.equal(view.card?.mapUrl, "https://maps.app.goo.gl/abc");
  assert.equal(view.wedding?.mapUrl, "https://maps.app.goo.gl/abc");
  assert.equal(view.hostPhrase, "يتشرف عبدالرحمن الحمدي بدعوتكم لحضور");

  // A reminder is the short text with the guest's link.
  const reminder = await rsvp.createInvitationLink(owner, "guest-1", { reminder: true });
  assert.match(reminder.message, /^أهلًا عمي صالح\nنذكرك بعرس أحمد\./);
  assert.doesNotMatch(reminder.message, /يتشرف/);
  assert.ok(reminder.message.includes(reminder.url));
});

test("the bride's card speaks to women, and a map link must be HTTPS", async () => {
  const db = fakeDatabase();
  const rsvp = service(db, { persona: "BRIDE" });
  await rsvp.setInvitationCard(owner, "plan-1", { hostLine: "أم سلمى" });
  const link = await rsvp.createInvitationLink(owner, "guest-1");
  assert.match(link.message, /تتشرف أم سلمى بدعوتكن لحضور/);
  assert.equal((await rsvp.getInvitation(tokenOf(link.url))).persona, "BRIDE");

  await assert.rejects(
    rsvp.setInvitationCard(owner, "plan-1", { mapUrl: "http://maps.app.goo.gl/abc" }),
    (error: any) => error?.response?.code === "INVITATION_CARD_MAP_URL_INVALID",
  );
});

test("D116: the card says what its picture is, a photo drawn in or a ready card shown whole", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const ready = await rsvp.setInvitationCard(owner, "plan-1", { photoKind: "CARD" });
  assert.equal(ready.photoKind, "CARD");
  // A save that does not name it keeps it.
  assert.equal((await rsvp.setInvitationCard(owner, "plan-1", { hostLine: "س" })).photoKind, "CARD");
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);
  assert.equal((await rsvp.getInvitation(token)).card?.photoKind, "CARD");
});

test("the card photo is the owner's verified upload, consumed by the card and released when replaced", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const first = "https://media.example/guest-invitation-card/owner-1/a.jpg";
  const saved = await rsvp.setInvitationCard(owner, "plan-1", { photoUrl: first });
  assert.equal(saved.photoUrl, first);
  assert.deepEqual(db.media, [
    ["verify", first],
    ["consume", first, "guest-invitation-card", { type: "GUEST_INVITATION_CARD", id: "card-plan-1" }],
  ]);

  db.media.length = 0;
  const cleared = await rsvp.setInvitationCard(owner, "plan-1", { photoUrl: null });
  assert.equal(cleared.photoUrl, null);
  assert.deepEqual(db.media, [["delete", { type: "GUEST_INVITATION_CARD", id: "card-plan-1" }]]);
});

test("the link origin must be HTTPS", () => {
  assert.equal(rsvpPublicOrigin({ INVITE_PUBLIC_ORIGIN: "https://example.org/x" }), "https://example.org");
  assert.throws(() => rsvpPublicOrigin({ INVITE_PUBLIC_ORIGIN: "http://example.org" }));
  assert.equal(
    buildRsvpMessage({
      guestName: "س",
      planTitle: "عرس",
      url: "https://x/rsvp/t",
      occasions: [
        {
          label: "العرس",
          isWedding: true,
          date: null,
          timeSlot: null,
          exactTime: null,
          placeLabel: null,
          address: null,
          mapUrl: null,
        },
      ],
    }).includes("الموعد"),
    false,
  );
});

// 6b: WhatsApp previews the first link of a text. The guest's own link
// comes first, so the preview is the invitation and not the venue's map.
test("the invitation link comes before every map link in the message", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  await rsvp.setInvitationCard(owner, "plan-1", {
    hostLine: "أبو أحمد",
    mapUrl: "https://maps.app.goo.gl/abc",
  });
  const link = await rsvp.createInvitationLink(owner, "guest-1");
  const urls = link.message.match(/https:\/\/\S+/g) ?? [];
  assert.deepEqual(urls, [
    link.url,
    "https://maps.app.goo.gl/abc",
    "https://maps.app.goo.gl/lunch",
  ]);
  // The details follow the link.
  assert.ok(link.message.indexOf(link.url) < link.message.indexOf("قاعة سبأ"));
  assert.match(link.message, /نرجو تأكيد حضورك لكل مناسبة من الرابط:\n/);
});

test("D116: a text too long for WhatsApp drops its map links, and says they are behind the link", () => {
  const occasion = (index: number) => ({
    label: `مناسبة ${index}`,
    isWedding: index === 0,
    date: new Date(Date.UTC(2027, 1, 10 + index)),
    timeSlot: "AFTER_ISHA" as const,
    exactTime: null,
    placeLabel: `مكان طويل الاسم رقم ${index} في صنعاء القديمة`,
    address: `شارع رقم ${index}، جوار الجامع الكبير، بعد الدوار الثاني`,
    mapUrl: `https://maps.app.goo.gl/${"x".repeat(40)}${index}`,
  });
  const message = buildRsvpMessage({
    guestName: "ياسر",
    planTitle: "عرس رضوان",
    url: "https://x/rsvp/t",
    occasions: Array.from({ length: 12 }, (_, index) => occasion(index)),
  });
  assert.ok(message.length <= RSVP_MESSAGE_SOFT_LIMIT || !message.includes("maps.app"));
  assert.doesNotMatch(message, /maps\.app/);
  assert.match(message, /ومواقع الخريطة في الرابط\./);
  assert.match(message, /\*مناسبة 11\*/);
});

// 6a: the card photo is private in the bucket; the guest's link reads it.
test("the guest page and the crawler read the card photo through the link, never the bucket address", async () => {
  process.env.INVITE_PUBLIC_ORIGIN = "https://3.121.198.183";
  const db = fakeDatabase();
  const rsvp = service(db);
  const stored = "https://media.example/guest-invitation-card/owner-1/a.jpg";
  await rsvp.setInvitationCard(owner, "plan-1", { hostLine: "أبو أحمد", photoUrl: stored });
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);

  const view = await rsvp.getInvitation(token);
  assert.equal(view.card?.photoUrl, `https://3.121.198.183/api/v1/public/rsvp/${token}/card-photo`);
  assert.ok(!JSON.stringify(view).includes("media.example"), "the stored address stays on the server");

  db.signed.length = 0;
  const read = await rsvp.cardPhotoDownloadUrl(token);
  assert.match(read, /^https:\/\/signed\.example\//);
  assert.deepEqual(db.signed, [[stored, "guest-invitation-card"]]);

  // A dead link reads nothing; a card without a photo is a 404 too.
  await assert.rejects(rsvp.cardPhotoDownloadUrl("C".repeat(43)), (error: any) =>
    error.getStatus() === 404 && error.response.code === "RSVP_LINK_NOT_FOUND");
  await rsvp.setInvitationCard(owner, "plan-1", { photoUrl: null });
  await assert.rejects(rsvp.cardPhotoDownloadUrl(token), (error: any) =>
    error.getStatus() === 404 && error.response.code === "RSVP_CARD_PHOTO_NOT_FOUND");
  assert.equal((await rsvp.getInvitation(token)).card?.photoUrl, null);
  // A replaced link reads nothing either.
  await rsvp.setInvitationCard(owner, "plan-1", { photoUrl: stored });
  await rsvp.replaceInvitationLink(owner, "guest-1");
  await assert.rejects(rsvp.cardPhotoDownloadUrl(token), /not valid/);
});

test("the owner's card carries a signed read of its photo", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const stored = "https://media.example/guest-invitation-card/owner-1/a.jpg";
  const saved = await rsvp.setInvitationCard(owner, "plan-1", { photoUrl: stored });
  assert.equal(saved.photoUrl, stored, "the saved address stays the card's identity");
  assert.match(saved.photoReadUrl ?? "", /^https:\/\/signed\.example\//);
  const read = await rsvp.getInvitationCard(member, "plan-1");
  assert.match(read.photoReadUrl ?? "", /^https:\/\/signed\.example\//);
  assert.equal((await rsvp.setInvitationCard(owner, "plan-1", { photoUrl: null })).photoReadUrl, null);
});

// From the review of this branch: the signed read is made after the card is
// saved. A photo that cannot be signed (kept on an older media host, or the
// storage not configured) failed the read of the whole card, and reported a
// save that had gone through as failed.
test("a photo that cannot be signed leaves the card readable and its save answered", async () => {
  const db = fakeDatabase();
  const stored = "https://old-media.example/guest-invitation-card/owner-1/a.jpg";
  await service(db).setInvitationCard(owner, "plan-1", { photoUrl: stored, hostLine: "آل الحمدي" });

  const failing = service(db, { signingFails: true });
  const read = await failing.getInvitationCard(member, "plan-1");
  assert.equal(read.photoUrl, stored);
  assert.equal(read.photoReadUrl, null);
  assert.equal(read.hostLine, "آل الحمدي");

  const saved = await failing.setInvitationCard(owner, "plan-1", { freeText: "نورتوا" });
  assert.equal(saved.freeText, "نورتوا");
  assert.equal(saved.photoReadUrl, null);
});

// From the second review of this branch: the guest's page and the link's
// preview named the photo's route all the same, so the guest got a broken
// picture and WhatsApp a picture that answers with an error.
test("a photo that cannot be signed is not offered to the guest's page (the preview never names a photo)", async () => {
  process.env.INVITE_PUBLIC_ORIGIN = "https://3.121.198.183";
  const db = fakeDatabase();
  const stored = "https://old-media.example/guest-invitation-card/owner-1/a.jpg";
  const rsvp = service(db);
  await rsvp.setInvitationCard(owner, "plan-1", { photoUrl: stored, hostLine: "آل الحمدي" });
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);

  const failing = service(db, { signingFails: true });
  const view = await failing.getInvitation(token);
  assert.equal(view.card?.photoUrl, null);
  assert.equal(view.card?.hostLine, "آل الحمدي", "the rest of the card is still read");
  const preview = await failing.invitationPreview(token);
  assert.ok(preview);
  assert.doesNotMatch(preview.image?.url ?? "", /card-photo/);
  // The route itself answers «no photo», not a server error.
  await assert.rejects(failing.cardPhotoDownloadUrl(token), (error: any) =>
    error.getStatus() === 404 && error.response.code === "RSVP_CARD_PHOTO_NOT_FOUND");
});

// «ذكّر الكل» (2026-11-14): a guest who already confirmed is reminded of the
// occasion, not asked to answer again. D116: the link is the same one, so
// the text no longer calls it new; the day is said with the occasion's
// details, not twice.
test("a reminder to a guest who confirmed says the occasion and keeps the link, without asking for an answer", () => {
  const base = {
    guestName: "مراد",
    planTitle: "عرس أحمد",
    url: "https://x/rsvp/t",
    kind: "REMINDER" as const,
    occasions: [
      {
        label: "العرس",
        isWedding: true,
        date: new Date(Date.UTC(2027, 1, 18)),
        timeSlot: null,
        exactTime: null,
        placeLabel: null,
        address: null,
        mapUrl: null,
      },
    ],
  };
  const confirmed = buildRsvpMessage({ ...base, confirmed: true });
  assert.equal(
    confirmed,
    "أهلًا مراد\nنذكرك بعرس أحمد.\nننتظرك. ولو تغيّر شي، هذا رابطك:\nhttps://x/rsvp/t\n\nالموعد: 18/2/2027",
  );
  assert.doesNotMatch(confirmed, /للرد/);

  const pending = buildRsvpMessage(base);
  assert.match(pending, /هذا رابطك للرد بضغطة:/);
  assert.doesNotMatch(pending, /الجديد/);
  assert.doesNotMatch(pending, /ننتظرك/);
});

test("a crawler gets this invitation's head; an unknown, replaced or archived link gets none", async () => {
  process.env.INVITE_PUBLIC_ORIGIN = "https://3.121.198.183";
  const db = fakeDatabase();
  const rsvp = service(db);
  await rsvp.setInvitationCard(owner, "plan-1", {
    hostLine: "أبو أحمد",
    photoUrl: "https://media.example/guest-invitation-card/owner-1/a.webp",
  });
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);

  const preview = await rsvp.invitationPreview(token);
  assert.ok(preview);
  assert.equal(preview.title, "يتشرف أبو أحمد بدعوتكم لحضور عرس أحمد");
  assert.equal(preview.url, `https://3.121.198.183/rsvp/${token}`);
  // RA-OP-29 (Q-44): the message keeps the preview after the link is
  // archived, so it holds the names and اعّرست's mark and nothing else: not
  // the card's photo, not the day, not the place.
  assert.equal(preview.description, "نرجو تأكيد حضورك من الرابط.");
  assert.doesNotMatch(preview.description, /18\/2\/2027|قاعة سبأ/);
  assert.deepEqual(preview.image, {
    url: "https://3.121.198.183/rsvp-preview.png",
    type: "image/png",
  });
  assert.doesNotMatch(JSON.stringify(preview), /card-photo|media\.example/);

  assert.equal(await rsvp.invitationPreview("short"), null);
  assert.equal(await rsvp.invitationPreview("D".repeat(43)), null);
  assert.equal(await service(db, { planStatus: "ARCHIVED" }).invitationPreview(token), null);
  await rsvp.replaceInvitationLink(owner, "guest-1");
  assert.equal(await rsvp.invitationPreview(token), null, "a replaced link names nobody");

  // A card with no photo previews the same way.
  const fresh = fakeDatabase();
  const plain = service(fresh);
  const plainToken = tokenOf((await plain.createInvitationLink(owner, "guest-1")).url);
  const plainPreview = await plain.invitationPreview(plainToken);
  assert.equal(plainPreview?.image?.url, "https://3.121.198.183/rsvp-preview.png");
  assert.equal(plainPreview?.title, "يسعدنا دعوتك لحضور عرس أحمد");
});

test("the head escapes what the hosts typed and names the image only when there is one", () => {
  const head = renderRsvpPreviewHead({
    title: `زفاف "سعيد" <script>&`,
    description: "الموعد: 18/2/2027",
    url: "https://3.121.198.183/rsvp/t",
    image: { url: "https://3.121.198.183/api/v1/public/rsvp/t/card-photo", type: "image/jpeg" },
  });
  assert.match(head, /<meta property="og:title" content="زفاف &quot;سعيد&quot; &lt;script&gt;&amp;">/);
  assert.doesNotMatch(head, /<script/);
  assert.match(head, /<meta property="og:url" content="https:\/\/3\.121\.198\.183\/rsvp\/t">/);
  assert.match(head, /<meta property="og:image" content="https:\/\/3\.121\.198\.183\/api\/v1\/public\/rsvp\/t\/card-photo">/);
  assert.match(head, /<meta property="og:image:type" content="image\/jpeg">/);
  assert.match(head, /<meta name="twitter:card" content="summary">/);

  const bare = renderRsvpPreviewHead({ title: "عرس", description: "د", url: "https://x/rsvp/t", image: null });
  assert.doesNotMatch(bare, /og:image/);
  assert.match(bare, /<meta name="twitter:card" content="summary">/);
});

function fakeResponse() {
  const sent: any = { headers: {} as Record<string, string> };
  const res: any = {
    set(name: string, value: string) { sent.headers[name.toLowerCase()] = value; return res; },
    status(code: number) { sent.status = code; return res; },
    type(value: string) { sent.headers["content-type"] = value; return res; },
    send(body: string) { sent.body = body; return res; },
    end() { sent.ended = true; return res; },
    redirect(code: number, url: string) { sent.status = code; sent.location = url; return res; },
  };
  return { res, sent };
}

test("the head route answers 204 for a dead link and HTML for a live one; the photo route redirects, uncached", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  await rsvp.setInvitationCard(owner, "plan-1", {
    photoUrl: "https://media.example/guest-invitation-card/owner-1/a.png",
  });
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);
  const controller = new PublicRsvpController(rsvp);

  const dead = fakeResponse();
  await controller.preview("E".repeat(43), dead.res);
  assert.equal(dead.sent.status, 204);
  assert.equal(dead.sent.body, undefined);
  assert.equal(dead.sent.headers["cache-control"], "private, no-store");

  const live = fakeResponse();
  await controller.preview(token, live.res);
  assert.equal(live.sent.status, 200);
  assert.match(live.sent.headers["content-type"], /^text\/html/);
  assert.match(live.sent.body, /og:image:type" content="image\/png"/);
  assert.equal(live.sent.headers["cache-control"], "private, no-store");

  const photo = fakeResponse();
  await controller.cardPhoto(token, photo.res);
  assert.equal(photo.sent.status, 302);
  assert.match(photo.sent.location, /^https:\/\/signed\.example\//);
  assert.equal(photo.sent.headers["cache-control"], "private, no-store");
  assert.equal(photo.sent.headers["referrer-policy"], "no-referrer");
  await assert.rejects(controller.cardPhoto("F".repeat(43), fakeResponse().res), /not valid/);
});

test("RA-BE-175: the guest's JSON (name, place) is never kept by a cache", () => {
  for (const route of ["getInvitation", "opened", "respond"] as const) {
    const headers: Array<{ name: string; value: string }> =
      Reflect.getMetadata(HEADERS_METADATA, PublicRsvpController.prototype[route]) ?? [];
    assert.deepEqual(
      headers.filter((header) => header.name.toLowerCase() === "cache-control"),
      [{ name: "Cache-Control", value: "private, no-store" }],
      route,
    );
  }
});

// RA-BE-173 (Q-43 (أ)): the owner sets how many may come with each guest
// (the guest's seats less their own); none unless the owner said so.
test("RA-BE-173: the guest brings at most the companions the owner gave them, none by default", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);
  assert.equal((await rsvp.getInvitation(token)).maxCompanions, 3);

  db.guests.get("guest-1").seatsCount = 1;
  const alone = await rsvp.getInvitation(token);
  assert.equal(alone.maxCompanions, 0);
  for (const planEventId of [undefined, "event-lunch"]) {
    await assert.rejects(rsvp.respond(token, "CONFIRMED", 1, planEventId), (error: any) =>
      error?.getStatus() === 400 && error?.response?.code === "RSVP_INVALID_COMPANIONS");
  }
  assert.equal((await rsvp.respond(token, "CONFIRMED", 0)).companionsCount, 0);

  db.guests.get("guest-1").seatsCount = 3;
  assert.equal((await rsvp.respond(token, "CONFIRMED", 2, "event-lunch")).events[0].companionsCount, 2);
  await assert.rejects(rsvp.respond(token, "CONFIRMED", 3, "event-lunch"), (error: any) =>
    error?.response?.code === "RSVP_INVALID_COMPANIONS");
  // Declining brings no one, whatever the page sent.
  assert.equal((await rsvp.respond(token, "DECLINED", 9)).companionsCount, 0);
});
