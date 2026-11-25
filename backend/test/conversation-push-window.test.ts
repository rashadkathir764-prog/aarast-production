import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ConflictException } from "@nestjs/common";
import { ConversationEventType } from "@prisma/client";
import {
  conversationMakesNotices,
} from "../src/conversations/chat-notifications";
import { ConversationsService } from "../src/conversations/conversations.service";
import {
  recordConversationEvent,
  setConversationPushStop,
} from "../src/conversations/conversation-lifecycle";
import { BookingsService } from "../src/marketplace/bookings.service";
import {
  CONVERSATION_PUSH_WINDOW_DAYS,
  settleConversationPush,
} from "../src/marketplace/conversation-push-window";

// RA-BE-170 (Q-42 أ): after a request is declined, cancelled or expired, or
// a booking ends, the conversation stays open to writing, and 30 days on its
// messages make no notice or phone alert. A new request, an offer or a
// booking asked again starts them again.

const DAY_MS = 24 * 60 * 60 * 1000;
const NOW = new Date("2026-11-25T09:00:00.000Z");

test("the window is 30 days, and a conversation without a stop always notifies", () => {
  assert.equal(CONVERSATION_PUSH_WINDOW_DAYS, 30);
  assert.equal(conversationMakesNotices({ pushStopsAt: null }, NOW), true);
  const stops = new Date(NOW.getTime() + DAY_MS);
  assert.equal(conversationMakesNotices({ pushStopsAt: stops }, NOW), true);
  assert.equal(conversationMakesNotices({ pushStopsAt: stops }, stops), false);
  assert.equal(
    conversationMakesNotices({ pushStopsAt: stops }, new Date(stops.getTime() + 1)),
    false,
  );
});

test("a request that ended with nothing else alive sets the stop 30 days on; with something alive it clears it", async () => {
  const sets: Array<[string, Date | null]> = [];
  const lifecycle = {
    setConversationPushStopInTransaction: async (_tx: unknown, id: string, at: Date | null) => {
      sets.push([id, at]);
    },
  };
  const where: any[] = [];
  const txWith = (alive: number) =>
    ({
      quoteRequest: {
        count: async (query: any) => {
          where.push(query.where);
          return alive;
        },
      },
    }) as any;

  await settleConversationPush(txWith(0), lifecycle, "conversation-1", NOW);
  await settleConversationPush(txWith(2), lifecycle, "conversation-1", NOW);
  assert.deepEqual(sets, [
    ["conversation-1", new Date(NOW.getTime() + 30 * DAY_MS)],
    ["conversation-1", null],
  ]);
  // Alive means: waiting on an answer or an offer, or accepted with its
  // booking not asked or not yet over.
  assert.deepEqual(where[0], {
    conversationId: "conversation-1",
    OR: [
      { status: { in: ["SENT", "VIEWED", "RESPONDED"] } },
      {
        status: "ACCEPTED",
        OR: [
          { booking: null },
          {
            booking: {
              status: { in: ["REQUESTED", "CONFIRMED"] },
              completedAt: null,
              notHappenedAt: null,
            },
          },
        ],
      },
    ],
  });
});

test("only a new request, an offer, a revised offer and an accepted one start a conversation's notices again", async () => {
  const updates: any[] = [];
  const tx = {
    conversationEvent: {
      createMany: async () => ({ count: 1 }),
      findUniqueOrThrow: async () => ({ id: "event-1" }),
    },
    conversation: {
      update: async ({ data }: any) => {
        updates.push(data);
      },
    },
    outboxEvent: { create: async () => ({}) },
  } as any;
  const record = (type: ConversationEventType) =>
    recordConversationEvent(tx, {
      conversationId: "conversation-1",
      type,
      occurredAt: NOW,
      dedupeKey: `key-${type}`,
    });

  for (const type of [
    ConversationEventType.QUOTE_REQUEST_CREATED,
    ConversationEventType.QUOTE_OFFER_RECEIVED,
    ConversationEventType.QUOTE_OFFER_REVISED,
    ConversationEventType.QUOTE_OFFER_ACCEPTED,
  ]) {
    updates.length = 0;
    await record(type);
    assert.deepEqual(updates, [{ lastActivityAt: NOW, pushStopsAt: null }], type);
  }
  // The ending ones leave the stop to marketplace, which knows what else lives.
  for (const type of [
    ConversationEventType.QUOTE_REQUEST_CANCELLED,
    ConversationEventType.QUOTE_REQUEST_REJECTED,
    ConversationEventType.QUOTE_REQUEST_EXPIRED,
    ConversationEventType.QUOTE_OFFER_REJECTED,
    ConversationEventType.QUOTE_OFFER_WITHDRAWN,
  ]) {
    updates.length = 0;
    await record(type);
    assert.deepEqual(updates, [{ lastActivityAt: NOW }], type);
  }

  const written: any[] = [];
  await setConversationPushStop(
    { conversation: { update: async (query: any) => written.push(query) } } as any,
    "conversation-1",
    NOW,
  );
  assert.deepEqual(written, [{ where: { id: "conversation-1" }, data: { pushStopsAt: NOW } }]);
});

// The booking that ends: the hourly completion of bookings nobody answered
// for, and the customer's or provider's cancel.
function bookingsService(alive: number, sets: Array<[string, Date | null]>) {
  const booking = {
    id: "booking-1",
    eventDate: new Date("2026-11-20T00:00:00.000Z"),
    quoteOffer: { deliveryDays: null },
    quoteRequest: { conversationId: "conversation-7" },
  };
  const tx: any = {
    booking: {
      findMany: async () => [booking],
      updateMany: async () => ({ count: 1 }),
    },
    quoteRequest: { count: async () => alive },
  };
  const prisma: any = {
    booking: tx.booking,
    $transaction: async (work: any) => work(tx),
  };
  const lifecycle: any = {
    setConversationPushStopInTransaction: async (_tx: unknown, id: string, at: Date | null) => {
      sets.push([id, at]);
    },
  };
  const service = new BookingsService(
    prisma,
    {} as any,
    {} as any,
    {} as any,
    undefined,
    undefined,
    undefined,
    lifecycle,
  );
  return { service, tx, booking };
}

test("a booking completed by the hourly job ends the conversation's notices in 30 days unless something else is alive", async () => {
  const sets: Array<[string, Date | null]> = [];
  const ended = bookingsService(0, sets);
  const { completed } = await ended.service.completeOverdueBookings(NOW);
  assert.equal(completed, 1);
  assert.deepEqual(sets, [["conversation-7", new Date(NOW.getTime() + 30 * DAY_MS)]]);

  sets.length = 0;
  await bookingsService(1, sets).service.completeOverdueBookings(NOW);
  assert.deepEqual(sets, [["conversation-7", null]]);
});

test("a cancelled or declined booking settles the conversation; a confirmed one does not", async () => {
  const sets: Array<[string, Date | null]> = [];
  const { service, tx, booking } = bookingsService(0, sets);
  tx.booking.findUniqueOrThrow = async () => ({ id: "booking-1" });
  const open = {
    ...booking,
    status: "CONFIRMED",
    completedAt: null,
    notHappenedAt: null,
    quoteOfferId: null,
    quoteRequest: { ...booking.quoteRequest, weddingPlanId: null },
    eventDate: new Date(NOW.getTime() + 20 * DAY_MS),
  };
  await (service as any).transition(tx, open, "CANCEL", "CUSTOMER", {});
  assert.equal(sets.length, 1);
  assert.equal(sets[0]![0], "conversation-7");
  assert.ok(sets[0]![1] instanceof Date);

  sets.length = 0;
  const requested = { ...open, status: "REQUESTED" };
  await (service as any).transition(tx, requested, "CONFIRM", "PROVIDER", {});
  assert.deepEqual(sets, [], "a confirmed booking is alive");
});

// CONVERSATION_CLOSED is live: the erasure of a provider's account closes
// his conversations (`closedAt`), and a closed one refuses a message with
// this code. A conversation past its 30 days is not closed: it still sends.
test("a closed conversation refuses a message with CONVERSATION_CLOSED; one past its notices window still sends", () => {
  const service = new ConversationsService(
    {} as any, {} as any, {} as any, {} as any, {} as any, {} as any,
  );
  const conversation = (extra: Record<string, unknown>) => ({
    provider: { status: "ACTIVE", userId: "provider-user" },
    weddingPlan: null,
    closedAt: null,
    pushStopsAt: null,
    participants: [{ userId: "provider-user", revokedAt: null }],
    customerSideBlockedAt: null,
    providerSideBlockedAt: null,
    customerSideBlockedById: null,
    ...extra,
  });
  const send = (record: unknown) => (service as any).assertConversationSendable(record);

  assert.throws(
    () => send(conversation({ closedAt: NOW })),
    (error: unknown) =>
      error instanceof ConflictException &&
      (error.getResponse() as any).code === "CONVERSATION_CLOSED",
  );
  assert.doesNotThrow(() =>
    send(conversation({ pushStopsAt: new Date(NOW.getTime() - 40 * DAY_MS) })),
  );
});
