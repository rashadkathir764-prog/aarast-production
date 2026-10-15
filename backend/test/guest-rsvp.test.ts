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
  const notifications: any[] = [];
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
  };
  const prisma: any = {
    ...tx,
    $transaction: async (operation: (client: any) => Promise<unknown>) => operation(tx),
  };
  return { prisma, guests, notifications };
}

function service(
  db: ReturnType<typeof fakeDatabase>,
  options: { contributorOwns?: string[]; planStatus?: string } = {},
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
      status: options.planStatus ?? "PLANNING",
      weddingDate: new Date("2027-02-18T00:00:00Z"),
      city: null,
      location: { governorate: "أمانة العاصمة", cityOrDistrict: "شعوب" },
    }),
  };
  const notifications: any = {
    createNotificationInTransaction: async (_tx: unknown, input: any) => {
      db.notifications.push(input);
      return null;
    },
  };
  return new GuestRsvpService(db.prisma, permissions, scope, plans, notifications);
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
  assert.match(db.notifications[0].body, /ومعه 2/);

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

test("the link origin must be HTTPS", () => {
  assert.equal(rsvpPublicOrigin({ INVITE_PUBLIC_ORIGIN: "https://example.org/x" }), "https://example.org");
  assert.throws(() => rsvpPublicOrigin({ INVITE_PUBLIC_ORIGIN: "http://example.org" }));
  assert.equal(
    buildRsvpMessage({ guestName: "س", planTitle: "عرس", weddingDate: null, locationLabel: null, url: "https://x/rsvp/t" })
      .includes("الموعد"),
    false,
  );
});
