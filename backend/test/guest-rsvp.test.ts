import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  buildRsvpMessage,
  GuestRsvpService,
  rsvpPublicOrigin,
  rsvpTokenHash,
} from "../src/guests/guest-rsvp.service";
import { assertWeddingPlanWritable } from "../src/modules/collaboration/public/collaboration-permission.port";
import { PublicRsvpController } from "../src/guests/guest-rsvp.controller";
import { renderRsvpPreviewHead } from "../src/guests/rsvp-preview";

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
  return { prisma, guests, eventInvites, cards, notifications, media: [] as any[], signed: [] as any[] };
}

function service(
  db: ReturnType<typeof fakeDatabase>,
  options: {
    contributorOwns?: string[];
    planStatus?: string;
    persona?: string;
    signingFails?: boolean;
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
test("the owner is told once per change of reply, never for the same reply again", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  const token = tokenOf((await rsvp.createInvitationLink(owner, "guest-1")).url);

  await rsvp.respond(token, "CONFIRMED", 2);
  await rsvp.respond(token, "CONFIRMED", 2);
  assert.equal(db.notifications.length, 1, "the same reply again tells nothing new");
  await rsvp.respond(token, "CONFIRMED", 3);
  await rsvp.respond(token, "DECLINED", 0);
  await rsvp.respond(token, "DECLINED", 4); // declining keeps no companions
  assert.equal(db.notifications.length, 3);
  assert.match(db.notifications[2].title.masculine, /اعتذر/);

  await rsvp.respond(token, "DECLINED", 0, "event-lunch");
  await rsvp.respond(token, "DECLINED", 0, "event-lunch");
  assert.equal(db.notifications.length, 4);
  await rsvp.respond(token, "CONFIRMED", 0, "event-lunch");
  assert.equal(db.notifications.length, 5);
  assert.match(db.notifications[4].title.masculine, /أكّد حضوره في الغداء/);
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

// 6b: WhatsApp previews the first link of a text. The guest's own link
// comes first, so the preview is the invitation and not the venue's map.
test("the invitation link comes before the map link in the message", async () => {
  const db = fakeDatabase();
  const rsvp = service(db);
  await rsvp.setInvitationCard(owner, "plan-1", {
    hostLine: "أبو أحمد",
    mapUrl: "https://maps.app.goo.gl/abc",
  });
  const link = await rsvp.createInvitationLink(owner, "guest-1");
  const urls = link.message.match(/https:\/\/\S+/g) ?? [];
  assert.deepEqual(urls, [link.url, "https://maps.app.goo.gl/abc"]);
  // The details still follow the link.
  assert.ok(link.message.indexOf(link.url) < link.message.indexOf("قاعة سبأ"));
  assert.match(link.message, /نرجو تأكيد حضورك من الرابط:\n/);
  // The reminder keeps its short text with the new link last.
  const reminder = await rsvp.createInvitationLink(owner, "guest-1", { reminder: true });
  assert.ok(reminder.message.endsWith(reminder.url));
  assert.doesNotMatch(reminder.message, /maps\.app/);
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
  // A revoked link (a new one replaced it) reads nothing either.
  await rsvp.setInvitationCard(owner, "plan-1", { photoUrl: stored });
  await rsvp.createInvitationLink(owner, "guest-1");
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

// «ذكّر الكل» (2026-11-14): a guest who already confirmed is reminded of the
// day, not asked to answer again.
test("a reminder to a guest who confirmed says the day and keeps the link, without asking for an answer", () => {
  const base = {
    guestName: "مراد",
    planTitle: "عرس أحمد",
    weddingDate: new Date(Date.UTC(2027, 1, 18)),
    locationLabel: null,
    url: "https://x/rsvp/t",
    reminder: true,
  };
  const confirmed = buildRsvpMessage({ ...base, confirmed: true });
  assert.match(confirmed, /نذكرك بعرس أحمد يوم 18\/2\/2027/);
  assert.match(confirmed, /ننتظرك/);
  assert.doesNotMatch(confirmed, /للرد/);
  assert.ok(confirmed.endsWith("https://x/rsvp/t"));

  const pending = buildRsvpMessage(base);
  assert.match(pending, /هذا رابطك الجديد للرد بضغطة:/);
  assert.doesNotMatch(pending, /ننتظرك/);
});

test("a crawler gets this invitation's head; an unknown, revoked or archived link gets none", async () => {
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
  assert.match(preview.description, /18\/2\/2027/);
  assert.match(preview.description, /قاعة سبأ/);
  assert.equal(preview.url, `https://3.121.198.183/rsvp/${token}`);
  assert.deepEqual(preview.image, {
    url: `https://3.121.198.183/api/v1/public/rsvp/${token}/card-photo`,
    type: "image/webp",
  });

  assert.equal(await rsvp.invitationPreview("short"), null);
  assert.equal(await rsvp.invitationPreview("D".repeat(43)), null);
  assert.equal(await service(db, { planStatus: "ARCHIVED" }).invitationPreview(token), null);
  await rsvp.createInvitationLink(owner, "guest-1");
  assert.equal(await rsvp.invitationPreview(token), null, "a replaced link names nobody");

  // Without a photo the head has no image.
  const fresh = fakeDatabase();
  const plain = service(fresh);
  const plainToken = tokenOf((await plain.createInvitationLink(owner, "guest-1")).url);
  const plainPreview = await plain.invitationPreview(plainToken);
  assert.equal(plainPreview?.image, null);
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
  assert.match(head, /<meta name="twitter:card" content="summary_large_image">/);

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
