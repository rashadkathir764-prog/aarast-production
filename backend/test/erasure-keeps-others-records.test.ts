import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { ConversationRelationsService } from "../src/conversations/conversation-relations";
import { FinancePortService } from "../src/modules/finance/infrastructure/finance-port.service";
import {
  ERASED_PROVIDER_NAME,
  MarketplaceErasureService,
} from "../src/modules/marketplace/infrastructure/marketplace-erasure.service";
import { MediaUploadTicketService } from "../src/modules/media/infrastructure/media-upload-ticket.service";
import { MessagingErasureService } from "../src/modules/messaging/infrastructure/messaging-erasure.service";
import { catalogWithoutMoneyLinks } from "./support/owner-ports";

// RA-BE-178: erasing an account erased other people's records. A member's
// receipts on the owner's costs went with his account (D112 says what he
// recorded stays), his messages in the owner's conversations went by
// cascade, and an erased provider took his customers' conversations,
// requests, offers and bookings with him, leaving their agreements with no
// offer behind them.

function relation(model: string, field: string) {
  const found = Prisma.dmmf.datamodel.models
    .find((candidate) => candidate.name === model)
    ?.fields.find((candidate) => candidate.name === field);
  assert.ok(found, `${model}.${field}`);
  return found;
}

test("RA-BE-178: a member's messages outlive his account, with no author", async () => {
  const sender = relation("ChatMessage", "sender");
  assert.equal(sender.relationOnDelete, "SetNull");
  assert.equal(relation("ChatMessage", "senderUserId").isRequired, false);

  // The retained administrator's application identity takes the same path
  // by hand: the messages stay, without him.
  const calls: Array<{ model: string; op: string; args: any }> = [];
  const record = (model: string) =>
    new Proxy(
      {},
      {
        get: (_target, op: string) => async (args: any) => {
          calls.push({ model, op, args });
          return { count: 1 };
        },
      },
    );
  const tx: any = new Proxy({}, { get: (_target, model: string) => record(model) });
  await new MessagingErasureService().eraseUserParticipationInTransaction(tx, "u1");
  const messages = calls.filter((call) => call.model === "chatMessage");
  assert.deepEqual(messages, [
    {
      model: "chatMessage",
      op: "updateMany",
      args: { where: { senderUserId: "u1" }, data: { senderUserId: null } },
    },
  ]);
});

test("RA-BE-178: a message whose sender was erased reads with no sender", async () => {
  const relations = new ConversationRelationsService(
    {} as any,
    {
      getAppIdentities: async (_client: unknown, ids: readonly string[]) =>
        ids.map((id) => ({ id, name: `اسم ${id}` })),
    } as any,
    {} as any,
    {} as any,
    {} as any,
  );
  const [kept, erased] = await relations.attachMessageSenders({} as any, [
    { id: "m1", senderUserId: "u2", attachments: [] },
    { id: "m2", senderUserId: null, attachments: [] },
  ] as any);
  assert.equal((kept.sender as any)?.id, "u2");
  assert.equal(erased.sender, null);
});

test("RA-BE-178 (D112): a member's receipt on the owner's cost stays, from «عضو سابق»", async () => {
  const receiptQueries: any[] = [];
  const updates: any[] = [];
  const tx: any = {
    weddingCost: { findMany: async () => [] },
    costReceipt: {
      findMany: async (args: any) => {
        receiptQueries.push(args.where);
        return [];
      },
      updateMany: async (args: any) => {
        updates.push(args);
        return { count: 2 };
      },
    },
  };
  const finance = new FinancePortService(catalogWithoutMoneyLinks);
  await finance.listErasedReceiptIdsInTransaction(tx, [], "member-1");
  // Only the receipts of his own private costs are his; none is chosen for
  // having been uploaded by him.
  assert.deepEqual(receiptQueries, [
    { weddingCost: { privateToUserId: "member-1" } },
  ]);
  await finance.detachReceiptUploaderInTransaction(tx, "member-1");
  assert.deepEqual(updates, [
    {
      where: { uploadedByUserId: "member-1" },
      data: { uploadedByUserId: null },
    },
  ]);
});

test("RA-BE-178: the files of what stays are not deleted with their uploader", async () => {
  const scopes: any[] = [];
  const tx: any = {
    $queryRaw: async () => [],
    mediaUploadTicket: {
      findMany: async (args: any) => {
        scopes.push(args.where);
        return [];
      },
      updateMany: async () => ({ count: 0 }),
    },
  };
  await new MediaUploadTicketService({} as any).scheduleUserDeletion("member-1", tx);
  assert.deepEqual(scopes, [
    {
      userId: "member-1",
      status: { not: "DELETED" },
      OR: [
        { consumedByType: null },
        {
          consumedByType: {
            notIn: ["CHAT_ATTACHMENT", "COST_RECEIPT", "GUEST_INVITATION_CARD"],
          },
        },
      ],
    },
  ]);
});

test("RA-BE-178: an erased provider's customers keep their conversations and requests", async () => {
  const queries: string[] = [];
  const tx: any = {
    $queryRaw: async (query: { strings: readonly string[] }) => {
      queries.push(query.strings.join("?"));
      return [];
    },
  };
  await new MessagingErasureService().lockOwnedConversationIdsForUpdateInTransaction(
    tx,
    { userId: "provider-owner", weddingPlanIds: [] },
  );
  await new MarketplaceErasureService().lockOwnedQuoteRequestIdsForUpdateInTransaction(
    tx,
    { userId: "provider-owner", weddingPlanIds: [], conversationIds: [] },
  );
  await new MarketplaceErasureService().lockMemberPlanQuoteRequestsForUpdateInTransaction(
    tx,
    { userId: "provider-owner", weddingPlanIds: [], conversationIds: [] },
  );
  assert.equal(queries.length, 3);
  for (const query of queries) {
    assert.doesNotMatch(query, /"providerId"/u);
  }
});

test("RA-BE-178: the erased listing stays as «مزود محذوف», read-only, with nothing of its own", async () => {
  const writes: Array<{ model: string; op: string; args: any }> = [];
  const tx: any = new Proxy(
    {},
    {
      get: (_target, model: string) =>
        new Proxy(
          {},
          {
            get: (_inner, op: string) => async (args: any) => {
              writes.push({ model, op, args });
              return { count: 1 };
            },
          },
        ),
    },
  );
  const erasedAt = new Date("2026-12-01T09:00:00.000Z");
  await new MarketplaceErasureService().eraseProvidersInTransaction(
    tx,
    ["provider-1"],
    erasedAt,
  );
  await new MessagingErasureService().closeProviderConversationsInTransaction(
    tx,
    ["provider-1"],
    erasedAt,
  );

  // Nothing his customers hold is deleted: the listing, its requests,
  // offers, bookings and conversations stay.
  for (const model of ["provider", "quoteRequest", "quoteOffer", "booking", "conversation"]) {
    assert.equal(
      writes.some((write) => write.model === model && write.op.startsWith("delete")),
      false,
      `${model} is kept`,
    );
  }
  const op = (model: string) => writes.filter((write) => write.model === model);
  // What was open ends.
  assert.deepEqual(op("quoteRequest")[0].args.data, {
    status: "EXPIRED",
    expiredAt: erasedAt,
  });
  assert.deepEqual(op("quoteRequest")[0].args.where.status, {
    in: ["SENT", "VIEWED", "RESPONDED"],
  });
  assert.equal(op("quoteOffer")[0].args.where.status, "PENDING");
  assert.equal(op("quoteOffer")[0].args.data.status, "WITHDRAWN");
  assert.equal(op("booking")[0].args.where.status, "REQUESTED");
  assert.equal(op("booking")[0].args.data.status, "EXPIRED");
  // The conversations are closed: read, never written again.
  assert.deepEqual(op("conversation"), [
    {
      model: "conversation",
      op: "updateMany",
      args: {
        where: { providerId: { in: ["provider-1"] }, closedAt: null },
        data: { closedAt: erasedAt },
      },
    },
  ]);
  // The listing's own data goes.
  for (const model of [
    "providerService",
    "providerPackage",
    "portfolioItem",
    "favoriteProvider",
    "providerReview",
    "providerBlockedDate",
    "providerProfileViewDay",
    "providerFeaturedPeriod",
    "providerClaimRequest",
    "providerReviewEvent",
    // RA-BE-152: the name and images he asked for and the team has not decided.
    "providerProfileChange",
  ]) {
    assert.deepEqual(
      op(model).map((write) => write.op),
      ["deleteMany"],
      `${model} goes`,
    );
  }
  const [erased] = op("provider");
  assert.equal(erased.op, "updateMany");
  assert.equal(ERASED_PROVIDER_NAME, "مزود محذوف");
  assert.equal(erased.args.data.businessName, ERASED_PROVIDER_NAME);
  assert.equal(erased.args.data.erasedAt, erasedAt);
  assert.equal(erased.args.data.status, "SUSPENDED");
  for (const field of [
    "ownerName",
    "whatsapp",
    "email",
    "description",
    "address",
    "latitude",
    "longitude",
    "logoUrl",
    "coverUrl",
  ]) {
    assert.equal(erased.args.data[field], null, `${field} is emptied`);
  }
  assert.equal(erased.args.data.phone, "");
});

test("RA-BE-178: an agreement keeps its amount and its offer when the provider goes", () => {
  // The listing row stays, so neither link is cut; and were the offer ever
  // removed, the agreement's amount is its own column, not the offer's.
  assert.equal(relation("WeddingCost", "quoteOffer").relationOnDelete, "SetNull");
  assert.equal(relation("WeddingCost", "provider").relationOnDelete, "SetNull");
  assert.equal(relation("WeddingCost", "totalAmount").isRequired, true);
});
