import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { JwtService } from "@nestjs/jwt";
import {
  AdminRole,
  AuthSessionScope,
  PrismaClient,
  ProviderStatus,
  UserRole,
  UserStatus,
  type User,
} from "@prisma/client";
import { FeaturedPeriodNoticesService } from "../../src/marketplace/featured-period-notices.service";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { notificationsService, ownerPorts } from "./support/owner-ports";

// Featured placement over HTTP on a real database (B-43, D41, G05): who may
// record it, what a placement may cover, the customers' list ranking the
// featured first with «مميز», the provider reading his placement, a renewal
// booked after it, cancelling and stopping one, the placement lapsing at its
// end by itself, the one placement rule (a provider customers cannot find is
// not featured, shown as such and counted nowhere), two grants at the same
// moment and the database's own refusal of an overlap, and the hourly job
// telling the provider once of a booked start, a last week and an end. No money is
// sent or kept anywhere. Run it with `npm run smoke:featured-placement`: the
// managed runner gives it an isolated database and its own API.

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const baseUrl = process.env.SMOKE_BASE_URL!;
const prisma = new PrismaClient();
const jwt = new JwtService({ secret: process.env.JWT_SECRET });
const label = `Featured ${runId}`;
const DAY_MS = 24 * 60 * 60 * 1000;
let checks = 0;

/** A Yemeni mobile number unique to this run and role. */
function scopedPhone(role: string): string {
  // smoke:all runs every suite under one run id: the suite name keeps
  // another suite's «customer» from taking this one's phone.
  const digits = createHash("sha256")
    .update(`${runId}:featured-placement:${role}`)
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

async function call(method: string, path: string, token: string, body?: unknown): Promise<Reply> {
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

async function session(user: User, scope: "admin" | "application"): Promise<string> {
  const stored = await prisma.refreshToken.create({
    data: {
      userId: user.id,
      tokenHash: `featured-${runId}-${user.id}-${scope}`,
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

async function account(role: string, userRole: UserRole, adminRole: AdminRole | null = null): Promise<User> {
  return prisma.user.create({
    data: {
      name: `${label} ${role}`,
      phone: scopedPhone(role),
      phoneVerifiedAt: new Date(),
      passwordHash: "managed-smoke-not-a-credential",
      appAccountActivatedAt: new Date(),
      role: userRole,
      adminRole,
      status: UserStatus.ACTIVE,
    },
  });
}

/** The Yemen calendar day (`YYYY-MM-DD`) that many days from now. */
function yemenDay(offset: number): string {
  return new Date(Date.now() + 3 * 60 * 60 * 1000 + offset * DAY_MS).toISOString().slice(0, 10);
}

async function main(): Promise<void> {
  const operations = await account("operations", UserRole.ADMIN, AdminRole.OPERATIONS);
  const support = await account("support", UserRole.ADMIN, AdminRole.SUPPORT);
  const customer = await account("customer", UserRole.USER);
  const ownerA = await account("owner-a", UserRole.PROVIDER);
  const ownerB = await account("owner-b", UserRole.PROVIDER);
  const ownerPending = await account("owner-pending", UserRole.PROVIDER);
  const city = await prisma.city.create({ data: { nameAr: `${label} مدينة`, countryCode: "YE" } });
  const category = await prisma.providerCategory.create({
    data: { nameAr: `${label} قسم`, slug: `featured-${runId}`.replace(/_/g, "-").toLowerCase() },
  });
  const listing = async (
    key: string,
    userId: string | null,
    rating: string,
    status: ProviderStatus = ProviderStatus.ACTIVE,
  ) => {
    const provider = await prisma.provider.create({
      data: {
        userId,
        cityId: city.id,
        primaryCategoryId: category.id,
        businessName: `${label} ${key}`,
        phone: scopedPhone(`listing-${key}`),
        status,
        ratingAverage: rating,
      },
    });
    await prisma.providerService.create({
      data: {
        providerId: provider.id,
        categoryId: category.id,
        title: `${label} ${key} خدمة`,
        basePrice: "300000",
        isActive: true,
      },
    });
    return provider;
  };
  // B has the better rating: without a placement it would come first.
  const providerA = await listing("A", ownerA.id, "3.50");
  const providerB = await listing("B", ownerB.id, "4.90");
  const unclaimed = await listing("unclaimed", null, "4.00");
  const pending = await listing("pending", ownerPending.id, "4.00", ProviderStatus.PENDING);
  // Approved and claimed, but his only service is switched off: customers
  // do not find him, so a placement would rank and badge nothing.
  const ownerHidden = await account("owner-hidden", UserRole.PROVIDER);
  const hidden = await listing("hidden", ownerHidden.id, "4.00");
  await prisma.providerService.updateMany({ where: { providerId: hidden.id }, data: { isActive: false } });
  // Two administrators record a placement for him at the same moment; he
  // works in another city, out of the list this smoke reads.
  const ownerRace = await account("owner-race", UserRole.PROVIDER);
  const elsewhere = await prisma.city.create({ data: { nameAr: `${label} مدينة ثانية`, countryCode: "YE" } });
  const race = await listing("race", ownerRace.id, "1.00");
  await prisma.provider.update({ where: { id: race.id }, data: { cityId: elsewhere.id } });

  const opsToken = await session(operations, "admin");
  const supportToken = await session(support, "admin");
  const customerToken = await session(customer, "application");
  const ownerAToken = await session(ownerA, "application");
  const list = (query = "") =>
    call("GET", `/api/v1/providers?cityId=${city.id}&categoryId=${category.id}${query}`, customerToken);
  const grant = (token: string, providerId: string, body: unknown) =>
    call("POST", `/admin/providers/${providerId}/featured-periods`, token, body);

  // ------------------------------------------------------------ permission
  expect(await call("GET", "/admin/featured-periods/summary", supportToken), 200, "support reads the placements");
  expect(
    await grant(supportToken, providerA.id, { endsOn: yemenDay(30) }),
    403,
    "support records a placement",
  );
  expect(await grant(customerToken, providerA.id, { endsOn: yemenDay(30) }), 403, "a customer records a placement");
  assert.equal(await prisma.providerFeaturedPeriod.count({ where: { providerId: providerA.id } }), 0);
  pass("only an administrator who may write providers records a placement; support reads it");

  // ------------------------------------------------------------ what a placement may cover
  expect(await grant(opsToken, unclaimed.id, { endsOn: yemenDay(30) }), 409, "an unclaimed listing", "FEATURED_PROVIDER_UNCLAIMED");
  expect(await grant(opsToken, pending.id, { endsOn: yemenDay(30) }), 409, "a provider under review", "FEATURED_PROVIDER_NOT_ACTIVE");
  expect(
    await grant(opsToken, providerA.id, { startsOn: yemenDay(-3), endsOn: yemenDay(30) }),
    422,
    "a back-dated start",
    "FEATURED_PERIOD_START_PAST",
  );
  expect(await grant(opsToken, providerA.id, { endsOn: yemenDay(400) }), 422, "more than a year", "FEATURED_PERIOD_TOO_LONG");
  expect(await grant(opsToken, providerA.id, { endsOn: yemenDay(-1) }), 422, "a placement already over", "FEATURED_PERIOD_INVALID");
  expect(await grant(opsToken, providerA.id, { endsOn: "2026-02-30" }), 422, "a day that does not exist", "FEATURED_PERIOD_INVALID");
  expect(
    await grant(opsToken, hidden.id, { endsOn: yemenDay(30) }),
    409,
    "a provider customers cannot find",
    "FEATURED_PROVIDER_NOT_LISTED",
  );
  assert.equal(await prisma.providerFeaturedPeriod.count({ where: { providerId: hidden.id } }), 0);
  pass("a placement needs a claimed, active, listed provider, starts now or later, and covers at most a year");

  // ------------------------------------------------------------ grant and ranking
  const before = expect(await list(), 200, "the list before");
  assert.deepEqual(before.items.map((item: any) => item.id), [providerB.id, unclaimed.id, providerA.id]);
  assert.ok(before.items.every((item: any) => item.isFeatured === false));
  const granted = expect(
    await grant(opsToken, providerA.id, { endsOn: yemenDay(30), note: "كاش · شهر" }),
    201,
    "operations records a month",
  );
  assert.equal(granted.state, "ACTIVE");
  assert.equal(granted.lastDay, yemenDay(30));
  assert.equal(granted.note, "كاش · شهر");
  assert.equal(granted.grantedBy?.id, operations.id);
  assert.equal("amount" in granted, false);
  const audit = await prisma.adminAuditLog.findMany({
    where: { actorUserId: operations.id, targetId: providerA.id, route: { contains: "featured-periods" } },
  });
  assert.ok(audit.some((row) => row.phase === "SUCCEEDED"), "the grant is in the audit log");
  const startNotice = await prisma.notification.findFirst({
    where: { userId: ownerA.id, entityId: granted.id },
  });
  assert.equal(startNotice?.title, "تفعّل ظهورك المميز");
  assert.ok(startNotice?.body.includes("يطلع مع المميزين أول"), "the provider is told what is true");
  assert.equal(startNotice?.body.includes("قسمك ومدينتك"), false);
  pass("a recorded month is audited, keeps no amount, and tells the provider it started");

  const after = expect(await list(), 200, "the list after");
  assert.deepEqual(after.items.map((item: any) => item.id), [providerA.id, providerB.id, unclaimed.id]);
  assert.deepEqual(after.items.map((item: any) => item.isFeatured), [true, false, false]);
  // Until when: a phone showing a saved copy drops «مميز» once it passed.
  assert.equal(new Date(after.items[0].featuredUntil).toISOString(), granted.endsAt);
  assert.deepEqual(after.items.slice(1).map((item: any) => item.featuredUntil), [null, null]);
  const pageTwo = expect(await list("&limit=1&page=2"), 200, "the second page of one");
  assert.deepEqual(pageTwo.items.map((item: any) => item.id), [providerB.id]);
  assert.equal(pageTwo.total, 3);
  const onlyFeatured = expect(await list("&featured=true"), 200, "featured only");
  assert.deepEqual(onlyFeatured.items.map((item: any) => item.id), [providerA.id]);
  const page = expect(await call("GET", `/api/v1/providers/${providerA.id}`, customerToken), 200, "the provider's page");
  assert.equal(page.isFeatured, true);
  // One source of featuring: a service carries no flag of its own.
  assert.ok(page.services.length > 0 && page.services.every((service: any) => !("isFeatured" in service)));
  pass("the featured provider comes first with «مميز» across pages; the filter and the page agree");

  const profile = expect(await call("GET", "/api/v1/provider/me/profile", ownerAToken), 200, "the provider's profile");
  assert.equal(profile.featured?.active, true);
  assert.equal(new Date(profile.featured.endsAt).toISOString(), granted.endsAt);
  pass("the provider reads his placement and until when");

  // ------------------------------------------------------------ renewal, overlap, cancel
  expect(
    await grant(opsToken, providerA.id, { startsOn: yemenDay(20), endsOn: yemenDay(50) }),
    409,
    "an overlapping placement",
    "FEATURED_PERIOD_OVERLAP",
  );
  const renewal = expect(
    await grant(opsToken, providerA.id, { startsOn: yemenDay(31), endsOn: yemenDay(60) }),
    201,
    "a renewal booked after it",
  );
  assert.equal(renewal.state, "SCHEDULED");
  // The renewal starts the day after: he reads where the run really ends.
  const runProfile = expect(await call("GET", "/api/v1/provider/me/profile", ownerAToken), 200, "his profile with a renewal");
  assert.equal(new Date(runProfile.featured.endsAt).toISOString(), renewal.endsAt);
  const cancelled = expect(
    await call("POST", `/admin/featured-periods/${renewal.id}/end`, opsToken, {}),
    201,
    "cancelling the renewal",
  );
  assert.equal(cancelled.state, "ENDED");
  const bookedNotice = await prisma.notification.findFirst({
    where: { userId: ownerA.id, entityId: renewal.id, title: "ظهورك المميز محجوز" },
  });
  assert.ok(bookedNotice?.body.includes("يبدأ"), "the provider is told the renewal is booked");
  const cancelledNotice = await prisma.notification.findFirst({
    where: { userId: ownerA.id, entityId: renewal.id, title: "لغينا ظهورك المميز" },
  });
  assert.ok(cancelledNotice, "the provider is told the renewal was cancelled");
  pass("placements never overlap; a renewal is booked after one and can be cancelled before it starts");

  // ------------------------------------------------------------ lapsing at its end, and the job
  const permissions = new PermissionService(prisma as any, ownerPorts.plans);
  const notices = new FeaturedPeriodNoticesService(
    prisma as any,
    notificationsService(prisma, permissions, { enqueue: async () => undefined }) as any,
  );
  // Ten days pass: A's month is over.
  await prisma.providerFeaturedPeriod.update({
    where: { id: granted.id },
    data: { startsAt: new Date(Date.now() - 40 * DAY_MS), endsAt: new Date(Date.now() - 60 * 1000) },
  });
  const lapsed = expect(await list(), 200, "the list after the end");
  assert.deepEqual(lapsed.items.map((item: any) => item.id), [providerB.id, unclaimed.id, providerA.id]);
  assert.ok(lapsed.items.every((item: any) => item.isFeatured === false));
  const lapsedProfile = expect(await call("GET", "/api/v1/provider/me/profile", ownerAToken), 200, "his profile after the end");
  assert.equal(lapsedProfile.featured, null);
  const finished = expect(
    await call("GET", `/admin/featured-periods?state=FINISHED&providerId=${providerA.id}`, opsToken),
    200,
    "the finished placements",
  );
  assert.deepEqual(finished.items.map((item: any) => [item.id, item.state]).sort(), [
    [granted.id, "EXPIRED"],
    [renewal.id, "ENDED"],
  ].sort());
  expect(
    await call("POST", `/admin/featured-periods/${granted.id}/end`, opsToken, {}),
    409,
    "ending a placement already over",
    "FEATURED_PERIOD_FINISHED",
  );
  pass("at its end the placement lapses by itself: no badge, no ranking, nothing for the provider to read");

  // ------------------------------------------------------------ the database refuses overlaps too
  // Two administrators record a month for the same provider at the same
  // moment: one placement is recorded, the other is refused.
  const raced = await Promise.all([
    grant(opsToken, race.id, { endsOn: yemenDay(30), note: "أول" }),
    grant(opsToken, race.id, { endsOn: yemenDay(30), note: "ثاني" }),
  ]);
  assert.deepEqual(raced.map((reply) => reply.status).sort(), [201, 409], JSON.stringify(raced));
  assert.equal(raced.find((reply) => reply.status === 409)!.body.code, "FEATURED_PERIOD_OVERLAP");
  assert.equal(await prisma.providerFeaturedPeriod.count({ where: { providerId: race.id } }), 1);
  // A writer that skips the check (a script, a seed) is refused by the
  // constraint itself; an ended period does not count.
  const racedPeriod = raced.find((reply) => reply.status === 201)!.body;
  await assert.rejects(
    prisma.providerFeaturedPeriod.create({
      data: {
        providerId: race.id,
        startsAt: new Date(Date.now() + 2 * DAY_MS),
        endsAt: new Date(Date.now() + 5 * DAY_MS),
        grantedById: operations.id,
      },
    }),
    /ProviderFeaturedPeriod_no_overlap|23P01|exclusion/i,
  );
  await prisma.providerFeaturedPeriod.create({
    data: {
      providerId: race.id,
      startsAt: new Date(Date.now() + 2 * DAY_MS),
      endsAt: new Date(Date.now() + 5 * DAY_MS),
      grantedById: operations.id,
      endedAt: new Date(),
      endedById: operations.id,
    },
  });
  pass("two grants at the same moment record one placement; the database refuses any overlap");

  // ------------------------------------------------------------ the hourly job
  // B gets three days: no «ينتهي قريب» minutes after it started.
  const short = expect(await grant(opsToken, providerB.id, { endsOn: yemenDay(2) }), 201, "a short placement");
  // The raced month is in its last week: 25 of its days passed.
  await prisma.providerFeaturedPeriod.update({
    where: { id: racedPeriod.id },
    data: { startsAt: new Date(Date.now() - 25 * DAY_MS), endsAt: new Date(Date.now() + 4 * DAY_MS) },
  });
  const firstRun = await notices.run();
  assert.deepEqual(firstRun.failures, []);
  assert.ok(firstRun.ended >= 1 && firstRun.warned >= 1);
  const secondRun = await notices.run();
  assert.equal(secondRun.started + secondRun.ended + secondRun.warned, 0, "the job tells nobody twice");
  const endedNotices = await prisma.notification.count({ where: { userId: ownerA.id, title: "خلص ظهورك المميز" } });
  const warnings = await prisma.notification.count({ where: { userId: ownerRace.id, entityId: racedPeriod.id, title: "ظهورك المميز ينتهي قريب" } });
  const shortWarnings = await prisma.notification.count({ where: { userId: ownerB.id, entityId: short.id, title: "ظهورك المميز ينتهي قريب" } });
  assert.equal(endedNotices, 1);
  assert.equal(warnings, 1);
  assert.equal(shortWarnings, 0, "a three-day placement is not warned about as it starts");
  // A booked from tomorrow; the day comes: he is told once that it started.
  const booked = expect(
    await grant(opsToken, providerA.id, { startsOn: yemenDay(1), endsOn: yemenDay(20) }),
    201,
    "a placement booked from tomorrow",
  );
  await prisma.providerFeaturedPeriod.update({
    where: { id: booked.id },
    data: { startsAt: new Date(Date.now() - 30 * 1000) },
  });
  const startRun = await notices.run();
  assert.equal(startRun.started, 1);
  assert.equal((await notices.run()).started, 0);
  const started = await prisma.notification.findMany({ where: { userId: ownerA.id, entityId: booked.id, title: "بدأ ظهورك المميز" } });
  assert.equal(started.length, 1);
  assert.ok(started[0]!.body.includes("يطلع مع المميزين أول"));
  pass("the hourly job tells a booked start once, warns a long placement once in its last week, and its end once");

  // ------------------------------------------------------------ stop early and the summary
  const summaryBefore = expect(await call("GET", "/admin/featured-periods/summary", opsToken), 200, "the summary");
  assert.ok(summaryBefore.featured >= 1 && summaryBefore.endingThisWeek >= 1);
  // B's only service is switched off while his placement runs: customers do
  // not find him, so a17 says so instead of «شغّال», and nothing counts him.
  await prisma.providerService.updateMany({ where: { providerId: providerB.id }, data: { isActive: false } });
  const hiddenRows = expect(
    await call("GET", `/admin/featured-periods?state=ACTIVE&providerId=${providerB.id}`, opsToken),
    200,
    "B's placements while he is out of the list",
  );
  assert.deepEqual(hiddenRows.items.map((item: any) => [item.id, item.state, item.providerShown]), [[short.id, "ACTIVE", false]]);
  const summaryHidden = expect(await call("GET", "/admin/featured-periods/summary", opsToken), 200, "the summary while B is out");
  assert.equal(summaryHidden.featured, summaryBefore.featured - 1);
  assert.equal(summaryHidden.endingThisWeek, summaryBefore.endingThisWeek - 1);
  await prisma.providerService.updateMany({ where: { providerId: providerB.id }, data: { isActive: true } });
  pass("a running placement on a provider customers cannot find is shown as such and counted nowhere");

  const stopped = expect(
    await call("POST", `/admin/featured-periods/${short.id}/end`, opsToken, { note: "طلب يوقفها" }),
    201,
    "stopping B early",
  );
  assert.equal(stopped.state, "ENDED");
  assert.equal(stopped.endNote, "طلب يوقفها");
  assert.equal(stopped.endedBy?.id, operations.id);
  const stopNotice = await prisma.notification.findFirst({
    where: { userId: ownerB.id, entityId: short.id, title: "وقّفنا ظهورك المميز" },
  });
  // The note is added to the standard sentence, never instead of it.
  assert.equal(stopNotice?.body, "من اليوم ملفك يظهر عادي. لو عندك سؤال كلّم فريق اعّرست.\nملاحظة الفريق: طلب يوقفها");
  const afterStop = expect(await list(), 200, "the list after stopping");
  // Only A's placement (booked, now started) still runs.
  assert.deepEqual(
    afterStop.items.filter((item: any) => item.isFeatured).map((item: any) => item.id),
    [providerA.id],
  );
  const summaryAfter = expect(await call("GET", "/admin/featured-periods/summary", opsToken), 200, "the summary after");
  assert.equal(summaryAfter.featured, summaryBefore.featured - 1);
  assert.equal(summaryAfter.free, summaryBefore.free + 1);
  assert.equal((await notices.run()).warned, 0, "a stopped placement is not warned about");
  pass("an administrator stops a placement early with a note the provider reads; the summary follows");

  console.log(`\nFeatured placement smoke: ${checks} checks passed.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
