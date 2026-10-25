import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { JwtService } from "@nestjs/jwt";
import {
  AdminRole,
  AuthSessionScope,
  PrismaClient,
  UserRole,
  UserStatus,
  type User,
} from "@prisma/client";

// The provider lifecycle over HTTP on a real database (B-01, B-02, B-10,
// B-12): joining with a priced service, changes per field and «أرسلت
// التعديل», reopening a refusal, and claiming a listing through the review
// team. Run it with `npm run smoke:provider-lifecycle`: the managed runner
// gives it an isolated database and its own API.

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const baseUrl = process.env.SMOKE_BASE_URL!;
const prisma = new PrismaClient();
const jwt = new JwtService({ secret: process.env.JWT_SECRET });
const label = `Lifecycle ${runId}`;
let checks = 0;

/** A Yemeni mobile number unique to this run and role. */
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

/** A signed session in the realm the account works in. */
async function session(user: User, scope: "admin" | "application"): Promise<string> {
  const stored = await prisma.refreshToken.create({
    data: {
      userId: user.id,
      tokenHash: `lifecycle-${runId}-${user.id}-${scope}`,
      scope: scope === "admin" ? AuthSessionScope.ADMIN : AuthSessionScope.APPLICATION,
      expiresAt: new Date(Date.now() + 60 * 60 * 1000),
    },
  });
  return jwt.sign({
    sub: user.id,
    phone: user.phone,
    scope,
    sid: stored.id,
    ...(scope === "admin" ? { amr: "admin_mfa" } : {}),
  });
}

async function account(role: string): Promise<User> {
  return prisma.user.create({
    data: {
      name: `${label} ${role}`,
      phone: scopedPhone(role),
      phoneVerifiedAt: new Date(),
      passwordHash: "managed-smoke-not-a-credential",
      // An application session needs an account that finished signing up.
      appPasswordConfiguredAt: new Date(),
      role: UserRole.USER,
      status: UserStatus.ACTIVE,
    },
  });
}

async function main(): Promise<void> {
  const admin = await prisma.user.create({
    data: {
      name: `${label} admin`,
      phone: scopedPhone("admin"),
      phoneVerifiedAt: new Date(),
      passwordHash: "managed-smoke-not-a-credential",
      role: UserRole.ADMIN,
      adminRole: AdminRole.OPERATIONS,
      status: UserStatus.ACTIVE,
    },
  });
  const [joiner, refused, claimant, customer, legacy] = await Promise.all([
    account("joiner"),
    account("refused"),
    account("claimant"),
    account("customer"),
    account("legacy"),
  ]);
  const city = await prisma.city.create({
    data: { nameAr: `${label} مدينة`, countryCode: "YE" },
  });
  const category = await prisma.providerCategory.create({
    data: {
      nameAr: `${label} قسم`,
      slug: `lifecycle-${runId}`.replace(/_/g, "-").toLowerCase(),
    },
  });
  const adminToken = await session(admin, "admin");
  const joinerToken = await session(joiner, "application");
  const refusedToken = await session(refused, "application");
  const claimantToken = await session(claimant, "application");
  const customerToken = await session(customer, "application");

  const application = (phone: string | null, services?: unknown) => ({
    businessName: `${label} نشاط`,
    phone,
    cityId: city.id,
    categoryIds: [category.id],
    ...(services === undefined ? {} : { services }),
  });

  // ---------------------------------------------------------------- B-10
  expect(
    await call("POST", "/api/v1/provider/apply", joinerToken, application(joiner.phone)),
    422,
    "apply without a service",
    "PROVIDER_SERVICE_REQUIRED",
  );
  expect(
    await call(
      "POST",
      "/api/v1/provider/apply",
      joinerToken,
      application(joiner.phone, [{ title: "زفة", basePrice: "0" }]),
    ),
    422,
    "apply with an unpriced service",
    "PROVIDER_SERVICE_REQUIRED",
  );
  expect(
    await call(
      "POST",
      "/api/v1/provider/apply",
      joinerToken,
      application(joiner.phone, [{ title: "زفة", basePrice: "500", currency: "USD" }]),
    ),
    422,
    "apply with a service priced in dollars",
    "PROVIDER_JOINING_CURRENCY",
  );
  assert.equal(await prisma.provider.count({ where: { userId: joiner.id } }), 0);
  pass("joining without a priced service, or priced in another currency than YER, is refused with 422 and writes nothing");

  const applied = expect(
    await call(
      "POST",
      "/api/v1/provider/apply",
      joinerToken,
      application(joiner.phone, [
        { title: "مزمار الليلة", basePrice: "150000", description: "مزمار وطبلين" },
      ]),
    ),
    201,
    "apply with a priced service",
  );
  assert.equal(applied.status, "PENDING");
  const joinerServices = expect(
    await call("GET", "/api/v1/provider/me/services", joinerToken),
    200,
    "joining service read before approval",
  );
  assert.equal(joinerServices.length, 1);
  assert.equal(joinerServices[0].basePrice, "150000");
  assert.equal(joinerServices[0].categoryId, category.id);
  const serviceId = joinerServices[0].id as string;
  const detail = expect(
    await call("GET", `/admin/providers/applications/${applied.id}`, adminToken),
    200,
    "admin reads the application",
  );
  assert.equal(detail.services.length, 1);
  assert.equal(detail.services[0].basePrice, "150000");
  pass("the joining service is created with the application and the admin sees it with its price");

  // ---------------------------------------------------------------- B-01
  const resubmit = (token: string, latestDecisionId: string | null) =>
    call("POST", "/api/v1/provider/me/application/resubmit", token, { latestDecisionId });
  expect(
    await resubmit(joinerToken, null),
    409,
    "resubmit while PENDING",
    "PROVIDER_NOT_AWAITING_CHANGES",
  );
  expect(
    await call("PATCH", `/admin/providers/${applied.id}/request-changes`, adminToken, {}),
    400,
    "request changes without a note",
  );
  expect(
    await call("PATCH", `/admin/providers/${applied.id}/request-changes`, adminToken, {
      note: "ملفك قريب.",
      fieldNotes: [
        { field: "SERVICE", note: "حدد سعر الليلة." },
        { field: "BUSINESS_NAME", note: "الاسم اللي يعرفونك فيه." },
      ],
    }),
    200,
    "request changes per field",
  );
  // The provider reads these notes; the team then rewrites them.
  const firstRead = expect(
    await call("GET", "/api/v1/provider/me/profile", joinerToken),
    200,
    "profile after the first request",
  );
  assert.equal(firstRead.latestDecision?.kind, "CHANGES_REQUESTED");
  // The team rewrites its notes while the provider is still fixing.
  expect(
    await call("PATCH", `/admin/providers/${applied.id}/request-changes`, adminToken, {
      fieldNotes: [{ field: "SERVICE", note: "حدد سعر الليلة، مو «حسب الطلب»." }],
    }),
    200,
    "rewrite the notes while NEEDS_CHANGES",
  );
  const needsChanges = expect(
    await call("GET", "/api/v1/provider/me/profile", joinerToken),
    200,
    "profile while NEEDS_CHANGES",
  );
  assert.equal(needsChanges.status, "NEEDS_CHANGES");
  assert.equal(needsChanges.reviewNote, null);
  assert.deepEqual(needsChanges.fieldNotes, [
    { field: "SERVICE", note: "حدد سعر الليلة، مو «حسب الطلب»." },
  ]);
  assert.notEqual(needsChanges.latestDecision.id, firstRead.latestDecision.id);
  pass("per-field notes reach the provider, and the newest request replaces the old notes");

  // Finding 7: sent after notes he never read, the fix does not go back.
  expect(
    await resubmit(joinerToken, firstRead.latestDecision.id),
    409,
    "resubmit naming the notes the team rewrote",
    "PROVIDER_REVIEW_CHANGED",
  );
  const stillFixing = await prisma.provider.findUniqueOrThrow({ where: { id: applied.id } });
  assert.equal(stillFixing.status, "NEEDS_CHANGES");
  assert.equal(stillFixing.resubmitCount, 0);
  expect(
    await call("POST", "/api/v1/provider/me/application/resubmit", joinerToken, {}),
    400,
    "resubmit naming no decision",
  );
  pass("«أرسلت التعديل» after notes the provider never read is refused, and the profile stays with him");

  expect(
    await call("PATCH", `/api/v1/provider/me/services/${serviceId}`, joinerToken, {
      isActive: false,
    }),
    403,
    "switch the joining service off before approval",
    "PROVIDER_JOINING_SERVICE_ONLY",
  );
  expect(
    await call("POST", "/api/v1/provider/me/services", joinerToken, {
      categoryId: category.id,
      title: "خدمة ثانية",
      basePrice: "50000",
    }),
    403,
    "a second service before approval",
    "PROVIDER_JOINING_SERVICE_ONLY",
  );
  expect(
    await call("PATCH", `/api/v1/provider/me/services/${serviceId}`, joinerToken, {
      priceUnit: "لليلة",
    }),
    403,
    "change the joining service's unit before approval",
    "PROVIDER_JOINING_SERVICE_ONLY",
  );
  expect(
    await call("PATCH", `/api/v1/provider/me/services/${serviceId}`, joinerToken, {
      currency: "USD",
    }),
    422,
    "price the joining service in dollars",
    "PROVIDER_JOINING_CURRENCY",
  );
  const fixedService = expect(
    await call("PATCH", `/api/v1/provider/me/services/${serviceId}`, joinerToken, {
      basePrice: "180000",
    }),
    200,
    "fix the joining service's price",
  );
  assert.equal(fixedService.basePrice, "180000");
  pass("before approval only the joining service's name, price and words change, in YER");

  // Finding 8: the team switches the joining service off; the provider is
  // not stuck, he adds another one and sends the profile back.
  expect(
    await call("PATCH", `/admin/services/${serviceId}`, adminToken, { isActive: false }),
    200,
    "the team switches the joining service off",
  );
  expect(
    await resubmit(joinerToken, needsChanges.latestDecision.id),
    422,
    "resubmit with the joining service switched off",
    "PROVIDER_SERVICE_REQUIRED",
  );
  const replacement = expect(
    await call("POST", "/api/v1/provider/me/services", joinerToken, {
      categoryId: category.id,
      title: "مزمار الليلة كاملة",
      basePrice: "200000",
      currency: "YER",
    }),
    201,
    "add a joining service after the first was switched off",
  );
  assert.equal(replacement.isActive, true);
  pass("a provider whose joining service was switched off adds another before approval");

  const resubmitted = expect(
    await resubmit(joinerToken, needsChanges.latestDecision.id),
    200,
    "resubmit",
  );
  assert.equal(resubmitted.status, "PENDING");
  assert.equal(resubmitted.resubmitCount, 1);
  assert.ok(resubmitted.resubmittedAt);
  assert.deepEqual(resubmitted.fieldNotes, []);
  expect(
    await resubmit(joinerToken, needsChanges.latestDecision.id),
    409,
    "resubmit twice",
    "PROVIDER_NOT_AWAITING_CHANGES",
  );
  const confirmation = await prisma.notification.findFirst({
    where: { userId: joiner.id, title: "وصلنا تعديلك" },
  });
  assert.ok(confirmation, "the provider is told the fixes arrived");
  const queue = expect(
    await call(
      "GET",
      "/admin/providers/applications?status=PENDING&resubmitted=true",
      adminToken,
    ),
    200,
    "the «أُعيد إرسالها» queue",
  );
  const queuedRow = queue.items.find((item: any) => item.id === applied.id);
  assert.ok(queuedRow);
  // Finding 6: the row reads «كان يحتاج تعديل» from the decision before it.
  assert.equal(queuedRow.latestDecision.kind, "CHANGES_REQUESTED");
  const fresh = expect(
    await call(
      "GET",
      "/admin/providers/applications?status=PENDING&resubmitted=false",
      adminToken,
    ),
    200,
    "the «جديد» queue",
  );
  assert.ok(!fresh.items.some((item: any) => item.id === applied.id));
  const stats = expect(await call("GET", "/admin/dashboard/stats", adminToken), 200, "stats");
  assert.ok(stats.resubmittedProviders >= 1);
  const history = expect(
    await call("GET", `/admin/providers/${applied.id}/review-history`, adminToken),
    200,
    "review history",
  );
  assert.deepEqual(
    history.events.map((event: any) => event.kind),
    ["CHANGES_REQUESTED", "CHANGES_REQUESTED", "RESUBMITTED"],
  );
  assert.equal(history.events[0].actor.id, admin.id);
  assert.equal(history.events[0].notes.length, 3);
  pass("«أرسلت التعديل» sends the profile back once, confirms it, and the admin sees it in its own queue with its history");

  // Finding 11: «أُعيد إرسالها» holds only the profiles waiting for review.
  expect(
    await call("PATCH", `/admin/providers/${applied.id}/request-changes`, adminToken, {
      fieldNotes: [{ field: "DESCRIPTION", note: "اكتب وين تشتغل." }],
    }),
    200,
    "ask for changes again after a resubmission",
  );
  const sentBackBefore = expect(
    await call("GET", "/admin/providers/applications?resubmitted=true", adminToken),
    200,
    "the «أُعيد إرسالها» queue while he fixes again",
  );
  assert.ok(!sentBackBefore.items.some((item: any) => item.id === applied.id));
  assert.ok(sentBackBefore.items.every((item: any) => item.status === "PENDING"));
  expect(
    await call(
      "GET",
      "/admin/providers/applications?status=NEEDS_CHANGES&resubmitted=true",
      adminToken,
    ),
    400,
    "«أُعيد إرسالها» with another status",
  );
  const secondRead = expect(
    await call("GET", "/api/v1/provider/me/profile", joinerToken),
    200,
    "profile asked for changes again",
  );
  const secondSend = expect(
    await resubmit(joinerToken, secondRead.latestDecision.id),
    200,
    "resubmit again",
  );
  assert.equal(secondSend.resubmitCount, 2);
  const sentBackAfter = expect(
    await call("GET", "/admin/providers/applications?resubmitted=true", adminToken),
    200,
    "the «أُعيد إرسالها» queue after the second send",
  );
  assert.ok(sentBackAfter.items.some((item: any) => item.id === applied.id));
  pass("«أُعيد إرسالها» lists only profiles waiting for review, never one the provider is fixing");

  // Finding 9: a profile from before B-10, with no service, is not approved.
  const legacyProfile = await prisma.provider.create({
    data: {
      userId: legacy.id,
      cityId: city.id,
      primaryCategoryId: category.id,
      businessName: `${label} قديم بلا خدمة`,
      phone: legacy.phone!,
      status: "PENDING",
    },
  });
  expect(
    await call("PATCH", `/admin/providers/${legacyProfile.id}/approve`, adminToken),
    422,
    "approve a profile without a priced service",
    "PROVIDER_SERVICE_REQUIRED",
  );
  const legacyAfter = await prisma.provider.findUniqueOrThrow({ where: { id: legacyProfile.id } });
  assert.equal(legacyAfter.status, "PENDING");
  pass("a profile without an active priced service is not approved");

  const approved = expect(
    await call("PATCH", `/admin/providers/${applied.id}/approve`, adminToken),
    200,
    "approve after the fixes",
  );
  assert.equal(approved.status, "ACTIVE");
  pass("the fixed profile is approved");

  // ---------------------------------------------------------------- B-02
  const refusedApplication = expect(
    await call(
      "POST",
      "/api/v1/provider/apply",
      refusedToken,
      application(refused.phone, [{ title: "تسريحة عروس", basePrice: "60000" }]),
    ),
    201,
    "second application",
  );
  expect(
    await call("POST", "/api/v1/provider/me/application/reopen", refusedToken),
    409,
    "reopen while PENDING",
    "PROVIDER_NOT_REJECTED",
  );
  expect(
    await call("PATCH", `/admin/providers/${refusedApplication.id}/reject`, adminToken, {
      reason: "وضّحي الخدمة.",
    }),
    200,
    "reject",
  );
  expect(
    await call("PATCH", `/admin/providers/${refusedApplication.id}/approve`, adminToken),
    409,
    "approve straight from REJECTED",
    "INVALID_PROVIDER_STATUS_TRANSITION",
  );
  expect(
    await call("PATCH", `/admin/providers/${refusedApplication.id}/request-changes`, adminToken, {
      note: "x",
    }),
    409,
    "request changes from REJECTED",
    "INVALID_PROVIDER_STATUS_TRANSITION",
  );
  expect(
    await call("PATCH", "/api/v1/provider/me/profile", refusedToken, {
      description: "وين أشتغل",
    }),
    403,
    "edit a refused profile",
    "PROVIDER_PROFILE_READ_ONLY",
  );
  pass("a refused profile is read-only and the review team cannot approve it without a fresh review");

  const reopened = expect(
    await call("POST", "/api/v1/provider/me/application/reopen", refusedToken),
    200,
    "reopen",
  );
  assert.equal(reopened.status, "NEEDS_CHANGES");
  assert.equal(reopened.reviewNote, "وضّحي الخدمة.");
  assert.ok(reopened.reopenedAt);
  expect(
    await call("POST", "/api/v1/provider/me/application/reopen", refusedToken),
    409,
    "reopen twice",
    "PROVIDER_NOT_REJECTED",
  );
  expect(
    await call("PATCH", "/api/v1/provider/me/profile", refusedToken, {
      description: "كوافيرة من البيت في المنصورة.",
    }),
    200,
    "edit after reopening",
  );
  assert.equal(reopened.latestDecision.kind, "REJECTED");
  const back = expect(
    await resubmit(refusedToken, reopened.latestDecision.id),
    200,
    "resubmit after reopening",
  );
  assert.equal(back.status, "PENDING");
  const refusedHistory = expect(
    await call("GET", `/admin/providers/${refusedApplication.id}/review-history`, adminToken),
    200,
    "history of a refused profile",
  );
  assert.deepEqual(
    refusedHistory.events.map((event: any) => event.kind),
    ["REJECTED", "REOPENED", "RESUBMITTED"],
  );
  assert.equal(refusedHistory.events[0].notes[0].note, "وضّحي الخدمة.");
  const refusedRow = expect(
    await call("GET", `/admin/providers/applications/${refusedApplication.id}`, adminToken),
    200,
    "the refused profile in the queue",
  );
  assert.ok(refusedRow.reopenedAt);
  assert.equal(refusedRow.resubmitCount, 1);
  // Finding 6: it reads «كان مرفوض» from the decision before the send.
  assert.equal(refusedRow.latestDecision.kind, "REJECTED");
  expect(
    await call("PATCH", `/admin/providers/${refusedApplication.id}/approve`, adminToken),
    200,
    "approve after the fresh review",
  );
  pass("«قدّم من جديد» reopens the refusal with its reason as the note, then the fix goes back to review");

  // ---------------------------------------------------------------- B-12
  const listing = expect(
    await call("POST", "/admin/providers", adminToken, {
      businessName: `${label} ملف بلا حساب`,
      phone: claimant.phone,
      cityId: city.id,
      categoryId: category.id,
    }),
    201,
    "list a provider without an account",
  );
  const offered = expect(
    await call("GET", "/api/v1/provider/claimable", claimantToken),
    200,
    "claimable listing",
  );
  assert.equal(offered.listing?.id, listing.id);
  // Finding 13: p02 names the listing's category and city.
  assert.equal(offered.listing.primaryCategory?.nameAr, category.nameAr);
  assert.equal(offered.listing.city?.nameAr, city.nameAr);
  assert.deepEqual(
    expect(await call("GET", "/api/v1/provider/me/claim", claimantToken), 200, "no claim yet"),
    { claim: null },
  );
  const claim = expect(
    await call("POST", `/api/v1/provider/claim/${listing.id}`, claimantToken),
    201,
    "claim",
  );
  assert.equal(claim.status, "PENDING");
  expect(
    await call("POST", `/api/v1/provider/claim/${listing.id}`, claimantToken),
    409,
    "claim twice",
    "PROVIDER_CLAIM_PENDING",
  );
  const listingRow = await prisma.provider.findUniqueOrThrow({ where: { id: listing.id } });
  assert.equal(listingRow.userId, null);
  expect(
    await call("POST", `/api/v1/providers/${listing.id}/quote-requests`, customerToken, {
      message: "عندك الخميس؟",
    }),
    409,
    "a request to the listing while the claim waits",
    "PROVIDER_NOT_CLAIMED",
  );
  pass("a claim waits for review; the listing stays unclaimed and takes no requests");

  const waiting = expect(
    await call("GET", "/admin/provider-claims?status=PENDING", adminToken),
    200,
    "claims queue",
  );
  const queued = waiting.items.find((item: any) => item.id === claim.id);
  assert.ok(queued);
  assert.equal(queued.provider.id, listing.id);
  assert.equal(queued.claimant.phone, claimant.phone);
  expect(
    await call("POST", `/admin/provider-claims/${claim.id}/reject`, adminToken, {}),
    400,
    "refuse without a reason",
  );
  expect(
    await call("POST", `/admin/provider-claims/${claim.id}/reject`, adminToken, {
      note: "اتصلنا بالرقم وما رد.",
    }),
    201,
    "refuse the claim",
  );
  const refusedClaim = expect(
    await call("GET", "/api/v1/provider/me/claim", claimantToken),
    200,
    "claim after refusal",
  );
  assert.equal(refusedClaim.claim.status, "REJECTED");
  assert.equal(refusedClaim.claim.note, "اتصلنا بالرقم وما رد.");
  assert.ok(
    await prisma.notification.findFirst({
      where: { userId: claimant.id, title: "ما قبلنا الاستلام" },
    }),
  );
  pass("a refused claim tells the claimant why");

  const second = expect(
    await call("POST", `/api/v1/provider/claim/${listing.id}`, claimantToken),
    201,
    "claim again",
  );
  // Finding 4: the account's phone changed after the claim was sent; it no
  // longer proves the listing is his.
  await prisma.user.update({
    where: { id: claimant.id },
    data: { phone: scopedPhone("claimant-moved") },
  });
  expect(
    await call("POST", `/admin/provider-claims/${second.id}/approve`, adminToken),
    409,
    "approve a claim whose phone changed",
    "PROVIDER_CLAIM_PHONE_CHANGED",
  );
  const unlinked = await prisma.provider.findUniqueOrThrow({ where: { id: listing.id } });
  assert.equal(unlinked.userId, null);
  await prisma.user.update({ where: { id: claimant.id }, data: { phone: claimant.phone } });
  pass("a claim is not approved once the claimant's phone no longer matches the listing");

  const decided = expect(
    await call("POST", `/admin/provider-claims/${second.id}/approve`, adminToken),
    201,
    "approve the claim",
  );
  assert.equal(decided.status, "APPROVED");
  expect(
    await call("POST", `/admin/provider-claims/${second.id}/approve`, adminToken),
    409,
    "approve twice",
    "PROVIDER_CLAIM_NOT_PENDING",
  );
  const linked = await prisma.provider.findUniqueOrThrow({ where: { id: listing.id } });
  assert.equal(linked.userId, claimant.id);
  const promoted = await prisma.user.findUniqueOrThrow({ where: { id: claimant.id } });
  assert.equal(promoted.role, UserRole.PROVIDER);
  const claimedProfile = expect(
    await call("GET", "/api/v1/provider/me/profile", claimantToken),
    200,
    "the claimed profile",
  );
  assert.equal(claimedProfile.id, listing.id);
  assert.equal(claimedProfile.status, "ACTIVE");
  pass("an approved claim links the listing to the account, once");

  console.log(`\nProvider lifecycle smoke: ${checks} checks passed.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
