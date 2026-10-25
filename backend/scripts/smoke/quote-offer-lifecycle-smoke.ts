import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { JwtService } from "@nestjs/jwt";
import {
  AuthSessionScope,
  ConversationEventType,
  PrismaClient,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
  UserRole,
  UserStatus,
  type User,
} from "@prisma/client";
import { QuoteRequestExpiryService } from "../../src/marketplace/quote-request-expiry.service";
import { providerResponseSample } from "../../src/modules/marketplace/infrastructure/marketplace-core.repository";
import { normalizeBudgetCategoryName } from "../../src/modules/finance/domain/cost-category-matching";
import { ConversationLifecycleService } from "../../src/modules/messaging/internal/conversation-lifecycle.internal.module";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { notificationsService, ownerPorts } from "./support/owner-ports";

// The request and its offer over HTTP on a real database (B-03, B-04, B-06,
// B-08, B-14, G19, G38): what the provider reads of the customer, versions
// and «ايش تغيّر», accepting the version read, withdrawing, the seven-day
// answer window and its hourly job, and an accepted «وجبات» offer filed under
// the hosting. Run it with `npm run smoke:quote-offer-lifecycle`: the managed
// runner gives it an isolated database and its own API.

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const baseUrl = process.env.SMOKE_BASE_URL!;
const prisma = new PrismaClient();
const jwt = new JwtService({ secret: process.env.JWT_SECRET });
const label = `Offers ${runId}`;
const DAY_MS = 24 * 60 * 60 * 1000;
let checks = 0;

function scopedPhone(role: string): string {
  const digits = createHash("sha256")
    .update(`${runId}:${role}`)
    .digest("hex")
    .split("")
    .map((character) => String(Number.parseInt(character, 16) % 10))
    .join("")
    .slice(0, 8);
  return `+9677${digits}`;
}

function pass(message: string): void {
  checks += 1;
  console.log(`PASS - ${message}`);
}

interface Reply {
  status: number;
  body: any;
}

async function call(
  method: string,
  path: string,
  token: string,
  body?: unknown,
): Promise<Reply> {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      ...(body === undefined ? {} : { "content-type": "application/json" }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  return { status: response.status, body: text ? JSON.parse(text) : null };
}

function expect(reply: Reply, status: number, what: string, code?: string): any {
  assert.equal(
    reply.status,
    status,
    `${what}: expected ${status}, got ${reply.status} ${JSON.stringify(reply.body)}`,
  );
  if (code) assert.equal(reply.body?.code, code, `${what}: code`);
  return reply.body;
}

async function session(user: User): Promise<string> {
  const stored = await prisma.refreshToken.create({
    data: {
      userId: user.id,
      tokenHash: `offers-${runId}-${user.id}`,
      scope: AuthSessionScope.APPLICATION,
      expiresAt: new Date(Date.now() + 60 * 60 * 1000),
    },
  });
  return jwt.sign({ sub: user.id, phone: user.phone, scope: "application", sid: stored.id });
}

async function account(role: string, name: string, userRole: UserRole = UserRole.USER): Promise<User> {
  return prisma.user.create({
    data: {
      name,
      phone: scopedPhone(role),
      phoneVerifiedAt: new Date(),
      passwordHash: "managed-smoke-not-a-credential",
      appPasswordConfiguredAt: new Date(),
      role: userRole,
      status: UserStatus.ACTIVE,
    },
  });
}

async function main(): Promise<void> {
  const customer = await account("customer", "محمد الحمدي");
  const providerUser = await account("provider", `${label} مزود`, UserRole.PROVIDER);
  // The production «وجبات» category and city, as the migrations wrote them.
  const meals = await prisma.providerCategory.findUniqueOrThrow({ where: { slug: "catering" } });
  assert.equal(meals.nameAr, "وجبات");
  const city = await prisma.city.findFirstOrThrow({ where: { nameAr: "صنعاء", countryCode: "YE" } });
  const provider = await prisma.provider.create({
    data: {
      userId: providerUser.id,
      cityId: city.id,
      primaryCategoryId: meals.id,
      businessName: "ضيافة الأصالة",
      phone: scopedPhone("provider"),
      status: ProviderStatus.ACTIVE,
    },
  });
  const service = await prisma.providerService.create({
    data: {
      providerId: provider.id,
      categoryId: meals.id,
      title: "عشاء 120 ضيف",
      basePrice: "500000",
      currency: "YER",
    },
  });
  const plan = await prisma.weddingPlan.create({
    data: {
      ownerUserId: customer.id,
      title: "عرس محمد",
      currency: "YER",
      weddingDate: new Date("2027-01-21T00:00:00.000Z"),
    },
  });
  for (const name of ["التصوير والفيديو", "الوليمة والضيافة", "أخرى"]) {
    await prisma.budgetCategory.create({
      data: { weddingPlanId: plan.id, name, normalizedName: normalizeBudgetCategoryName(name) },
    });
  }
  const customerToken = await session(customer);
  const providerToken = await session(providerUser);

  const request = (eventDate: string, share: boolean) =>
    call("POST", `/api/v1/wedding-plans/${plan.id}/quote-requests`, customerToken, {
      providerId: provider.id,
      serviceId: service.id,
      eventDate,
      guestCount: 120,
      budgetMin: "400000",
      budgetMax: "600000",
      message: "نشتي عشاء لـ120 ضيف",
      shareBudget: share,
      shareContact: share,
    });

  // ---------------------------------------------------------------- B-08
  const privateQuote = expect(await request("2027-01-21", false), 201, "a private request");
  const sharedQuote = expect(await request("2027-01-22", true), 201, "a shared request");
  const seenPrivate = expect(
    await call("GET", `/api/v1/provider/me/quote-requests/${privateQuote.id}`, providerToken),
    200,
    "the provider reads the private request",
  );
  assert.equal(seenPrivate.budgetMin, null);
  assert.equal(seenPrivate.budgetMax, null);
  assert.equal(seenPrivate.contactPhone, null);
  assert.equal(seenPrivate.contactNormalizedPhone, null);
  assert.equal(seenPrivate.user.phone, null);
  assert.equal(seenPrivate.shareBudget, false);
  const seenShared = expect(
    await call("GET", `/api/v1/provider/me/quote-requests/${sharedQuote.id}`, providerToken),
    200,
    "the provider reads the shared request",
  );
  assert.equal(seenShared.budgetMax, "600000");
  assert.equal(seenShared.contactPhone, customer.phone);
  const providerList = expect(
    await call("GET", "/api/v1/provider/me/quote-requests", providerToken),
    200,
    "the provider's requests",
  );
  const listedPrivate = providerList.find((item: any) => item.id === privateQuote.id);
  assert.equal(listedPrivate.budgetMin, null);
  assert.equal(listedPrivate.user.phone, null);
  pass("the provider reads the customer's budget and phone only on the request that shared them");

  // ---------------------------------------------------------------- B-14
  const conversations = expect(
    await call("GET", "/api/v1/conversations", providerToken),
    200,
    "the provider's conversations",
  );
  const items = conversations.items ?? conversations;
  const planChat = items.find((item: any) => item.weddingPlan?.id === plan.id);
  assert.ok(planChat, "the plan's conversation is listed");
  assert.deepEqual(planChat.counterpart, {
    firstName: "محمد",
    weddingLabel: "عرس محمد",
    eventDate: planChat.latestQuoteRequest.eventDate,
  });
  const chatQuote = planChat.latestQuoteRequest;
  if (chatQuote.id === privateQuote.id) {
    assert.equal(chatQuote.budgetMin, undefined);
    assert.equal(chatQuote.contactPhone, undefined);
  }
  pass("in a plan's conversation the provider reads the customer's first name, the wedding and its day, and no phone");

  // ---------------------------------------------------------------- B-04 window
  const created = await prisma.quoteRequest.findUniqueOrThrow({ where: { id: privateQuote.id } });
  assert.equal(created.expiresAt.getTime() - created.createdAt.getTime(), 7 * DAY_MS);
  assert.equal(new Date(seenPrivate.expiresAt).getTime(), created.expiresAt.getTime());
  pass("a new request answers by seven days after it was sent, and the provider reads the deadline");

  // ---------------------------------------------------------------- G19
  expect(
    await call("POST", `/api/v1/provider/me/quote-requests/${privateQuote.id}/offers`, providerToken, {
      title: "عشاء",
      message: "عشاء لـ120 ضيف",
      amount: "500",
      currency: "USD",
    }),
    400,
    "an offer in dollars on a plan in rials",
    "QUOTE_OFFER_CURRENCY_MISMATCH",
  );
  pass("an offer in another currency than the plan's is refused with an Arabic message");

  // ---------------------------------------------------------------- B-06
  const offer = expect(
    await call("POST", `/api/v1/provider/me/quote-requests/${privateQuote.id}/offers`, providerToken, {
      title: "عشاء 120 ضيف",
      message: "لحم ورز وسلطات",
      amount: "500000",
      currency: "YER",
    }),
    201,
    "the first offer",
  );
  assert.equal(offer.versionNo, 1);
  assert.deepEqual(offer.changes, []);
  const revised = expect(
    await call("PATCH", `/api/v1/provider/me/quote-offers/${offer.id}`, providerToken, {
      amount: "450000",
      message: "لحم ورز وسلطات وحلى",
    }),
    200,
    "the edit",
  );
  assert.equal(revised.versionNo, 2);
  assert.deepEqual(revised.changes, [
    { field: "amount", from: "500000", to: "450000" },
    { field: "message", from: "لحم ورز وسلطات", to: "لحم ورز وسلطات وحلى" },
  ]);
  const retried = expect(
    await call("PATCH", `/api/v1/provider/me/quote-offers/${offer.id}`, providerToken, {
      amount: "450000",
      message: "لحم ورز وسلطات وحلى",
    }),
    200,
    "the same edit again",
  );
  assert.equal(retried.versionNo, 2);
  assert.equal(await prisma.quoteOfferVersion.count({ where: { quoteOfferId: offer.id } }), 2);
  assert.equal(
    await prisma.conversationEvent.count({
      where: { quoteOfferId: offer.id, type: ConversationEventType.QUOTE_OFFER_REVISED },
    }),
    1,
  );
  assert.equal(
    await prisma.notification.count({
      where: { userId: customer.id, dedupeKey: `${customer.id}:quote-offer:${offer.id}:v2` },
    }),
    1,
  );
  const customerView = expect(
    await call("GET", `/api/v1/quote-requests/${privateQuote.id}`, customerToken),
    200,
    "the customer reads the offer",
  );
  const customerOffer = customerView.offers.find((item: any) => item.id === offer.id);
  assert.equal(customerOffer.versionNo, 2);
  assert.equal(customerOffer.amount, "450000");
  assert.equal(customerOffer.changes[0].field, "amount");
  pass("an edit before acceptance is version 2 with «ايش تغيّر», one event and one notice; repeating it changes nothing");

  // A member who manages the providers but sees no money reads the
  // conversation's timeline: the revision is there, its amounts are not.
  const member = await account("member", `${label} مساعد`);
  await prisma.sharedMember.create({
    data: {
      weddingPlanId: plan.id,
      userId: member.id,
      canManageProviders: true,
      canViewMoney: false,
    },
  });
  const memberToken = await session(member);
  const timeline = expect(
    await call("GET", `/api/v1/conversations/${planChat.id}/timeline`, memberToken),
    200,
    "the member reads the timeline",
  );
  const revisedEvent = timeline.items.find(
    (item: any) => item.kind === "EVENT" && item.event?.type === "QUOTE_OFFER_REVISED",
  );
  assert.ok(revisedEvent, "the revision is on the timeline");
  assert.deepEqual(revisedEvent.event.data, { versionNo: 2 });
  for (const item of timeline.items) {
    if (item.kind !== "EVENT") continue;
    assert.doesNotMatch(
      JSON.stringify(item.event.data ?? {}),
      /amount|changes|500000|450000/u,
      `${item.event.type} carries no money`,
    );
  }
  const memberRequests = expect(
    await call("GET", `/api/v1/conversations/${planChat.id}/quote-requests`, memberToken),
    200,
    "the member reads the conversation's requests",
  );
  const memberOffer = memberRequests.items
    .flatMap((quote: any) => quote.offers)
    .find((item: any) => item.id === offer.id);
  assert.equal(memberOffer.amount, undefined);
  assert.deepEqual(
    memberOffer.changes.map((change: any) => change.field),
    ["message"],
    "«ايش تغيّر» without the amount",
  );
  pass("a member without money reads the revision on the timeline and «ايش تغيّر» without any amount");

  expect(
    await call("PATCH", `/api/v1/quote-offers/${offer.id}/accept`, customerToken, { versionNo: 1 }),
    409,
    "accepting the version before the edit",
    "QUOTE_OFFER_CHANGED",
  );
  assert.equal(
    (await prisma.quoteOffer.findUniqueOrThrow({ where: { id: offer.id } })).status,
    QuoteOfferStatus.PENDING,
  );
  pass("accepting a version that is no longer the offer's is refused and changes nothing");

  // ---------------------------------------------------------------- B-03
  const afterWithdraw = expect(
    await call("POST", `/api/v1/provider/me/quote-offers/${offer.id}/withdraw`, providerToken, {
      reason: "الموعد ما عاد يناسبنا",
    }),
    200,
    "the withdrawal",
  );
  assert.equal(afterWithdraw.status, QuoteRequestStatus.VIEWED);
  const withdrawnOffer = afterWithdraw.offers.find((item: any) => item.id === offer.id);
  assert.equal(withdrawnOffer.status, QuoteOfferStatus.WITHDRAWN);
  assert.equal(withdrawnOffer.withdrawnReason, "الموعد ما عاد يناسبنا");
  assert.ok(new Date(afterWithdraw.expiresAt).getTime() > Date.now() + 6 * DAY_MS);
  const again = expect(
    await call("POST", `/api/v1/provider/me/quote-offers/${offer.id}/withdraw`, providerToken, {}),
    200,
    "the withdrawal again",
  );
  assert.equal(again.status, QuoteRequestStatus.VIEWED);
  assert.equal(
    await prisma.conversationEvent.count({
      where: { quoteOfferId: offer.id, type: ConversationEventType.QUOTE_OFFER_WITHDRAWN },
    }),
    1,
  );
  assert.equal(
    await prisma.notification.count({
      where: { dedupeKey: `${customer.id}:quote-offer-withdrawn:${offer.id}` },
    }),
    1,
  );
  expect(
    await call("PATCH", `/api/v1/quote-offers/${offer.id}/accept`, customerToken, { versionNo: 2 }),
    409,
    "accepting a withdrawn offer",
    "QUOTE_OFFER_WITHDRAWN",
  );
  expect(
    await call("PATCH", `/api/v1/provider/me/quote-offers/${offer.id}`, providerToken, { amount: "1" }),
    409,
    "editing a withdrawn offer",
    "QUOTE_OFFER_LOCKED",
  );
  pass("a withdrawn offer gives the request back for seven days, tells the customer once, and can be neither accepted nor edited");

  const responseWindow = { since: new Date(0), settledBefore: new Date(Date.now() + DAY_MS) };
  const afterWithdrawal = await providerResponseSample(prisma as any, provider.id, responseWindow);
  assert.equal(afterWithdrawal.answered, 0, "a withdrawn offer is no answer");
  assert.equal(afterWithdrawal.requests, 2);
  pass("the response speed does not count a withdrawn offer as an answer");

  // ---------------------------------------------------------------- G38
  const second = expect(
    await call("POST", `/api/v1/provider/me/quote-requests/${privateQuote.id}/offers`, providerToken, {
      title: "عشاء 120 ضيف",
      message: "لحم ورز وسلطات وحلى",
      amount: "480000",
      currency: "YER",
    }),
    201,
    "a new offer after the withdrawal",
  );
  assert.equal(second.versionNo, 1);
  assert.equal(
    (await providerResponseSample(prisma as any, provider.id, responseWindow)).answered,
    1,
    "the new offer answers the request",
  );

  // Revisions are told once per offer per ten minutes; the timeline keeps each.
  const revise = async (message: string, versionNo: number) => {
    const body = expect(
      await call("PATCH", `/api/v1/provider/me/quote-offers/${second.id}`, providerToken, { message }),
      200,
      `revision ${versionNo}`,
    );
    assert.equal(body.versionNo, versionNo);
  };
  const toldOf = (versionNo: number) =>
    prisma.notification.count({
      where: { userId: customer.id, dedupeKey: `${customer.id}:quote-offer:${second.id}:v${versionNo}` },
    });
  await revise("لحم ورز وسلطات وحلى وعصير", 2);
  await revise("لحم ورز وسلطات وحلى وعصير وشاي", 3);
  assert.equal(await toldOf(2), 1, "the first revision is told");
  assert.equal(await toldOf(3), 0, "a revision a minute later is not told again");
  await prisma.quoteOffer.update({
    where: { id: second.id },
    data: { revisionNoticeAt: new Date(Date.now() - 11 * 60 * 1000) },
  });
  await revise("لحم ورز وسلطات وحلى وعصير وشاي وقهوة", 4);
  assert.equal(await toldOf(4), 1, "ten minutes later a revision is told again");
  assert.equal(
    await prisma.conversationEvent.count({
      where: { quoteOfferId: second.id, type: ConversationEventType.QUOTE_OFFER_REVISED },
    }),
    3,
  );
  pass("revisions of one offer are told once per ten minutes, and the timeline records every version");

  const accepted = expect(
    await call("PATCH", `/api/v1/quote-offers/${second.id}/accept`, customerToken, { versionNo: 4 }),
    200,
    "accepting the version read",
  );
  assert.equal(accepted.weddingCost.totalAmount, "480000");
  const cost = await prisma.weddingCost.findUniqueOrThrow({
    where: { quoteOfferId: second.id },
    include: { budgetCategory: true },
  });
  assert.equal(cost.budgetCategory.name, "الوليمة والضيافة");
  expect(
    await call("PATCH", `/api/v1/provider/me/quote-offers/${second.id}`, providerToken, { amount: "1" }),
    409,
    "editing an accepted offer",
    "QUOTE_OFFER_LOCKED",
  );
  expect(
    await call("POST", `/api/v1/provider/me/quote-offers/${second.id}/withdraw`, providerToken, {}),
    409,
    "withdrawing an accepted offer",
    "QUOTE_OFFER_NOT_WITHDRAWABLE",
  );
  pass("a new offer after a withdrawal is accepted by its version; the «وجبات» cost lands in «الوليمة والضيافة», and the accepted offer is locked");

  // ---------------------------------------------------------------- B-04 job
  const permissions = new PermissionService(prisma as any, ownerPorts.plans);
  const expiry = new QuoteRequestExpiryService(
    prisma as any,
    new ConversationLifecycleService(ownerPorts.plans, ownerPorts.providers),
    notificationsService(prisma, permissions, { enqueue: async () => undefined }) as any,
  );
  const now = new Date();
  // The shared request ends in twelve hours: the provider is warned once.
  await prisma.quoteRequest.update({
    where: { id: sharedQuote.id },
    data: { expiresAt: new Date(now.getTime() + 12 * 60 * 60 * 1000) },
  });
  const warnedRuns = await Promise.all([expiry.run(now), expiry.run(now)]);
  assert.equal(warnedRuns.reduce((sum, run) => sum + run.warned, 0), 1);
  assert.equal((await expiry.run(now)).warned, 0);
  assert.equal(
    await prisma.notification.count({
      where: { userId: providerUser.id, type: "QUOTE_REQUEST_EXPIRING", entityId: sharedQuote.id },
    }),
    1,
  );
  pass("the day before the deadline the provider is warned once, even by two jobs at the same time");

  // Past its deadline the job ends it, once, and tells the customer.
  const later = new Date(now.getTime() + 13 * 60 * 60 * 1000);
  const expiredRuns = await Promise.all([expiry.run(later), expiry.run(later)]);
  assert.equal(expiredRuns.reduce((sum, run) => sum + run.expired, 0), 1);
  assert.deepEqual(expiredRuns.flatMap((run) => run.failures), []);
  assert.equal((await expiry.run(later)).expired, 0);
  const ended = await prisma.quoteRequest.findUniqueOrThrow({ where: { id: sharedQuote.id } });
  assert.equal(ended.status, QuoteRequestStatus.EXPIRED);
  assert.equal(
    await prisma.conversationEvent.count({
      where: { quoteRequestId: sharedQuote.id, type: ConversationEventType.QUOTE_REQUEST_EXPIRED },
    }),
    1,
  );
  const told = await prisma.notification.findMany({
    where: { userId: customer.id, dedupeKey: `${customer.id}:quote-request-expired:${sharedQuote.id}` },
  });
  assert.equal(told.length, 1);
  assert.equal(told[0].title, "ما رد ضيافة الأصالة خلال 7 أيام");
  const customerEnded = expect(
    await call("GET", `/api/v1/quote-requests/${sharedQuote.id}`, customerToken),
    200,
    "the customer reads the ended request",
  );
  assert.equal(customerEnded.status, "EXPIRED");
  assert.equal(customerEnded.lifecycleStatus, "EXPIRED");
  expect(
    await call("POST", `/api/v1/provider/me/quote-requests/${sharedQuote.id}/offers`, providerToken, {
      message: "متأخر",
      amount: "450000",
    }),
    409,
    "an offer on an ended request",
    "QUOTE_REQUEST_EXPIRED",
  );
  expect(await request("2027-01-22", true), 201, "asking the same again after it ended");
  pass("past seven days the job ends the request once, the customer is told «ما رد … خلال 7 أيام», and may ask again");

  // A request whose deadline passed long before the job reached it (the
  // first run after B-04 shipped) ends without telling the customer.
  const stale = expect(await request("2027-01-23", false), 201, "a request the job reaches late");
  await prisma.quoteRequest.update({
    where: { id: stale.id },
    data: { expiresAt: new Date(Date.now() - 30 * DAY_MS) },
  });
  const lateRun = await expiry.run(new Date());
  assert.deepEqual(lateRun.failures, []);
  assert.equal(lateRun.expired, 1);
  assert.equal(
    (await prisma.quoteRequest.findUniqueOrThrow({ where: { id: stale.id } })).status,
    QuoteRequestStatus.EXPIRED,
  );
  assert.equal(
    await prisma.conversationEvent.count({
      where: { quoteRequestId: stale.id, type: ConversationEventType.QUOTE_REQUEST_EXPIRED },
    }),
    1,
  );
  assert.equal(
    await prisma.notification.count({
      where: { dedupeKey: `${customer.id}:quote-request-expired:${stale.id}` },
    }),
    0,
  );
  pass("a request ended more than a day after its deadline is closed without telling the customer late news");

  console.log(`\nQuote offer lifecycle smoke: ${checks} checks passed.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
