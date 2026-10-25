import "reflect-metadata";

import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { NotificationType, Prisma, UserRole } from "@prisma/client";
import { ConversationsService } from "../src/conversations/conversations.service";
import { toCategoryAdminResponse } from "../src/admin/admin.presenter";
import { CatalogAdminService } from "../src/modules/catalog/infrastructure/catalog-admin.service";
import { providerCategoryBudgetItem } from "../src/modules/finance/public/provider-category-budget-item";
import { providerResponseSample } from "../src/modules/marketplace/infrastructure/marketplace-core.repository";
import { isQuoteRequestExpiryNoticeTimely } from "../src/marketplace/quote-lifecycle";
import {
  isQuoteOfferRevisionNoticeDue,
  QUOTE_OFFER_NOTICE_WINDOW_MS,
  quoteOfferReceivedNotification,
  quoteOfferRevisedNotification,
} from "../src/marketplace/quote-notifications";
import { QuoteRequestExpiryService } from "../src/marketplace/quote-request-expiry.service";
import { pushNotificationCopy } from "../src/push/push-notification.policy";

// The review of the offers slice (D50): what a member without money reads
// in the timeline, the revision notice and its push, the provider side's
// view of the customer, where an admin category's cost lands, the response
// metric, and the hourly expiry job.

const src = join(__dirname, "..", "src");

function sourceFiles(root: string): string[] {
  return readdirSync(root).flatMap((name) => {
    const path = join(root, name);
    if (statSync(path).isDirectory()) return sourceFiles(path);
    return path.endsWith(".ts") ? [path] : [];
  });
}

/** Each `data: { … }` written with a conversation event, as source text. */
function conversationEventPayloads(text: string): string[] {
  const payloads: string[] = [];
  for (const call of text.matchAll(/(?:recordConversationEvent|upsertEvent)\(/gu)) {
    const from = call.index! + call[0].length;
    const window = text.slice(from, from + 900);
    const data = window.match(/\bdata:\s*(\{[^}]*\})/u);
    if (data) payloads.push(data[1]);
  }
  return payloads;
}

// 1. Every plan reader with the providers right opens the conversation's
// timeline, whose events are returned as stored; money stays out of them.
test("no conversation event stores an amount or the offer's changes", () => {
  const files = [
    ...sourceFiles(src),
    join(__dirname, "..", "prisma", "demo-seed", "marketplace.ts"),
  ];
  let payloads = 0;
  for (const file of files) {
    for (const payload of conversationEventPayloads(readFileSync(file, "utf8"))) {
      payloads += 1;
      assert.doesNotMatch(
        payload,
        /amount|changes|budget|price|Changes/u,
        `${file}: conversation event data ${payload}`,
      );
    }
  }
  assert.ok(payloads >= 15, `read only ${payloads} event payloads`);
  const revised = readFileSync(
    join(src, "provider-dashboard", "provider-dashboard.service.ts"),
    "utf8",
  );
  assert.match(revised, /QUOTE_OFFER_REVISED,[\s\S]{0,400}data: \{ versionNo \}/u);
});

// 3. A revision has its own words on the lock screen, never an amount, and
// is told once per offer per ten minutes.
test("a revised offer pushes «عدّلوا عرضهم», a new one «وصل عرض سعر»", () => {
  const base = {
    requesterId: "customer",
    weddingPlanId: "plan",
    quoteRequestId: "request",
    quoteOfferId: "offer",
    providerId: "provider",
    providerName: "ضوء صنعاء",
  };
  const fresh = quoteOfferReceivedNotification(base);
  const revised = quoteOfferRevisedNotification({ ...base, versionNo: 3 });
  assert.equal(fresh.type, NotificationType.QUOTE_OFFER_RECEIVED);
  assert.equal(revised.type, NotificationType.QUOTE_OFFER_RECEIVED);
  const freshCopy = pushNotificationCopy(fresh.type, fresh.data);
  const revisedCopy = pushNotificationCopy(revised.type, revised.data);
  assert.equal(freshCopy.title, "وصل عرض سعر");
  assert.equal(revisedCopy.title, "عدّلوا عرضهم");
  assert.match(revisedCopy.body, /ايش تغيّر/u);
  for (const copy of [freshCopy, revisedCopy]) {
    assert.doesNotMatch(`${copy.title} ${copy.body}`, /[0-9٠-٩]|ضوء صنعاء/u);
  }
});

test("revisions of one offer are told once per ten minutes", () => {
  const sent = new Date("2026-10-25T10:00:00.000Z");
  const at = (ms: number) => new Date(sent.getTime() + ms);
  assert.equal(QUOTE_OFFER_NOTICE_WINDOW_MS, 10 * 60 * 1000);
  assert.equal(isQuoteOfferRevisionNoticeDue(null, sent), true);
  assert.equal(isQuoteOfferRevisionNoticeDue(sent, at(60 * 1000)), false);
  assert.equal(isQuoteOfferRevisionNoticeDue(sent, at(10 * 60 * 1000 - 1)), false);
  assert.equal(isQuoteOfferRevisionNoticeDue(sent, at(10 * 60 * 1000)), true);
  const service = readFileSync(
    join(src, "provider-dashboard", "provider-dashboard.service.ts"),
    "utf8",
  );
  assert.match(service, /revisionNoticeAt: revisedAt/u, "a told revision starts the window");
  assert.match(service, /if \(tellCustomer\)/u, "a revision inside the window is not told");
});

// 4. B-14: the provider side never gets a customer's picture.
function conversations(): any {
  return new ConversationsService(
    {} as never,
    {} as never,
    {} as never,
    { createDownloadUrl: async () => ({ downloadUrl: "u", expiresAt: new Date() }) } as never,
    {} as never,
    {} as never,
  );
}

const groom = {
  id: "groom",
  name: "محمد الحمدي",
  appName: null,
  role: UserRole.USER,
  avatarUrl: "https://cdn.example/groom.jpg",
  appAvatarUrl: null,
};
const providerAccount = {
  id: "provider-user",
  name: "ضوء صنعاء",
  appName: null,
  role: UserRole.USER,
  avatarUrl: "https://cdn.example/studio.jpg",
  appAvatarUrl: null,
};

test("the provider reads the customer's full name and no picture", () => {
  const service = conversations();
  const quote = {
    id: "q",
    user: groom,
    offers: [],
    budgetMin: null,
    budgetMax: null,
    contactName: null,
    contactPhone: null,
    contactNormalizedPhone: null,
    shareBudget: false,
    shareContact: false,
  };
  const access = (side: "PROVIDER" | "CUSTOMER") => ({
    side,
    canManageProviders: true,
    canViewMoney: side === "CUSTOMER",
    canManageMoney: false,
    canViewContact: true,
  });
  assert.deepEqual(service.toQuoteRequestResponse(quote, access("PROVIDER")).user, {
    id: "groom",
    name: "محمد الحمدي",
    avatarUrl: null,
  });
  assert.equal(
    service.toQuoteRequestResponse(quote, access("CUSTOMER")).user.avatarUrl,
    groom.avatarUrl,
  );
});

test("a message shows only the provider account's picture, to both sides", async () => {
  const service = conversations();
  const fromGroom = await service.toMessageResponse(
    { id: "m1", sender: groom, attachments: [] },
    providerAccount.id,
  );
  assert.deepEqual(fromGroom.sender, { id: "groom", name: "محمد الحمدي", avatarUrl: null });
  const fromProvider = await service.toMessageResponse(
    { id: "m2", sender: providerAccount, attachments: [] },
    providerAccount.id,
  );
  assert.equal(fromProvider.sender.avatarUrl, providerAccount.avatarUrl);
});

// 5. Where an admin category's cost lands, by the acceptance matcher.
const starterItems = [
  { persona: "GROOM" as const, nameAr: "القاعة" },
  { persona: "GROOM" as const, nameAr: "التصوير والفيديو" },
  { persona: "BRIDE" as const, nameAr: "الصالة" },
  { persona: "BRIDE" as const, nameAr: "التصوير" },
  { persona: "NEUTRAL" as const, nameAr: "التصوير" },
];

function categoryRecord(nameAr: string): any {
  return {
    id: "c",
    nameAr,
    nameEn: null,
    slug: "c",
    icon: null,
    showForGroom: true,
    showForBride: true,
    isActive: true,
    sortOrder: 0,
    createdAt: new Date(),
    updatedAt: new Date(),
    _count: { providers: 0, services: 0 },
  };
}

test("an admin category says which budget item it lands in, or «أخرى»", () => {
  assert.equal(providerCategoryBudgetItem(["القاعة", "التصوير والفيديو"], "تصوير"), "التصوير والفيديو");
  assert.equal(providerCategoryBudgetItem(["القاعة"], "تنظيف"), null);
  assert.deepEqual(toCategoryAdminResponse(categoryRecord("مصورين"), starterItems).budgetItems, {
    groom: "التصوير والفيديو",
    bride: "التصوير",
    shared: "التصوير",
  });
  // A renamed or new category no topic knows: «أخرى» everywhere, said.
  assert.deepEqual(toCategoryAdminResponse(categoryRecord("تنظيف بعد العرس"), starterItems).budgetItems, {
    groom: null,
    bride: null,
    shared: null,
  });
});

test("the starter items are the published, active ones with their persona", async () => {
  const revision = (no: number, nameAr: string, persona: unknown, isActive = true, sortOrder = 0) => ({
    revision: no,
    nameAr,
    isActive,
    sortOrder,
    metadata: persona === undefined ? null : { persona },
  });
  const client = {
    referenceCatalog: {
      findUnique: async () => ({
        isActive: true,
        items: [
          { publishedRevision: 2, revisions: [revision(1, "قديم", "GROOM"), revision(2, "التصوير", "GROOM", true, 20)] },
          { publishedRevision: 1, revisions: [revision(1, "القاعة", "GROOM", true, 10)] },
          { publishedRevision: 1, revisions: [revision(1, "معطّل", "BRIDE", false)] },
          { publishedRevision: 1, revisions: [revision(1, "بلا جهة", undefined)] },
        ],
      }),
    },
  };
  assert.deepEqual(await new CatalogAdminService().listStarterBudgetItems(client as never), [
    { persona: "GROOM", nameAr: "القاعة" },
    { persona: "GROOM", nameAr: "التصوير" },
  ]);
});

// 6. A withdrawn offer is no answer for the response metric.
test("the response metric reads the first offer that was not withdrawn", async () => {
  let sql = "";
  const client = {
    $queryRaw: async (query: Prisma.Sql) => {
      sql = query.sql;
      return [{ requests: 0n, answered: 0n, medianMinutes: null }];
    },
  };
  await providerResponseSample(client as never, "provider", {
    since: new Date(0),
    settledBefore: new Date(),
  });
  assert.match(sql, /FROM "QuoteOffer"\s+WHERE "status" <> 'WITHDRAWN'\s+GROUP BY "quoteRequestId"/u);
});

// 8. A request the job reaches more than a day late is not news.
test("the customer is told of an expiry only within a day of the deadline", () => {
  const deadline = new Date("2026-10-20T12:00:00.000Z");
  const later = (hours: number) => new Date(deadline.getTime() + hours * 60 * 60 * 1000);
  assert.equal(isQuoteRequestExpiryNoticeTimely(deadline, later(0)), true);
  assert.equal(isQuoteRequestExpiryNoticeTimely(deadline, later(1)), true);
  assert.equal(isQuoteRequestExpiryNoticeTimely(deadline, later(24)), true);
  assert.equal(isQuoteRequestExpiryNoticeTimely(deadline, later(25)), false);
  assert.equal(isQuoteRequestExpiryNoticeTimely(deadline, later(24 * 120)), false);
});

// 11. A run lists each due request once, whatever happens to it.
test("the expiry job passes a request it leaves as it was, and never lists it again", async () => {
  const now = new Date("2026-10-25T12:00:00.000Z");
  const due = Array.from({ length: 250 }, (_, index) => ({
    id: `r${String(index).padStart(3, "0")}`,
    expiresAt: new Date(now.getTime() - (index % 3) * 1000),
  })).sort(
    (a, b) => a.expiresAt.getTime() - b.expiresAt.getTime() || a.id.localeCompare(b.id),
  );
  const after = (where: any) => (row: { id: string; expiresAt: Date }) => {
    const or = where.OR as Array<any> | undefined;
    if (!or) return true;
    const [later, same] = or;
    return (
      row.expiresAt.getTime() > later.expiresAt.gt.getTime() ||
      (row.expiresAt.getTime() === same.expiresAt.getTime() && row.id > same.id.gt)
    );
  };
  let listed = 0;
  const prisma = {
    quoteRequest: {
      findMany: async ({ where, take }: any) => {
        listed += 1;
        // Warnings: nothing is due. Overdue: every request still waits,
        // because the job leaves each one as it was.
        if (where.expiresAt.gt) return [];
        return due.filter(after(where)).slice(0, take);
      },
    },
  };
  const service = new QuoteRequestExpiryService(prisma as never, {} as never, {} as never) as any;
  const seen: string[] = [];
  service.expire = async (id: string) => {
    seen.push(id);
    if (id === "r007") throw new Error("lock timeout");
    return false;
  };
  const run = await service.run(now);
  assert.deepEqual(seen, due.map((row) => row.id), "each overdue request once, in order");
  assert.equal(run.expired, 0);
  assert.equal(run.skipped, 249);
  assert.deepEqual(run.failures.map((failure: any) => failure.quoteRequestId), ["r007"]);
  assert.ok(listed <= 5, `listed ${listed} batches`);
});
