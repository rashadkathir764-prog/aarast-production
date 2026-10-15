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
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { ownerPorts } from "./support/owner-ports";

// Bookings without payment (V1 checklist 4.6) on a real database: requests,
// the provider's decisions, the calendar, and the partial unique index that
// lets only one of two racing confirmations for the same day succeed.

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
  );

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
    assert.equal(code((refused[0] as PromiseRejectedResult).reason), "BOOKING_DATE_UNAVAILABLE");
    const confirmedRows = await prisma.booking.count({
      where: { providerId: provider.id, status: "CONFIRMED" },
    });
    assert.equal(confirmedRows, 1);
    console.log("PASS - two racing confirmations for one day: exactly one wins");

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

    const cancelled = await bookings.cancelAsCustomer(
      (winner.id === bookingA.id ? customerA : customerB) as any,
      winner.id,
      {},
    );
    assert.equal(cancelled.status, "CANCELLED");
    assert.equal(cancelled.cancelledBy, "CUSTOMER");
    await bookings.blockDate(providerUser as any, "2027-02-18");
    console.log("PASS - a cancelled booking frees the provider's day");
  } finally {
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
