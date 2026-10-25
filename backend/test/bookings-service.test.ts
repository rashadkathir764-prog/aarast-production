import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { BookingsService } from "../src/marketplace/bookings.service";
import { textFor } from "../src/shared-kernel/voice/address-form";

// Bookings without payment (V1 checklist 4.6), end to end through the
// service on an in-memory database: request, confirm, decline, cancel, the
// provider's calendar, and no double booking.

const customer = { id: "customer-1" } as any;
const stranger = { id: "stranger-1" } as any;
const providerUser = { id: "provider-user-1" } as any;

function fakeDatabase() {
  let sequence = 0;
  const providers = new Map<string, any>([
    [
      "provider-1",
      { id: "provider-1", userId: "provider-user-1", status: "ACTIVE", businessName: "الفنان علي" },
    ],
  ]);
  const quotes = new Map<string, any>();
  const bookings = new Map<string, any>();
  const blocked = new Map<string, any>();
  const offers = new Map<string, any>();
  const notifications: any[] = [];
  const dayKey = (value: Date) => value.toISOString().slice(0, 10);

  const addQuote = (id: string, overrides: Record<string, unknown> = {}) => {
    quotes.set(id, {
      id,
      userId: "customer-1",
      weddingPlanId: "plan-1",
      providerId: "provider-1",
      serviceId: null,
      status: "ACCEPTED",
      eventDate: new Date("2027-02-18T00:00:00Z"),
      contactName: "عريس تجربة",
      guestCount: 200,
      location: null,
      ...overrides,
    });
    offers.set(`offer-${id}`, { id: `offer-${id}`, quoteRequestId: id, status: "ACCEPTED" });
  };

  const bookingMatches = (row: any, where: any) =>
    (!where.id || (typeof where.id === "string" ? row.id === where.id : row.id !== where.id.not)) &&
    (!where.providerId || row.providerId === where.providerId) &&
    (!where.status || row.status === where.status) &&
    (!where.eventDate ||
      (where.eventDate instanceof Date
        ? dayKey(row.eventDate) === dayKey(where.eventDate)
        : where.eventDate.lt
          ? row.eventDate < where.eventDate.lt
          : row.eventDate >= where.eventDate.gte)) &&
    (!where.quoteRequestId || where.quoteRequestId.in.includes(row.quoteRequestId));

  const tx: any = {
    $queryRaw: async (query: { values: unknown[] }) =>
      providers.has(query.values[0] as string) ? [{ id: query.values[0] }] : [],
    provider: {
      findUnique: async ({ where }: any) =>
        where.id
          ? providers.get(where.id) ?? null
          : [...providers.values()].find((row) => row.userId === where.userId) ?? null,
    },
    quoteRequest: {
      findUnique: async ({ where }: any) => {
        const quote = quotes.get(where.id);
        if (!quote) return null;
        return {
          ...quote,
          offers: [...offers.values()].filter(
            (offer) => offer.quoteRequestId === quote.id && offer.status === "ACCEPTED",
          ),
          booking: [...bookings.values()].find((row) => row.quoteRequestId === quote.id) ?? null,
        };
      },
      findMany: async ({ where }: any) =>
        [...quotes.values()].filter(
          (row) => row.userId === where.userId && row.providerId === where.providerId,
        ),
    },
    booking: {
      findUnique: async ({ where }: any) => {
        const row = bookings.get(where.id);
        return row ? { ...row, quoteRequest: quotes.get(row.quoteRequestId) } : null;
      },
      findUniqueOrThrow: async ({ where }: any) => ({ ...bookings.get(where.id) }),
      count: async ({ where }: any) =>
        [...bookings.values()].filter((row) => bookingMatches(row, where)).length,
      upsert: async ({ where, create, update }: any) => {
        const existing = [...bookings.values()].find(
          (row) => row.quoteRequestId === where.quoteRequestId,
        );
        const now = new Date(Date.now() + ++sequence);
        const row = existing
          ? { ...existing, ...update, updatedAt: now }
          : { id: `booking-${sequence}`, createdAt: now, updatedAt: now, ...create };
        bookings.set(row.id, row);
        return row;
      },
      updateMany: async ({ where, data }: any) => {
        const row = bookings.get(where.id);
        if (!row || row.status !== where.status) return { count: 0 };
        bookings.set(row.id, { ...row, ...data, updatedAt: new Date(Date.now() + ++sequence) });
        return { count: 1 };
      },
      findMany: async ({ where }: any) =>
        [...bookings.values()]
          .filter((row) =>
            where.providerId
              ? row.providerId === where.providerId
              : row.status === where.status &&
                row.eventDate >= where.eventDate.gte &&
                row.eventDate <= where.eventDate.lte,
          )
          .map((row) => ({
            ...row,
            quoteRequest: quotes.get(row.quoteRequestId),
            provider: providers.get(row.providerId),
          })),
    },
    providerBlockedDate: {
      findUnique: async ({ where }: any) =>
        blocked.get(`${where.providerId_date.providerId}:${dayKey(where.providerId_date.date)}`) ?? null,
      upsert: async ({ create }: any) => {
        const row = { id: `blocked-${++sequence}`, createdAt: new Date(), ...create };
        blocked.set(`${create.providerId}:${dayKey(create.date)}`, row);
        return row;
      },
      deleteMany: async ({ where }: any) => {
        blocked.delete(`${where.providerId}:${dayKey(where.date)}`);
        return { count: 1 };
      },
      findMany: async ({ where }: any) =>
        [...blocked.values()].filter((row) => row.providerId === where.providerId),
    },
  };
  const prisma: any = {
    ...tx,
    $transaction: async (operation: (client: any) => Promise<unknown>) => operation(tx),
  };
  return { prisma, quotes, bookings, notifications, addQuote, providers };
}

function service(db: ReturnType<typeof fakeDatabase>) {
  const permissions: any = {
    assertPlanReadableInTransaction: async (_tx: unknown, planId: string, user: any) => ({
      plan: { id: planId, ownerUserId: "customer-1", status: "PLANNING" },
      isOwner: user.id === "customer-1",
      sharedMember: null,
    }),
    canManageProviders: () => true,
  };
  const notifications: any = {
    createNotificationInTransaction: async (_tx: unknown, input: any) => {
      db.notifications.push(input);
      return null;
    },
  };
  return new BookingsService(db.prisma, permissions, notifications);
}

async function rejects(promise: Promise<unknown>, code: string) {
  await assert.rejects(promise, (error: any) => error?.response?.code === code);
}

test("a customer asks for the quote's day and the provider is told", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  const bookings = service(db);

  const booking = await bookings.requestBooking(customer, "quote-1", {});

  assert.equal(booking.status, "REQUESTED");
  assert.equal(booking.eventDate, "2027-02-18");
  assert.equal(db.notifications.length, 1);
  assert.equal(db.notifications[0].userId, "provider-user-1");
  // B-19: a booking request is its own type, opening the request.
  assert.equal(db.notifications[0].type, "BOOKING_REQUESTED");
  assert.equal(db.notifications[0].routeTarget, "/provider/requests/quote-1");
});

test("a booking needs an accepted offer and a single open request", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1", { status: "RESPONDED" });
  db.addQuote("quote-2");
  const bookings = service(db);

  await rejects(bookings.requestBooking(customer, "quote-1", {}), "BOOKING_QUOTE_NOT_ACCEPTED");
  await bookings.requestBooking(customer, "quote-2", {});
  await rejects(bookings.requestBooking(customer, "quote-2", {}), "BOOKING_ALREADY_OPEN");
});

test("someone outside the quote cannot book on it", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  await assert.rejects(service(db).requestBooking(stranger, "quote-1", {}), /not found/i);
});

test("the provider confirms, the customer is told, and the day is taken", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  db.addQuote("quote-2", { userId: "customer-2" });
  const bookings = service(db);
  const first = await bookings.requestBooking(customer, "quote-1", {});

  const confirmed = await bookings.decideAsProvider(providerUser, first.id, "CONFIRM", {});
  assert.equal(confirmed.status, "CONFIRMED");
  assert.equal(db.notifications.slice(-1)[0].userId, "customer-1");
  assert.match(db.notifications.slice(-1)[0].title, /^تأكد حجزك مع /);

  // Another customer cannot even ask for a day the provider is confirmed on.
  await rejects(
    bookings.requestBooking({ id: "customer-2" } as any, "quote-2", {}),
    "BOOKING_DATE_UNAVAILABLE",
  );
});

test("two requests for one day: the second confirmation is refused", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  db.addQuote("quote-2");
  const bookings = service(db);
  const first = await bookings.requestBooking(customer, "quote-1", {});
  const second = await bookings.requestBooking(customer, "quote-2", {});

  await bookings.decideAsProvider(providerUser, first.id, "CONFIRM", {});
  await rejects(
    bookings.decideAsProvider(providerUser, second.id, "CONFIRM", {}),
    "BOOKING_DATE_UNAVAILABLE",
  );
});

test("a decline can be followed by a new request for another day", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  const bookings = service(db);
  const first = await bookings.requestBooking(customer, "quote-1", {});

  const declined = await bookings.decideAsProvider(providerUser, first.id, "DECLINE", { note: "مشغول" });
  assert.equal(declined.status, "DECLINED");
  assert.match(db.notifications.slice(-1)[0].title, /^اعتذر .+ عن يوم الخميس 18 فبراير$/);

  const again = await bookings.requestBooking(customer, "quote-1", { eventDate: "2027-02-19" });
  assert.equal(again.id, first.id);
  assert.equal(again.status, "REQUESTED");
  assert.equal(again.eventDate, "2027-02-19");
});

test("the customer cancels and the provider's day frees up", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  const bookings = service(db);
  const first = await bookings.requestBooking(customer, "quote-1", {});
  await bookings.decideAsProvider(providerUser, first.id, "CONFIRM", {});

  const cancelled = await bookings.cancelAsCustomer(customer, first.id, {});
  assert.equal(cancelled.status, "CANCELLED");
  assert.equal(cancelled.cancelledBy, "CUSTOMER");
  assert.equal(db.notifications.slice(-1)[0].userId, "provider-user-1");
  await rejects(
    bookings.decideAsProvider(providerUser, first.id, "CONFIRM", {}),
    "BOOKING_NOT_ALLOWED",
  );
});

test("a blocked day refuses requests and cannot block over a confirmed booking", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  db.addQuote("quote-2", { eventDate: new Date("2027-03-01T00:00:00Z") });
  const bookings = service(db);

  await bookings.blockDate(providerUser, "2027-02-18");
  assert.deepEqual(await bookings.listBlockedDates(providerUser), ["2027-02-18"]);
  await rejects(bookings.requestBooking(customer, "quote-1", {}), "BOOKING_DATE_UNAVAILABLE");

  const booking = await bookings.requestBooking(customer, "quote-2", {});
  await bookings.decideAsProvider(providerUser, booking.id, "CONFIRM", {});
  await rejects(bookings.blockDate(providerUser, "2027-03-01"), "BOOKING_DATE_HAS_BOOKING");

  await bookings.unblockDate(providerUser, "2027-02-18");
  assert.equal((await bookings.requestBooking(customer, "quote-1", {})).status, "REQUESTED");
});

test("a racing confirmation that hits the unique index reads as unavailable", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  const bookings = service(db);
  const first = await bookings.requestBooking(customer, "quote-1", {});
  db.prisma.$transaction = async () => {
    throw new Prisma.PrismaClientKnownRequestError("unique", {
      code: "P2002",
      clientVersion: "test",
    });
  };
  await rejects(
    bookings.decideAsProvider(providerUser, first.id, "CONFIRM", {}),
    "BOOKING_DATE_UNAVAILABLE",
  );
});

// F10: a review needs a confirmed booking whose day has passed.
test("a customer without a completed booking cannot review the provider", async () => {
  const { marketplaceService } = await import("./support/owner-ports");
  const { FinancePortService } = await import(
    "../src/modules/finance/infrastructure/finance-port.service"
  );
  let completedBookings = 0;
  const prisma: any = {
    $transaction: async (operation: (tx: any) => Promise<unknown>) => operation(prisma),
    $queryRaw: async () => [{ id: "11111111-1111-4111-8111-111111111111" }],
    provider: {
      findFirst: async () => ({ id: "11111111-1111-4111-8111-111111111111", userId: "owner", status: "ACTIVE" }),
      findUnique: async () => ({ id: "11111111-1111-4111-8111-111111111111", userId: "owner", status: "ACTIVE" }),
    },
    providerReview: { findUnique: async () => null },
    quoteRequest: { findMany: async () => [{ id: "quote-1" }] },
    booking: { count: async () => completedBookings },
  };
  const marketplace = marketplaceService(prisma, {} as any, {} as any, {} as any, new FinancePortService());

  await assert.rejects(
    marketplace.createReview(customer, "11111111-1111-4111-8111-111111111111", { rating: 5 } as any),
    (error: any) => error?.response?.code === "REVIEW_REQUIRES_COMPLETED_BOOKING",
  );
});

test("a confirmed booking reminds both sides a week and a day before, once each", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  const sent = new Set<string>();
  const bookings = new BookingsService(
    db.prisma,
    {
      assertPlanReadableInTransaction: async (_tx: unknown, planId: string) => ({
        plan: { id: planId, ownerUserId: "customer-1", status: "PLANNING" },
        isOwner: true,
        sharedMember: null,
      }),
      canManageProviders: () => true,
    } as any,
    {
      // The real notifications row is unique on its dedupe key.
      createNotificationInTransaction: async (_tx: unknown, input: any) => {
        if (sent.has(input.dedupeKey)) {
          throw new Prisma.PrismaClientKnownRequestError("dup", {
            code: "P2002",
            clientVersion: "test",
          });
        }
        sent.add(input.dedupeKey);
        db.notifications.push(input);
        return { id: input.dedupeKey };
      },
    } as any,
  );
  const requested = await bookings.requestBooking(customer, "quote-1", {});
  await bookings.decideAsProvider(providerUser, requested.id, "CONFIRM", {});
  db.notifications.length = 0;

  // The booking day is 2027-02-18 (Yemen time).
  const at = (day: string) => new Date(`${day}T09:00:00Z`);
  assert.deepEqual(await bookings.sendDueReminders(at("2027-02-01")), { sent: 0, failures: [] });

  const week = await bookings.sendDueReminders(at("2027-02-11"));
  assert.equal(week.sent, 2);
  assert.deepEqual(db.notifications.map((n) => n.userId).sort(), ["customer-1", "provider-user-1"]);
  // B5: the customer's line comes in both forms; the writer picks hers.
  // B-38: how far and the day in words (no «2027-02-18»).
  assert.match(textFor("MASCULINE", db.notifications[0].title), /بعد 7 أيام$/);
  assert.match(textFor("MASCULINE", db.notifications[0].body), /^يوم الخميس 18 فبراير\. تواصل معه/);
  assert.match(textFor("FEMININE", db.notifications[0].body), /^يوم الخميس 18 فبراير\. تواصلي معه/);

  // The next hourly scans inside the same window send nothing again.
  assert.equal((await bookings.sendDueReminders(at("2027-02-12"))).sent, 0);

  const dayBefore = await bookings.sendDueReminders(at("2027-02-17"));
  assert.equal(dayBefore.sent, 2);
  assert.match(textFor("MASCULINE", db.notifications.slice(-1)[0].title), /بكرة$/);
  assert.equal(db.notifications.slice(-1)[0].priority, "HIGH");

  // The day itself and after: nothing.
  assert.equal((await bookings.sendDueReminders(at("2027-02-18"))).sent, 0);
});

test("a cancelled booking is not reminded", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  const bookings = service(db);
  const requested = await bookings.requestBooking(customer, "quote-1", {});
  await bookings.decideAsProvider(providerUser, requested.id, "CONFIRM", {});
  await bookings.cancelAsCustomer(customer, requested.id, {});
  db.notifications.length = 0;

  const result = await bookings.sendDueReminders(new Date("2027-02-17T09:00:00Z"));
  assert.equal(result.sent, 0);
  assert.equal(db.notifications.length, 0);
});
