import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  ConversationScope,
  PrismaClient,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from "@prisma/client";
import { BookingsService } from "../../src/marketplace/bookings.service";
import { bookingToday } from "../../src/marketplace/booking-policy";
import { MarketplaceAdminService } from "../../src/modules/marketplace/internal/marketplace-admin.service";
import * as core from "../../src/modules/marketplace/infrastructure/marketplace-core.repository";
import * as dashboardStore from "../../src/modules/marketplace/infrastructure/provider-dashboard.repository";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { ownerPorts } from "./support/owner-ports";

// Bookings without payment (V1 checklist 4.6) on a real database: requests,
// the provider's decisions, the calendar, and the provider's daily number
// (B-20): racing confirmations counted under his row lock never pass it.

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const label = `Booking smoke ${runId}`;

function passwordHash(value: string): string {
  return createHash("sha256").update(`${runId}:${value}`).digest("hex");
}

function code(error: any): string | undefined {
  return error?.response?.code;
}

async function main(): Promise<void> {
  const city = await prisma.city.create({
    data: { nameAr: label, countryCode: "ZZ", isActive: true },
  });
  const [providerUser, customerA, customerB] = await Promise.all(
    ["provider", "customer-a", "customer-b"].map((name) =>
      prisma.user.create({
        data: { name: `${label} ${name}`, passwordHash: passwordHash(name) },
      }),
    ),
  );
  const provider = await prisma.provider.create({
    data: {
      userId: providerUser.id,
      cityId: city.id,
      businessName: `${label} provider`,
      phone: `booking-${runId}`.slice(0, 30),
      status: ProviderStatus.ACTIVE,
    },
  });

  async function acceptedQuote(userId: string, eventDate: string) {
    // One account conversation per customer and provider.
    const conversation =
      (await prisma.conversation.findFirst({
        where: { accountRequesterUserId: userId, providerId: provider.id },
      })) ??
      (await prisma.conversation.create({
        data: {
          scope: ConversationScope.ACCOUNT,
          accountRequesterUserId: userId,
          providerId: provider.id,
          createdByUserId: userId,
        },
      }));
    const quote = await prisma.quoteRequest.create({
      data: {
        userId,
        providerId: provider.id,
        conversationId: conversation.id,
        status: QuoteRequestStatus.ACCEPTED,
        acceptedAt: new Date(),
        eventDate: new Date(`${eventDate}T00:00:00Z`),
        contactName: "عريس تجربة",
      },
    });
    await prisma.quoteOffer.create({
      data: {
        quoteRequestId: quote.id,
        providerId: provider.id,
        amount: "400000",
        status: QuoteOfferStatus.ACCEPTED,
      },
    });
    return quote;
  }

  const notifications: any[] = [];
  const bookings = new BookingsService(
    prisma as any,
    new PermissionService(prisma as any, ownerPorts.plans),
    {
      createNotificationInTransaction: async (_tx: unknown, input: any) => {
        notifications.push(input);
        return null;
      },
    } as any,
    ownerPorts.finance,
  );

  let planId: string | null = null;
  try {
    const quoteA = await acceptedQuote(customerA.id, "2027-02-18");
    const quoteB = await acceptedQuote(customerB.id, "2027-02-18");

    const bookingA = await bookings.requestBooking(customerA as any, quoteA.id, {});
    const bookingB = await bookings.requestBooking(customerB as any, quoteB.id, {});
    assert.equal(bookingA.status, "REQUESTED");
    assert.equal(bookingA.eventDate, "2027-02-18");
    assert.equal(notifications.filter((item) => item.userId === providerUser.id).length, 2);
    console.log("PASS - two customers can ask for the same day");

    await assert.rejects(
      bookings.requestBooking(customerB as any, quoteA.id, {}),
      /not found/i,
    );
    console.log("PASS - a customer cannot book on another customer's quote");

    const listed = await bookings.listForProvider(providerUser as any);
    assert.deepEqual(
      listed.map((item) => item.id).sort(),
      [bookingA.id, bookingB.id].sort(),
    );
    assert.equal(listed[0].customerName, "عريس تجربة");
    console.log("PASS - the provider lists both requests with the customer's name");

    const results = await Promise.allSettled([
      bookings.decideAsProvider(providerUser as any, bookingA.id, "CONFIRM", {}),
      bookings.decideAsProvider(providerUser as any, bookingB.id, "CONFIRM", {}),
    ]);
    const confirmed = results.filter((result) => result.status === "fulfilled");
    const refused = results.filter((result) => result.status === "rejected");
    assert.equal(confirmed.length, 1);
    assert.equal(refused.length, 1);
    assert.equal(code((refused[0] as PromiseRejectedResult).reason), "BOOKING_DAY_FULL");
    const confirmedRows = await prisma.booking.count({
      where: { providerId: provider.id, status: "CONFIRMED" },
    });
    assert.equal(confirmedRows, 1);
    console.log("PASS - two racing confirmations for a one-wedding day: exactly one wins (no unique index)");

    const winner = (confirmed[0] as PromiseFulfilledResult<any>).value;
    const loserId = winner.id === bookingA.id ? bookingB.id : bookingA.id;
    const loserQuote = winner.id === bookingA.id ? quoteB : quoteA;
    const loserUser = winner.id === bookingA.id ? customerB : customerA;
    const declined = await bookings.decideAsProvider(
      providerUser as any,
      loserId,
      "DECLINE",
      { note: "اليوم محجوز" },
    );
    assert.equal(declined.status, "DECLINED");
    const reopened = await bookings.requestBooking(loserUser as any, loserQuote.id, {
      eventDate: "2027-02-19",
    });
    assert.equal(reopened.id, loserId);
    assert.equal(reopened.status, "REQUESTED");
    console.log("PASS - a declined customer asks again for another day");

    await bookings.blockDate(providerUser as any, "2027-03-01");
    assert.deepEqual(await bookings.listBlockedDates(providerUser as any), ["2027-03-01"]);
    await assert.rejects(
      bookings.blockDate(providerUser as any, "2027-02-18"),
      (error: any) => code(error) === "BOOKING_DATE_HAS_BOOKING",
    );
    const quoteC = await acceptedQuote(customerA.id, "2027-03-01");
    await assert.rejects(
      bookings.requestBooking(customerA as any, quoteC.id, {}),
      (error: any) => code(error) === "BOOKING_DATE_UNAVAILABLE",
    );
    await bookings.unblockDate(providerUser as any, "2027-03-01");
    assert.equal(
      (await bookings.requestBooking(customerA as any, quoteC.id, {})).status,
      "REQUESTED",
    );
    console.log("PASS - a blocked day refuses requests until it is unblocked");

    // A week before the confirmed day both sides are reminded; two days
    // before it is outside every window (V1 checklist 4.17).
    const remindedBefore = notifications.length;
    await bookings.sendDueReminders(new Date("2027-02-11T09:00:00Z"));
    const reminders = notifications
      .slice(remindedBefore)
      .filter((item) => item.data?.bookingId === winner.id);
    assert.deepEqual(
      reminders.map((item) => item.data.recipientAudience).sort(),
      ["CUSTOMER", "PROVIDER"],
    );
    assert.ok(reminders.every((item) => item.dedupeKey.endsWith(":REMINDER:7:2027-02-18")));
    const outside = notifications.length;
    await bookings.sendDueReminders(new Date("2027-02-05T09:00:00Z"));
    assert.equal(
      notifications.slice(outside).filter((item) => item.data?.bookingId === winner.id).length,
      0,
    );
    console.log("PASS - a confirmed booking is reminded a week before, on both sides");

    // The provider's stats (V1 checklist 4.19): concurrent first views of a
    // day add up in one row; an unknown provider counts nothing.
    const today = new Date().toISOString().slice(0, 10);
    await Promise.all(
      [1, 2, 3].map(() => core.recordProviderProfileView(prisma as any, provider.id, today)),
    );
    assert.equal(
      await core.recordProviderProfileView(prisma as any, "00000000-0000-4000-8000-000000000000", today),
      0,
    );
    const [views, requested, accepted, decided, upcoming, completed] =
      await dashboardStore.providerActivity(
        prisma as any,
        provider.id,
        new Date(Date.now() - 24 * 60 * 60 * 1000),
        new Date(`${today}T00:00:00Z`),
      );
    assert.equal(views._sum.views, 3);
    assert.equal(requested, 3);
    assert.equal(accepted, 3);
    assert.equal(decided, 3);
    assert.equal(upcoming, 1);
    assert.equal(completed, 0);
    console.log("PASS - provider stats: views add up per day, with requests, offers and bookings");

    const cancelled = await bookings.cancelAsCustomer(
      (winner.id === bookingA.id ? customerA : customerB) as any,
      winner.id,
      {},
    );
    assert.equal(cancelled.status, "CANCELLED");
    assert.equal(cancelled.cancelledBy, "CUSTOMER");
    await bookings.blockDate(providerUser as any, "2027-02-18");
    console.log("PASS - a cancelled booking frees the provider's day");

    // A plan's bookings (V1 checklist 4.13: when the wedding moves, the app
    // names the ones made for the old day). Its owner reads them with the
    // provider's name; someone outside the plan cannot.
    const plan = await prisma.weddingPlan.create({
      data: { ownerUserId: customerA.id, title: `${label} plan` },
    });
    planId = plan.id;
    const planQuote = await acceptedQuote(customerA.id, "2027-04-10");
    await prisma.quoteRequest.update({
      where: { id: planQuote.id },
      data: { weddingPlanId: plan.id },
    });
    const planBooking = await bookings.requestBooking(customerA as any, planQuote.id, {});
    const planBookings = await bookings.listForPlan(customerA as any, plan.id);
    assert.deepEqual(planBookings.map((item) => item.id), [planBooking.id]);
    assert.equal(planBookings[0].providerName, `${label} provider`);
    assert.equal(planBookings[0].eventDate, "2027-04-10");
    await assert.rejects(bookings.listForPlan(customerB as any, plan.id));
    console.log("PASS - a plan lists its bookings with the provider's name, to its people only");

    // RA-BE-48: a booking asked again is the same row. A day change left
    // waiting on the booking before was accepted onto the new one and moved
    // its day; and «تم» said on the day, while a cancel and a move were still
    // open, travelled with the booking to another day.
    const moveQuote = await acceptedQuote(customerA.id, "2027-05-05");
    const moving = await bookings.requestBooking(customerA as any, moveQuote.id, {});
    await bookings.decideAsProvider(providerUser as any, moving.id, "CONFIRM", {});
    await bookings.requestChangeAsCustomer(customerA as any, moving.id, { eventDate: "2027-05-12" });
    await bookings.cancelAsCustomer(customerA as any, moving.id, {});
    const askedAgain = await bookings.requestBooking(customerA as any, moveQuote.id, {});
    assert.equal(askedAgain.id, moving.id);
    await bookings.decideAsProvider(providerUser as any, askedAgain.id, "CONFIRM", {});
    const stale = await prisma.bookingChange.findFirst({ where: { bookingId: moving.id } });
    assert.equal(stale?.status, "CANCELLED");
    await assert.rejects(
      bookings.decideChangeAsProvider(providerUser as any, stale!.id, true, {}),
      (error: any) => error?.response?.code === "BOOKING_CHANGE_DECIDED",
    );
    const kept = await prisma.booking.findUniqueOrThrow({ where: { id: askedAgain.id } });
    assert.equal(kept.eventDate.toISOString().slice(0, 10), "2027-05-05");
    console.log("PASS - a booking asked again carries no change left waiting from before");

    await prisma.booking.update({
      where: { id: askedAgain.id },
      data: { eventDate: bookingToday() },
    });
    await bookings.recordOutcomeAsProvider(providerUser as any, askedAgain.id, { happened: true });
    await assert.rejects(
      bookings.cancelAsCustomer(customerA as any, askedAgain.id, {}),
      (error: any) => error?.response?.code === "BOOKING_OUTCOME_ALREADY_DECIDED",
    );
    await assert.rejects(
      bookings.requestChangeAsCustomer(customerA as any, askedAgain.id, { eventDate: "2027-06-01" }),
      (error: any) => error?.response?.code === "BOOKING_CHANGE_ALREADY_DECIDED",
    );
    console.log("PASS - once «تم» is said on the day, the booking is neither cancelled nor moved");

    // B-20: three customers race for a day of a provider who takes two.
    await prisma.provider.update({
      where: { id: provider.id },
      data: { dailyBookingCapacity: 2 },
    });
    const raceDay = "2027-05-06";
    const raceCustomers = [customerA, customerB, customerA];
    const raceBookings = [];
    for (const customer of raceCustomers) {
      const quote = await acceptedQuote(customer.id, raceDay);
      raceBookings.push(await bookings.requestBooking(customer as any, quote.id, {}));
    }
    const raced = await Promise.allSettled(
      raceBookings.map((booking) =>
        bookings.decideAsProvider(providerUser as any, booking.id, "CONFIRM", {}),
      ),
    );
    assert.equal(raced.filter((result) => result.status === "fulfilled").length, 2);
    const raceRefused = raced.filter((result) => result.status === "rejected");
    assert.equal(raceRefused.length, 1);
    assert.equal(code((raceRefused[0] as PromiseRejectedResult).reason), "BOOKING_DAY_FULL");
    const raceDate = new Date(`${raceDay}T00:00:00Z`);
    assert.equal(
      await prisma.booking.count({
        where: { providerId: provider.id, status: "CONFIRMED", eventDate: raceDate },
      }),
      2,
    );
    const seats = (await bookings.listForProvider(providerUser as any)).find(
      (item) => item.eventDate === raceDay && item.status === "CONFIRMED",
    )!.day;
    assert.deepEqual(seats, { confirmed: 2, capacity: 2 });
    console.log("PASS - a two-wedding day: three racing confirmations, exactly two win");

    // He lowers his number under the day's bookings: they stay, nothing new fits.
    await prisma.provider.update({
      where: { id: provider.id },
      data: { dailyBookingCapacity: 1 },
    });
    assert.equal(
      await prisma.booking.count({
        where: { providerId: provider.id, status: "CONFIRMED", eventDate: raceDate },
      }),
      2,
    );
    await assert.rejects(
      prisma.provider.update({ where: { id: provider.id }, data: { dailyBookingCapacity: 21 } }),
    );
    console.log("PASS - a lowered number keeps the bookings; the database refuses 21");

    // B-42: a suspension expires the open request and keeps the confirmed
    // bookings; every customer concerned is told which.
    const openQuote = await acceptedQuote(customerB.id, "2027-06-03");
    const open = await bookings.requestBooking(customerB as any, openQuote.id, {});
    const suspendedAt = new Date();
    const notices = await prisma.$transaction((tx) =>
      new MarketplaceAdminService().settleBookingsOnSuspensionInTransaction(
        tx,
        provider.id,
        suspendedAt,
      ),
    );
    const expired = await prisma.booking.findUniqueOrThrow({ where: { id: open.id } });
    assert.equal(expired.status, "EXPIRED");
    assert.ok(expired.expiredAt);
    assert.equal(
      await prisma.booking.count({ where: { providerId: provider.id, status: "CONFIRMED", eventDate: raceDate } }),
      2,
    );
    assert.ok(notices.some((notice: any) => notice.data.bookingId === open.id && notice.data.bookingKept === false));
    assert.ok(notices.some((notice: any) => notice.data.bookingKept === true));
    assert.ok(notices.every((notice: any) => String(notice.title).endsWith("موقوف مؤقتًا")));
    // Once back, the customer may ask again.
    assert.equal(
      (await bookings.requestBooking(customerB as any, openQuote.id, {})).status,
      "REQUESTED",
    );
    console.log("PASS - a suspension expires the open request, keeps the confirmed ones and tells both");
  } finally {
    if (planId) {
      await prisma.quoteRequest.updateMany({
        where: { weddingPlanId: planId },
        data: { weddingPlanId: null },
      });
      await prisma.weddingPlan.deleteMany({ where: { id: planId } });
    }
    await prisma.provider.deleteMany({ where: { id: provider.id } });
    await prisma.user.deleteMany({
      where: { id: { in: [providerUser.id, customerA.id, customerB.id] } },
    });
    await prisma.city.deleteMany({ where: { id: city.id } });
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
