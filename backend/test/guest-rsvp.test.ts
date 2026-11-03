import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  buildRsvpMessage,
  GuestRsvpService,
  rsvpPublicOrigin,
  rsvpTokenHash,
} from "../src/guests/guest-rsvp.service";

// Personal invitation links and RSVP (V1 checklist 4.7).

const owner = { id: "owner-1" } as any;
const member = { id: "member-1" } as any;

// D83: the plan's events beyond the wedding, as planning lists them.
const planEvents = [
  {
    id: "event-wedding",
    weddingPlanId: "plan-1",
    type: "WEDDING",
    title: null,
    date: new Date("2027-02-18T00:00:00Z"),
    timeSlot: "AFTER_ISHA",
    exactTime: null,
    placeLabel: "قاعة سبأ",
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
  },
];

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
        seatsCount: 1,
        companionsCount: 0,
        respondedAt: null,
        rsvpTokenHash: null,
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
    },
  ];
  const cards = new Map<string, any>();
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
      findUnique: async ({ where }: any) => {
        if (where.id) return guests.get(where.id) ?? null;
        return [...guests.values()].find((row) => row.rsvpTokenHash === where.rsvpTokenHash) ?? null;
      },
      update: async ({ where, data }: any) => {
        const row = { ...guests.get(where.id), ...data };
        guests.set(where.id, row);
        return row;
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
          : { id: `card-${where.weddingPlanId}`, ...create, updatedAt: new Date() };
        cards.set(where.weddingPlanId, row);
        return row;
      },
    },
  };
  const prisma: any = {
    ...tx,
    $transaction: async (operation: (client: any) => Promise<unknown>) => operation(tx),
  };
  return { prisma, guests, eventInvites, cards, notifications, media: [] as any[] };
}

function service(
  db: ReturnType<typeof fakeDatabase>,
  options: { contributorOwns?: string[]; planStatus?: string; persona?: string } = {},
) {
  const permissions: any = {
    assertGuestManageableInTransaction: async (_tx: unknown, _plan: string, user: any) => ({
      isOwner: user.id === "owner-1",
      sharedMember: user.id === "owner-1" ? null : { userId: user.id },
    }),
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
      weddingDate: new Date("2027-02-18T00:00:00Z"),
      city: null,
      location: { governorate: "أمانة العاصمة", cityOrDistrict: "شعوب" },
    }),
    listPlanEvents: async () => planEvents,
  };
  const notifications: any = {
    createNotificationInTransaction: async (_tx: unknown, input: any) => {
      db.notifications.push(input);
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
  };
  return new GuestRsvpService(db.prisma, permissions, scope, plans, notifications, media);
}

function tokenOf(url: string): string {
  return url.split("/rsvp/")[1];
}

test("the owner gets a personal link and a WhatsApp message; only the hash is stored", async () => {
  process.env.INVITE_PUBLIC_ORIGIN = "https://3-121-198-183.sslip.io";
  const db = fakeDatabase();
  const link = await service(db).createInvitationLink(owner, "guest-1");

  assert.match(link.url, /^https:\/\/3-121-198-183\.sslip\.io\/rsvp\/[A-Za-z0-9_-]{43}$/);
  assert.equal(link.phone, "+967777000111");
  assert.match(link.message, /عرس أحمد/);
  assert.match(link.message, /18\/2\/2027/);
  assert.ok(link.message.includes(link.url));
  const stored = db.guests.get("guest-1");
  assert.equal(stored.rsvpTokenHash, rsvpTokenHash(tokenOf(link.url)));
  assert.equal(stored.invitationStatus, "SENT");
  assert.ok(!JSON.stringify(stored).includes(tokenOf(link.url)));
});

test("a new link replaces the old one", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const first = await rsvp.createInvitationLink(owner, "guest-1");
  const second = await rsvp.createInvitationLink(owner, "guest-1");

  await assert.rejects(rsvp.getInvitation(tokenOf(first.url)), /not valid/);
  assert.equal((await rsvp.getInvitation(tokenOf(second.url))).guestName, "عمي صالح");
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

  const answered = await rsvp.respond(token, "CONFIRMED", 2);
  assert.equal(answered.attendanceStatus, "CONFIRMED");
  assert.equal(answered.companionsCount, 2);
  const row = db.guests.get("guest-1");
  assert.equal(row.status, "CONFIRMED");
  assert.ok(row.respondedAt instanceof Date);
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
});

test("bad tokens, too many companions and archived plans are refused", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  await assert.rejects(rsvp.getInvitation("short"), /not valid/);
  await assert.rejects(rsvp.getInvitation("A".repeat(43)), /not valid/);
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);
  await assert.rejects(rsvp.respond(token, "CONFIRMED", 21), (error: any) =>
    error?.response?.code === "RSVP_INVALID_COMPANIONS");
  await assert.rejects(
    service(db, { planStatus: "ARCHIVED" }).getInvitation(token),
    /not valid/,
  );
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
  // The wedding row's time and venue reach the page too.
  assert.deepEqual(view.wedding, {
    timeSlot: "AFTER_ISHA",
    exactTime: null,
    timeLabel: "بعد العشاء",
    placeLabel: "قاعة سبأ",
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

// D83: one card per plan, kept in the account.
test("the card is saved once per plan, read by the guest, and spoken in the message", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);

  const empty = await rsvp.getInvitationCard(owner, "plan-1");
  assert.deepEqual(empty, {
    weddingPlanId: "plan-1",
    hostLine: null,
    freeText: null,
    photoUrl: null,
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
  // A later save of one field keeps the others.
  const kept = await rsvp.setInvitationCard(owner, "plan-1", { address: "شارع تعز، جوار الجامع" });
  assert.equal(kept.hostLine, "عبدالرحمن الحمدي");
  assert.equal(kept.address, "شارع تعز، جوار الجامع");
  assert.equal((await rsvp.getInvitationCard(owner, "plan-1")).address, "شارع تعز، جوار الجامع");

  const link = await rsvp.createInvitationLink(owner, "guest-1");
  assert.match(link.message, /يتشرف عبدالرحمن الحمدي بدعوتكم لحضور عرس أحمد/);
  assert.match(link.message, /يا مرحبا بالحاضرين/);
  assert.match(link.message, /الغداء/);
  assert.match(link.message, /بيت العريس/);
  assert.match(link.message, /https:\/\/maps\.app\.goo\.gl\/abc/);
  assert.match(link.message, /قاعة سبأ/);

  const view = await rsvp.getInvitation(tokenOf(link.url));
  assert.equal(view.card?.hostLine, "عبدالرحمن الحمدي");
  assert.equal(view.card?.mapUrl, "https://maps.app.goo.gl/abc");
  assert.equal(view.hostPhrase, "يتشرف عبدالرحمن الحمدي بدعوتكم لحضور");

  // A reminder is the short text with the new link.
  const reminder = await rsvp.createInvitationLink(owner, "guest-1", { reminder: true });
  assert.match(reminder.message, /نذكرك بعرس أحمد يوم 18\/2\/2027/);
  assert.doesNotMatch(reminder.message, /يتشرف/);
  assert.ok(reminder.message.includes(reminder.url));
});

test("the bride's card speaks to women, and a map link must be HTTPS", async () => {
  const db = fakeDatabase();
  const rsvp = service(db, { persona: "BRIDE" });
  await rsvp.setInvitationCard(owner, "plan-1", { hostLine: "أم سلمى" });
  const link = await rsvp.createInvitationLink(owner, "guest-1");
  assert.match(link.message, /تتشرف أم سلمى بدعوتكن لحضور/);

  await assert.rejects(
    rsvp.setInvitationCard(owner, "plan-1", { mapUrl: "http://maps.app.goo.gl/abc" }),
    (error: any) => error?.response?.code === "INVITATION_CARD_MAP_URL_INVALID",
  );
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
    buildRsvpMessage({ guestName: "س", planTitle: "عرس", weddingDate: null, locationLabel: null, url: "https://x/rsvp/t" })
      .includes("الموعد"),
    false,
  );
});
