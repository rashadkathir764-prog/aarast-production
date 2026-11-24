import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { MediaUploadStatus } from "@prisma/client";
import { MediaUploadTicketService } from "../src/modules/media/infrastructure/media-upload-ticket.service";
import { providerDashboardService } from "./support/owner-ports";
import { AdminProfileChangeReview } from "../src/admin/admin-profile-change-review";
import { runAuditedAdminRequest } from "../src/modules/backoffice/public/admin-audit-change";
import { decideProfileChange } from "../src/modules/marketplace/infrastructure/provider-profile-change.repository";

// RA-BE-152 (Q-39 (أ), D124): an approved provider's new name, logo, cover,
// city or category waits for the team; the listing keeps its live values
// and images until the team approves.

type Ticket = {
  key: string;
  status: MediaUploadStatus;
  consumedByType: string | null;
  consumedById: string | null;
  consumedAt: Date | null;
};

function ticketStore(tickets: Ticket[]) {
  const matches = (row: Ticket, where: any) =>
    (where.key === undefined || row.key === where.key) &&
    (where.status === undefined || row.status === where.status) &&
    (where.consumedByType === undefined || row.consumedByType === where.consumedByType) &&
    (where.consumedById === undefined || row.consumedById === where.consumedById);
  return {
    $queryRaw: async () => [{ locked: true }],
    mediaUploadTicket: {
      findMany: async ({ where }: any) =>
        tickets.filter((row) => matches(row, where)).map((row) => ({ key: row.key })),
      updateMany: async ({ where, data }: any) => {
        const rows = tickets.filter((row) => matches(row, where));
        for (const row of rows) Object.assign(row, data);
        return { count: rows.length };
      },
    },
  };
}

const LOGO = { type: "PROVIDER_LOGO", id: "provider-1" } as const;
const PENDING_LOGO = { type: "PROVIDER_PROFILE_CHANGE_LOGO", id: "change-1" } as const;

test("RA-BE-152: the pending logo becomes the listing's only on approval, and the old one is deleted then", async () => {
  const tickets: Ticket[] = [
    { key: "old", status: MediaUploadStatus.VERIFIED, consumedByType: LOGO.type, consumedById: LOGO.id, consumedAt: new Date(0) },
    { key: "new", status: MediaUploadStatus.VERIFIED, consumedByType: PENDING_LOGO.type, consumedById: PENDING_LOGO.id, consumedAt: new Date(0) },
  ];
  const service = new MediaUploadTicketService({} as any);
  await service.promoteTargetMedia(PENDING_LOGO, LOGO, ticketStore(tickets) as any);

  const [old, next] = tickets;
  assert.equal(old.status, MediaUploadStatus.DELETE_PENDING);
  assert.equal(next.status, MediaUploadStatus.VERIFIED);
  assert.deepEqual([next.consumedByType, next.consumedById], [LOGO.type, LOGO.id]);
});

test("RA-BE-152: approving a change whose pending image is gone leaves the live image in place", async () => {
  const tickets: Ticket[] = [
    { key: "old", status: MediaUploadStatus.VERIFIED, consumedByType: LOGO.type, consumedById: LOGO.id, consumedAt: new Date(0) },
  ];
  const service = new MediaUploadTicketService({} as any);
  await assert.rejects(
    () => service.promoteTargetMedia(PENDING_LOGO, LOGO, ticketStore(tickets) as any),
    (error: any) => error?.response?.code === "PENDING_MEDIA_UNAVAILABLE",
  );
  assert.equal(tickets[0].status, MediaUploadStatus.VERIFIED);
});

// ---------------------------------------------------------------------------
// The provider's edit: the reviewed fields wait, the rest goes live.

const CITY = "11111111-1111-4111-8111-111111111111";
const CATEGORY = "22222222-2222-4222-8222-222222222222";
const OTHER_CATEGORY = "33333333-3333-4333-8333-333333333333";
const OLD_LOGO = "https://media.example/provider-logo/u1/old.png";
const NEW_LOGO = "https://media.example/provider-logo/u1/new.png";

function providerHarness(status: "ACTIVE" | "PENDING" = "ACTIVE") {
  const provider: any = {
    id: "p1",
    userId: "u1",
    status,
    businessName: "استوديو ضوء",
    ownerName: null,
    phone: "+967777000000",
    whatsapp: null,
    email: null,
    description: "قديم",
    address: null,
    latitude: null,
    longitude: null,
    cityId: CITY,
    primaryCategoryId: CATEGORY,
    logoUrl: OLD_LOGO,
    coverUrl: null,
    logoThumbUrl: null,
    logoMediumUrl: null,
    coverThumbUrl: null,
    coverMediumUrl: null,
    ratingAverage: { toString: () => "0" },
    ratingCount: 0,
    dailyBookingCapacity: 1,
    socialLinks: null,
    createdAt: new Date(0),
    updatedAt: new Date(0),
  };
  const changes: any[] = [];
  const media: Array<[string, string, string]> = [];
  const services = [{ providerId: "p1", categoryId: CATEGORY, isActive: true }];
  const prisma: any = {
    $queryRaw: async (query: any) => {
      const text = (query?.strings ?? query?.sql ?? []).join?.("") ?? String(query?.sql ?? "");
      if (text.includes('"User"')) return [{ id: "u1", status: "ACTIVE" }];
      if (text.includes('"Provider"')) return [{ id: "p1" }];
      return [];
    },
    provider: {
      findUnique: async () => ({ ...provider }),
      update: async ({ data }: any) => Object.assign(provider, data),
    },
    providerProfileChange: {
      findFirst: async ({ where }: any) =>
        changes.find((row) => row.providerId === where.providerId && row.status === where.status) ?? null,
      create: async ({ data }: any) => {
        const row = { id: `change-${changes.length + 1}`, status: "PENDING", createdAt: new Date(), updatedAt: new Date(), ...data };
        changes.push(row);
        return { ...row };
      },
      update: async ({ where, data }: any) => {
        const row = changes.find((item) => item.id === where.id);
        Object.assign(row, data);
        return { ...row };
      },
      updateMany: async ({ where, data }: any) => {
        const rows = changes.filter((item) => item.id === where.id && item.status === where.status);
        for (const row of rows) Object.assign(row, data);
        return { count: rows.length };
      },
    },
    providerService: {
      findMany: async ({ where }: any) =>
        services.filter((row) => row.providerId === where.providerId && row.isActive === where.isActive),
    },
    providerReviewEvent: { findFirst: async () => null, findMany: async () => [] },
    providerFeaturedPeriod: { findMany: async () => [] },
    portfolioItem: { findMany: async () => [] },
    city: { findMany: async () => [{ id: CITY, nameAr: "صنعاء", nameEn: "Sanaa", countryCode: "YE", sortOrder: 0 }] },
    providerCategory: {
      findMany: async () => [{ id: CATEGORY, nameAr: "تصوير", nameEn: null, slug: "photo", icon: null, showForGroom: true, showForBride: true, sortOrder: 0 }],
    },
  };
  prisma.$transaction = async (operation: any) => operation(prisma);
  const mediaStorage = {
    verifyPublicMediaUrl: async (_user: unknown, value: string | null) => value,
    consumePublicMediaUrl: async (_u: unknown, value: string, _p: unknown, target: any) => {
      media.push(["consume", `${target.type}:${target.id}`, value]);
    },
    scheduleTargetDeletion: async (target: any) => {
      media.push(["delete", `${target.type}:${target.id}`, ""]);
    },
  };
  const service = providerDashboardService(prisma, {}, mediaStorage, {});
  return { service, provider, changes, media };
}

const user = { id: "u1" } as any;

test("RA-BE-152: an approved provider's new name and logo wait for the team; his description goes live", async () => {
  const { service, provider, changes, media } = providerHarness();
  const profile: any = await service.updateProfile(user, {
    businessName: "استوديو ضوء الجديد",
    logoUrl: NEW_LOGO,
    description: "نبذة جديدة",
  } as any);

  assert.equal(provider.businessName, "استوديو ضوء");
  assert.equal(provider.logoUrl, OLD_LOGO);
  assert.equal(provider.description, "نبذة جديدة");
  assert.equal(changes.length, 1);
  assert.equal(changes[0].businessName, "استوديو ضوء الجديد");
  assert.equal(changes[0].logoUrl, NEW_LOGO);
  // The new logo is held by the request; the live one is not touched.
  assert.deepEqual(media, [["consume", "PROVIDER_PROFILE_CHANGE_LOGO:change-1", NEW_LOGO]]);
  assert.equal(profile.businessName, "استوديو ضوء");
  assert.equal(profile.pendingChange.businessName, "استوديو ضوء الجديد");
  assert.equal(profile.pendingChange.logoUrl, NEW_LOGO);
});

test("RA-BE-152: before approval his name still changes at once", async () => {
  const { service, provider, changes } = providerHarness("PENDING");
  const profile: any = await service.updateProfile(user, { businessName: "اسم آخر" } as any);
  assert.equal(provider.businessName, "اسم آخر");
  assert.equal(changes.length, 0);
  assert.equal(profile.pendingChange, null);
});

test("RA-BE-152: a later edit updates the waiting request, and setting a field back takes it out", async () => {
  const { service, changes, media } = providerHarness();
  await service.updateProfile(user, { businessName: "اسم جديد", logoUrl: NEW_LOGO } as any);
  // He typed his live name back: only the logo still waits.
  await service.updateProfile(user, { businessName: "استوديو ضوء" } as any);
  assert.equal(changes.length, 1);
  assert.equal(changes[0].businessName, null);
  assert.equal(changes[0].logoUrl, NEW_LOGO);
  assert.equal(changes[0].status, "PENDING");
  // And the live logo back: nothing waits, and the held image is deleted.
  await service.updateProfile(user, { logoUrl: OLD_LOGO } as any);
  assert.equal(changes[0].status, "WITHDRAWN");
  assert.deepEqual(media[media.length - 1], ["delete", "PROVIDER_PROFILE_CHANGE_LOGO:change-1", ""]);
});

test("RA-BE-152: «اسحب التعديل» withdraws the waiting change and deletes its image; the listing stays", async () => {
  const { service, provider, changes, media } = providerHarness();
  await service.updateProfile(user, { businessName: "اسم جديد", logoUrl: NEW_LOGO } as any);
  const profile: any = await service.withdrawProfileChange(user);
  assert.equal(changes[0].status, "WITHDRAWN");
  assert.ok(changes[0].decidedAt instanceof Date);
  assert.deepEqual(media[media.length - 1], ["delete", "PROVIDER_PROFILE_CHANGE_LOGO:change-1", ""]);
  assert.equal(provider.businessName, "استوديو ضوء");
  assert.equal(profile.pendingChange, null);
  await assert.rejects(
    () => service.withdrawProfileChange(user),
    (error: any) => error?.response?.code === "PROFILE_CHANGE_NOT_FOUND",
  );
});

test("RA-BE-152: after approval a service does not open a section the listing is not in", async () => {
  const { service } = providerHarness();
  await assert.rejects(
    () =>
      service.createService(user, {
        categoryId: OTHER_CATEGORY,
        title: "قاعة",
        basePrice: "100000",
      } as any),
    (error: any) => error?.response?.code === "PROVIDER_CATEGORY_LOCKED",
  );
});

// ---------------------------------------------------------------------------
// The team's decision (back office, behind PROVIDERS_WRITE and the audit log).

function waitingChange(overrides: Record<string, unknown> = {}) {
  return {
    id: "change-1",
    providerId: "p1",
    status: "PENDING",
    businessName: "استوديو ضوء الجديد",
    cityId: null,
    primaryCategoryId: null,
    logoUrl: NEW_LOGO,
    coverUrl: null,
    rejectionReason: null,
    decidedAt: null,
    decidedById: null,
    createdAt: new Date(0),
    updatedAt: new Date(0),
    provider: {
      id: "p1",
      businessName: "استوديو ضوء",
      userId: "u1",
      status: "ACTIVE",
      cityId: CITY,
      primaryCategoryId: CATEGORY,
      logoUrl: OLD_LOGO,
      coverUrl: null,
    },
    ...overrides,
  };
}

function reviewHarness(change = waitingChange()) {
  const calls: Array<[string, unknown]> = [];
  const notices: any[] = [];
  const review = new AdminProfileChangeReview({
    prisma: { $transaction: async (operation: any) => operation({}) } as any,
    owners: {
      marketplace: {
        lockProfileChangeInTransaction: async () => change,
        decideProfileChangeInTransaction: async (_tx: unknown, _id: string, decision: any) => {
          calls.push(["decide", decision]);
          return {
            ...change,
            status: decision.status,
            rejectionReason: decision.reason,
            decidedAt: decision.decidedAt,
            decidedById: decision.decidedById,
          };
        },
      },
      media: {
        promoteTargetMedia: async (pending: any, live: any) => {
          calls.push(["promote", `${pending.type}:${pending.id}->${live.type}:${live.id}`]);
        },
        scheduleTargetDeletion: async (target: any) => {
          calls.push(["delete", `${target.type}:${target.id}`]);
        },
      },
      lockActiveCatalogInTransaction: async () => true,
      catalogNames: async () => ({ cities: new Map([[CITY, "صنعاء"]]), categories: new Map([[CATEGORY, "تصوير"]]) }),
    } as any,
    notifications: {
      createNotificationInTransaction: async (_tx: unknown, notice: any) => {
        notices.push(notice);
      },
    } as any,
  });
  return { review, calls, notices };
}

const admin = { id: "admin-1" } as any;

test("RA-BE-152: approving puts the new logo in place of the old one, tells the provider, and audits the change", async () => {
  const { review, calls, notices } = reviewHarness();
  const audit = { before: null, after: null } as any;
  const response: any = await runAuditedAdminRequest(audit, () =>
    review.decide(admin, "change-1", { decision: "APPROVE" }),
  );
  assert.deepEqual(calls[0], ["promote", "PROVIDER_PROFILE_CHANGE_LOGO:change-1->PROVIDER_LOGO:p1"]);
  assert.equal((calls[1][1] as any).status, "APPROVED");
  assert.equal(response.status, "APPROVED");
  assert.equal(notices.length, 1);
  assert.equal(notices[0].type, "PROVIDER_PROFILE_CHANGE_REVIEWED");
  assert.equal(notices[0].userId, "u1");
  assert.equal(notices[0].routeTarget, "/provider/dashboard?tab=profile");
  assert.equal(notices[0].body, "تعديل الاسم والشعار صار ظاهر للعرسان.");
  assert.deepEqual(audit.before, {
    status: "PENDING",
    businessNameChanged: true,
    logoChanged: true,
    coverChanged: false,
    cityId: null,
    primaryCategoryId: null,
  });
  assert.equal(audit.after.status, "APPROVED");
});

test("RA-BE-152: a refusal needs its reason, deletes the held image, and the provider reads why", async () => {
  const { review, calls, notices } = reviewHarness();
  await assert.rejects(() => review.decide(admin, "change-1", { decision: "REJECT" }), /reason/);
  await review.decide(admin, "change-1", { decision: "REJECT", reason: "الشعار فيه رقم جوال" });
  assert.deepEqual(calls[0], ["delete", "PROVIDER_PROFILE_CHANGE_LOGO:change-1"]);
  assert.equal((calls[1][1] as any).status, "REJECTED");
  assert.equal((calls[1][1] as any).reason, "الشعار فيه رقم جوال");
  assert.match(notices[0].body, /ما نزل، وملفك باقي مثل ما كان\. السبب: الشعار فيه رقم جوال$/);
});

test("RA-BE-152: a team member does not decide on his own listing, nor twice", async () => {
  const own = reviewHarness(waitingChange({ provider: { ...waitingChange().provider, userId: "admin-1" } }));
  await assert.rejects(() => own.review.decide(admin, "change-1", { decision: "APPROVE" }), /own listing/);
  assert.equal(own.calls.length, 0);
  const done = reviewHarness(waitingChange({ status: "APPROVED" }));
  await assert.rejects(
    () => done.review.decide(admin, "change-1", { decision: "APPROVE" }),
    (error: any) => error?.response?.code === "PROFILE_CHANGE_ALREADY_DECIDED",
  );
});

test("RA-BE-152: an approved change's values and the new logo's smaller copies become the listing's", async () => {
  const row = { ...waitingChange(), provider: undefined };
  let providerData: any = null;
  const tx: any = {
    providerProfileChange: {
      findUnique: async () => row,
      updateMany: async () => ({ count: 1 }),
    },
    provider: {
      update: async ({ data }: any) => {
        providerData = data;
      },
    },
  };
  await decideProfileChange(tx, "change-1", {
    status: "APPROVED",
    reason: null,
    decidedAt: new Date(),
    decidedById: "admin-1",
  });
  assert.deepEqual(providerData, {
    businessName: "استوديو ضوء الجديد",
    logoUrl: NEW_LOGO,
    logoThumbUrl: "https://media.example/provider-logo/u1/new-480.webp",
    logoMediumUrl: "https://media.example/provider-logo/u1/new-1080.webp",
  });
});
