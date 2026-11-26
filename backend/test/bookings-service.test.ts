import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { BookingsService } from "../src/marketplace/bookings.service";
import { withProviderUpdateFanOut } from "./support/owner-ports";
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
  // Q-55 (أ): the agreement each accepted offer put in the money, by offer.
  const agreements = new Map<string, any>();
  const agreementWrites: any[] = [];
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
    offers.set(`offer-${id}`, {
      id: `offer-${id}`,
      quoteRequestId: id,
      providerId: "provider-1",
      status: "ACCEPTED",
      amount: new Prisma.Decimal(550000),
      currency: "YER",
    });
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
              ? row.providerId === where.providerId &&
                (!where.status || row.status === where.status) &&
                (!where.eventDate ||
                  ((!where.eventDate.gte || row.eventDate >= where.eventDate.gte) &&
                    (!where.eventDate.lt || row.eventDate < where.eventDate.lt)))
              : row.status === where.status &&
                row.eventDate >= where.eventDate.gte &&
                row.eventDate <= where.eventDate.lte,
          )
          .map((row) => ({
            ...row,
            quoteRequest: quotes.get(row.quoteRequestId),
            quoteOffer: row.quoteOfferId ? (offers.get(row.quoteOfferId) ?? null) : null,
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
    // RA-BE-48: a booking asked again closes any change left waiting.
    bookingChange: {
      updateMany: async () => ({ count: 0 }),
    },
    // The accepted offer as its agreement reads it (Q-55).
    quoteOffer: {
      findUnique: async ({ where }: any) => {
        const offer = offers.get(where.id);
        if (!offer) return null;
        const provider = providers.get(offer.providerId);
        return {
          ...offer,
          quoteRequest: { ...quotes.get(offer.quoteRequestId), service: null },
          provider: {
            businessName: provider.businessName,
            userId: provider.userId,
            primaryCategoryId: "category-photo",
          },
          providerLinks: [],
        };
      },
    },
  };
  const prisma: any = {
    ...tx,
    $transaction: async (operation: (client: any) => Promise<unknown>) => operation(tx),
  };
  // Finance's port as the bookings read and write it: no agreement is
  // listed for B-18 here (tested on its own), and the agreement an accepted
  // offer makes is kept by offer (WeddingCost.quoteOfferId is unique).
  const finance: any = {
    listCostsForOffers: async () => [],
    markOfferBookingFellThrough: async () => 0,
    findCostForAcceptedOffer: async (_tx: unknown, offerId: string) =>
      agreements.get(offerId) ?? null,
    createCostFromAcceptedOffer: async (_tx: unknown, input: any) => {
      if (agreements.has(input.quoteOfferId)) throw new Error("P2002 quoteOfferId");
      agreementWrites.push(input);
      const cost = {
        id: `cost-${input.quoteOfferId}`,
        weddingPlanId: input.weddingPlanId,
        providerId: input.providerId,
        quoteOfferId: input.quoteOfferId,
        title: input.title,
        totalAmount: input.amount,
        paidAmount: new Prisma.Decimal(0),
        status: "OPEN",
        createdAt: new Date(),
        budgetCategory: { name: input.providerCategoryName ?? "أخرى" },
      };
      agreements.set(input.quoteOfferId, cost);
      return cost;
    },
  };
  // The plan's currency and the offer's category, as marketplace's
  // relations attach them from planning and catalog.
  const relations: any = {
    attachOfferContext: async (_tx: unknown, offer: any) => ({
      ...offer,
      quoteRequest: {
        ...offer.quoteRequest,
        weddingPlan: { id: offer.quoteRequest.weddingPlanId, currency: "YER" },
        service: null,
      },
    }),
    offerCategory: async () => ({ nameAr: "التصوير", slug: "photography" }),
  };
  return {
    prisma,
    quotes,
    bookings,
    notifications,
    addQuote,
    providers,
    offers,
    agreements,
    agreementWrites,
    finance,
    relations,
  };
}

function service(
  db: ReturnType<typeof fakeDatabase>,
  { managesMoney = true, history }: { managesMoney?: boolean; history?: any } = {},
) {
  const permissions: any = {
    assertPlanReadableInTransaction: async (_tx: unknown, planId: string, user: any) => ({
      plan: { id: planId, ownerUserId: "customer-1", status: "PLANNING", persona: "GROOM" },
      isOwner: user.id === "customer-1",
      sharedMember: null,
    }),
    canManageProviders: () => true,
    canManageMoney: () => managesMoney,
  };
  const notifications: any = {
    createNotificationInTransaction: async (_tx: unknown, input: any) => {
      db.notifications.push(input);
      return null;
    },
  };
  return new BookingsService(
    db.prisma,
    permissions,
    withProviderUpdateFanOut(notifications),
    db.finance,
    undefined,
    undefined,
    undefined,
    undefined,
    db.relations,
    history,
  );
}

/** No customer keeps an agreement for these offers (B-18 is tested on its own). */
const noAgreements: any = {
  listCostsForOffers: async () => [],
  markOfferBookingFellThrough: async () => 0,
};

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

// Q-55 (أ), D127: choosing an offer writes nothing in the money; asking for
// the booking puts the offer's agreement there, once per offer.
test("Q-55: asking for the booking writes the offer's agreement in the money, once", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  const recorded: any[] = [];
  const history = {
    recordForContextInTransaction: async (_tx: unknown, _context: unknown, input: any) => {
      recorded.push(input);
      return null;
    },
  };
  const bookings = service(db, { history });

  const first = await bookings.requestBooking(customer, "quote-1", {});
  assert.equal(db.agreementWrites.length, 1);
  const written = db.agreementWrites[0];
  assert.equal(written.weddingPlanId, "plan-1");
  assert.equal(written.providerId, "provider-1");
  assert.equal(written.quoteOfferId, "offer-quote-1");
  assert.equal(written.amount.toString(), "550000");
  // No service named: the provider's name and his own category.
  assert.equal(written.title, "الفنان علي");
  assert.equal(written.providerCategoryName, "التصوير");
  assert.equal(written.providerCategorySlug, "photography");
  assert.equal(written.planPersona, "GROOM");
  // The money's history says the agreement came in, once.
  const money = recorded.filter((input) => input.section === "MONEY");
  assert.equal(money.length, 1);
  assert.equal(money[0].entityId, "cost-offer-quote-1");
  assert.equal(money[0].action, "CREATED");

  // Declined, then asked again: the agreement there is the one kept.
  await bookings.decideAsProvider(providerUser, first.id, "DECLINE", {});
  await bookings.requestBooking(customer, "quote-1", { eventDate: "2027-02-19" });
  assert.equal(db.agreementWrites.length, 1, "a request asked again writes no second agreement");
  assert.equal(recorded.filter((input) => input.section === "MONEY").length, 1);
});

test("Q-55: an agreement an older acceptance already wrote is left as it is", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  db.agreements.set("offer-quote-1", { id: "cost-old", quoteOfferId: "offer-quote-1" });

  const booking = await service(db).requestBooking(customer, "quote-1", {});
  assert.equal(booking.status, "REQUESTED");
  assert.equal(db.agreementWrites.length, 0);
  assert.equal(db.agreements.get("offer-quote-1").id, "cost-old");
});

// Q-65 (أ), D127: the request puts an agreement in the money, so it takes
// the money right; a helper without it is told who can, and nothing moves.
test("Q-65: a member without the money right cannot ask for the booking", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");

  await assert.rejects(
    service(db, { managesMoney: false }).requestBooking(customer, "quote-1", {}),
    (error: any) =>
      error?.getStatus?.() === 403 &&
      error?.response?.code === "BOOKING_NEEDS_MONEY_RIGHT" &&
      /صاحب الخطة/.test(error.response.message),
  );
  assert.equal(db.bookings.size, 0);
  assert.equal(db.agreementWrites.length, 0);
  assert.equal(db.notifications.length, 0);
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

test("RA-BE-47: the provider cannot confirm a booking on a plan that was archived", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  const first = await service(db).requestBooking(customer, "quote-1", {});
  // The couple archived the plan after asking; the request still waited.
  let planStatus = "ARCHIVED";
  const plans: any = {
    lockPlanRowForShareInTransaction: async () => [{ id: "plan-1" }],
    getPlan: async () => ({ id: "plan-1", ownerUserId: "customer-1", status: planStatus }),
  };
  const permissions: any = {
    assertPlanReadableInTransaction: async () => ({
      plan: { id: "plan-1", ownerUserId: "customer-1", status: "PLANNING" },
      isOwner: true,
      sharedMember: null,
    }),
    canManageProviders: () => true,
  };
  const notifications: any = withProviderUpdateFanOut({ createNotificationInTransaction: async () => null });
  const bookings = new BookingsService(
    db.prisma,
    permissions,
    notifications,
    noAgreements,
    undefined,
    undefined,
    plans,
  );

  await rejects(
    bookings.decideAsProvider(providerUser, first.id, "CONFIRM", {}),
    "BOOKING_PLAN_ARCHIVED",
  );
  assert.equal(db.bookings.get(first.id)?.status, "REQUESTED");
  // Declining stays open, so the provider can answer the request.
  planStatus = "ARCHIVED";
  const declined = await bookings.decideAsProvider(providerUser, first.id, "DECLINE", { note: "انلغى" });
  assert.equal(declined.status, "DECLINED");
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

  // B-20: one wedding a day by default; another customer cannot even ask
  // for the day once it is full.
  await rejects(
    bookings.requestBooking({ id: "customer-2" } as any, "quote-2", {}),
    "BOOKING_DAY_FULL",
  );
});

test("two requests for one day: the second confirmation is refused (the day is full)", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  db.addQuote("quote-2");
  const bookings = service(db);
  const first = await bookings.requestBooking(customer, "quote-1", {});
  const second = await bookings.requestBooking(customer, "quote-2", {});

  await bookings.decideAsProvider(providerUser, first.id, "CONFIRM", {});
  await rejects(
    bookings.decideAsProvider(providerUser, second.id, "CONFIRM", {}),
    "BOOKING_DAY_FULL",
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

// B-20: the old one-a-day unique index (and its P2002 mapping) is gone; the
// count under the provider's row lock is the guard. Its race on a real
// database is in `scripts/smoke/booking-smoke.ts`.
test("a day takes the provider's number of confirmations, and a lowered number keeps them", async () => {
  const db = fakeDatabase();
  db.providers.get("provider-1").dailyBookingCapacity = 2;
  for (const id of ["quote-1", "quote-2", "quote-3"]) db.addQuote(id);
  const bookings = service(db);
  const [a, b, c] = [
    await bookings.requestBooking(customer, "quote-1", {}),
    await bookings.requestBooking(customer, "quote-2", {}),
    await bookings.requestBooking(customer, "quote-3", {}),
  ];

  await bookings.decideAsProvider(providerUser, a.id, "CONFIRM", {});
  await bookings.decideAsProvider(providerUser, b.id, "CONFIRM", {});
  await rejects(bookings.decideAsProvider(providerUser, c.id, "CONFIRM", {}), "BOOKING_DAY_FULL");

  // He lowers it to one: both confirmed bookings stay, the day stays full.
  db.providers.get("provider-1").dailyBookingCapacity = 1;
  assert.equal(db.bookings.get(a.id).status, "CONFIRMED");
  assert.equal(db.bookings.get(b.id).status, "CONFIRMED");
  await rejects(bookings.decideAsProvider(providerUser, c.id, "CONFIRM", {}), "BOOKING_DAY_FULL");

  // A cancellation frees a seat only once the count is under the number.
  await bookings.cancelAsCustomer(customer, a.id, {});
  await rejects(bookings.decideAsProvider(providerUser, c.id, "CONFIRM", {}), "BOOKING_DAY_FULL");
  await bookings.cancelAsCustomer(customer, b.id, {});
  assert.equal(
    (await bookings.decideAsProvider(providerUser, c.id, "CONFIRM", {})).status,
    "CONFIRMED",
  );
});

test("a suspended provider confirms nothing and closes no day", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  db.addQuote("quote-2");
  const bookings = service(db);
  const first = await bookings.requestBooking(customer, "quote-1", {});
  db.providers.get("provider-1").status = "SUSPENDED";

  await rejects(
    bookings.decideAsProvider(providerUser, first.id, "CONFIRM", {}),
    "PROVIDER_NOT_ACTIVE",
  );
  await rejects(bookings.blockDate(providerUser, "2027-03-01"), "PROVIDER_NOT_ACTIVE");
  await rejects(bookings.requestBooking(customer, "quote-2", {}), "PROVIDER_NOT_ACTIVE");
});

test("the provider reads agreed, paid and left on his booking, and the month's totals per currency", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  db.offers.get("offer-quote-1").currency = "YER";
  const finance: any = {
    listCostsForOffers: async (_client: unknown, ids: string[]) =>
      ids.includes("offer-quote-1")
        ? [
            {
              id: "cost-1",
              quoteOfferId: "offer-quote-1",
              budgetCategoryId: "item-1",
              totalAmount: new Prisma.Decimal(550000),
              paidAmount: new Prisma.Decimal(100000),
              status: "PARTIALLY_PAID",
              lastPaidAt: new Date("2026-12-12T10:00:00Z"),
            },
          ]
        : [],
    markOfferBookingFellThrough: async () => 1,
    // The customer's agreement for this offer is already in his money.
    findCostForAcceptedOffer: async () => ({ id: "cost-1" }),
  };
  const bookings = new BookingsService(
    db.prisma,
    { assertPlanReadableInTransaction: async () => ({ plan: { id: "plan-1", status: "PLANNING" }, isOwner: true, sharedMember: null }), canManageProviders: () => true, canManageMoney: () => true } as any,
    withProviderUpdateFanOut({ createNotificationInTransaction: async () => null }) as any,
    finance,
    undefined,
    undefined,
    undefined,
    undefined,
    db.relations,
  );
  const requested = await bookings.requestBooking(customer, "quote-1", {});
  await bookings.decideAsProvider(providerUser, requested.id, "CONFIRM", {});

  const ledger = await bookings.ledgerForProvider(providerUser, "2027-02");
  assert.deepEqual(ledger.totals, [
    { currency: "YER", agreed: "550000.00", paid: "100000.00", left: "450000.00", bookings: 1 },
  ]);
  assert.deepEqual(ledger.bookings[0].money, {
    agreed: "550000.00",
    paid: "100000.00",
    left: "450000.00",
    currency: "YER",
    lastPaidAt: new Date("2026-12-12T10:00:00Z"),
  });
  // Only the three totals: no payment, payer, receipt or note.
  assert.deepEqual(Object.keys(ledger.bookings[0].money!).sort(), [
    "agreed",
    "currency",
    "lastPaidAt",
    "left",
    "paid",
  ]);
  assert.deepEqual((await bookings.ledgerForProvider(providerUser, "2027-03")).totals, []);
  await rejects(bookings.ledgerForProvider(providerUser, "2027-13"), "LEDGER_INVALID_MONTH");
});

// F10: a review needs a confirmed booking whose day has passed.
test("a customer without a completed booking cannot review the provider", async () => {
  const { marketplaceService, catalogWithoutMoneyLinks } = await import("./support/owner-ports");
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
  const marketplace = marketplaceService(prisma, {} as any, {} as any, {} as any, new FinancePortService(catalogWithoutMoneyLinks));

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
      canManageMoney: () => true,
    } as any,
    withProviderUpdateFanOut({
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
    }) as any,
    db.finance,
    undefined,
    undefined,
    undefined,
    undefined,
    db.relations,
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
  assert.match(textFor("MASCULINE", db.notifications.slice(-1)[0].title), /غدًا$/);
  assert.equal(db.notifications.slice(-1)[0].priority, "HIGH");

  // The day itself and after: nothing.
  assert.equal((await bookings.sendDueReminders(at("2027-02-18"))).sent, 0);
});

// M-2 (Q-45, D124): a plan the owner asked to delete is closed; its bookings are not reminded.
test("a booking whose plan is pending deletion is not reminded, and is again once he takes it back", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  const base = service(db);
  const requested = await base.requestBooking(customer, "quote-1", {});
  await base.decideAsProvider(providerUser, requested.id, "CONFIRM", {});
  db.notifications.length = 0;

  let deletionRequestedAt: Date | null = new Date("2027-02-10T00:00:00Z");
  const plans: any = {
    getPlan: async () => ({ id: "plan-1", ownerUserId: "customer-1", status: "PLANNING", deletionRequestedAt }),
  };
  const permissions: any = { canManageProviders: () => true };
  const notifications: any = {
    createNotificationInTransaction: async (_tx: unknown, input: any) => {
      db.notifications.push(input);
      return { id: input.dedupeKey };
    },
  };
  const bookings = new BookingsService(
    db.prisma, permissions, withProviderUpdateFanOut(notifications), noAgreements, undefined, undefined, plans,
  );

  const week = await bookings.sendDueReminders(new Date("2027-02-11T09:00:00Z"));
  assert.deepEqual(week, { sent: 0, failures: [] });
  assert.equal(db.notifications.length, 0);

  deletionRequestedAt = null;
  assert.equal((await bookings.sendDueReminders(new Date("2027-02-11T10:00:00Z"))).sent, 2);
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

// RA-BE-138 (Q-34 (ب)): the item an accepted offer made stays when the
// provider declines or cancels; it is marked for «يحتاج انتباهك», the notice
// says so, and asking again or a confirmation clears the mark.
test("RA-BE-138: a provider's decline keeps the item, marks it and says so; asking again clears it", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  const marks: Array<[string, Date | null]> = [];
  const finance: any = {
    listCostsForOffers: async () => [],
    markOfferBookingFellThrough: async (_tx: unknown, offerId: string, at: Date | null) => {
      marks.push([offerId, at]);
      return 1;
    },
    // The item the offer made is in the money (Q-55: since the request).
    findCostForAcceptedOffer: async () => ({ id: "cost-1" }),
  };
  const permissions: any = {
    assertPlanReadableInTransaction: async (_tx: unknown, planId: string) => ({
      plan: { id: planId, ownerUserId: "customer-1", status: "PLANNING" },
      isOwner: true,
      sharedMember: null,
    }),
    canManageProviders: () => true,
    canManageMoney: () => true,
  };
  const notifications: any = {
    createNotificationInTransaction: async (_tx: unknown, input: any) => {
      db.notifications.push(input);
      return null;
    },
  };
  const bookings = new BookingsService(
    db.prisma,
    permissions,
    withProviderUpdateFanOut(notifications),
    finance,
    undefined,
    undefined,
    undefined,
    undefined,
    db.relations,
  );
  const first = await bookings.requestBooking(customer, "quote-1", {});
  const offerId = db.bookings.get(first.id)!.quoteOfferId;
  assert.deepEqual(marks, [[offerId, null]], "a request is a live item again");

  await bookings.decideAsProvider(providerUser, first.id, "DECLINE", { note: "مشغول" });
  assert.equal(marks.length, 2);
  assert.equal(marks[1][0], offerId);
  assert.ok(marks[1][1] instanceof Date);
  const notice = db.notifications.slice(-1)[0];
  assert.match(notice.body.masculine, /بنده باقي في «اتفقت على»/);
  assert.match(notice.body.feminine, /احذفيه/);

  await bookings.requestBooking(customer, "quote-1", { eventDate: "2027-02-19" });
  assert.deepEqual(marks[2], [offerId, null]);
  await bookings.decideAsProvider(providerUser, first.id, "CONFIRM", {});
  assert.deepEqual(marks[3], [offerId, null]);
  await bookings.decideAsProvider(providerUser, first.id, "CANCEL", {});
  assert.ok(marks[4][1] instanceof Date, "a provider's cancel marks it too");
  assert.match(db.notifications.slice(-1)[0].body.masculine, /بنده باقي/);
});

test("RA-BE-138: a decline with no item left says nothing of money", async () => {
  const db = fakeDatabase();
  db.addQuote("quote-1");
  const bookings = service(db);
  const first = await bookings.requestBooking(customer, "quote-1", {});
  await bookings.decideAsProvider(providerUser, first.id, "DECLINE", {});
  assert.doesNotMatch(JSON.stringify(db.notifications.slice(-1)[0].body), /بنده/);
});

// RA-MO-338 (Q-51 (أ), D80): every participant reads all of the plan's
// bookings, without amounts; confirming and cancelling stay with whoever
// may act on the request (the owner and partner, or the member who asked).
test("RA-MO-338: every participant reads the plan's bookings; acting stays with the request's side", async () => {
  const row = (id: string, userId: string) => ({
    id,
    quoteRequestId: `quote-${id}`,
    quoteOfferId: `offer-${id}`,
    providerId: "provider-1",
    eventDate: new Date("2099-02-18T00:00:00Z"),
    status: "CONFIRMED",
    cancelledBy: null,
    note: "رقم القاعة عند أبوي",
    confirmedAt: new Date(0),
    declinedAt: null,
    cancelledAt: null,
    createdAt: new Date(0),
    updatedAt: new Date(0),
    changes: [],
    quoteRequest: { userId, weddingPlanId: "plan-1", contactName: "x" },
    provider: { businessName: id === "owners" ? "قاعة السعادة" : "الفنان علي" },
  });
  const rows = [row("owners", "owner-1"), row("helpers", "helper-1")];
  const db: any = {
    booking: { findMany: async () => rows },
  };
  db.$transaction = async (operation: any) => operation(db);
  const readAs = (manages: boolean, owner: boolean) =>
    new BookingsService(
      db,
      {
        assertPlanReadableInTransaction: async () => ({
          plan: { id: "plan-1", ownerUserId: "owner-1", status: "PLANNING" },
          isOwner: owner,
          sharedMember: owner ? null : { role: manages ? "HELPER" : "VIEWER" },
        }),
        canManageProviders: () => manages,
      } as any,
      {} as any,
      noAgreements,
    );

  const helper = await readAs(true, false).listForPlan({ id: "helper-1" } as any, "plan-1");
  assert.deepEqual(
    helper.map((booking: any) => [booking.providerName, booking.canAct]),
    [["قاعة السعادة", false], ["الفنان علي", true]],
  );
  // Another's booking is read without its note, links or offer.
  assert.equal("note" in helper[0], false);
  assert.equal("quoteOfferId" in helper[0], false);
  assert.equal((helper[1] as any).note, "رقم القاعة عند أبوي");

  const viewer = await readAs(false, false).listForPlan({ id: "viewer-1" } as any, "plan-1");
  assert.deepEqual(
    viewer.map((booking: any) => [booking.providerName, booking.status, booking.canAct]),
    [["قاعة السعادة", "CONFIRMED", false], ["الفنان علي", "CONFIRMED", false]],
  );

  const owner = await readAs(true, true).listForPlan({ id: "owner-1" } as any, "plan-1");
  assert.deepEqual(owner.map((booking: any) => booking.canAct), [true, true]);
});
