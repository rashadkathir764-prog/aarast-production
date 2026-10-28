import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  AdminRole,
  MediaUploadStatus,
  PrismaClient,
  ProviderStatus,
  UserRole,
  UserStatus,
  WeddingPersona,
} from "@prisma/client";
import sharp from "sharp";
import { AdminController } from "../../src/admin/admin.controller";
import { MediaStorageService } from "../../src/media/media-storage.service";
import { ADMIN_PERMISSIONS_KEY } from "../../src/modules/backoffice/public/admin-permission.decorator";
import {
  AdminPermission,
  hasAdminPermission,
} from "../../src/modules/backoffice/domain/admin-permissions";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { MediaUploadTicketService } from "../../src/modules/media/infrastructure/media-upload-ticket.service";
import { WOMEN_ALBUM } from "../../src/modules/marketplace/public/provider-portfolio";
import { OutboxService } from "../../src/platform/outbox/outbox.service";
import {
  adminService,
  marketplaceService,
  notificationsService,
  ownerPorts,
  providerDashboardService,
} from "./support/owner-ports";

// B-16 (D62) on a real database and a real bucket: a photo uploaded and
// verified (its metadata stripped) is PENDING and hidden; the moderation
// team approves it and customers see it, the women's album brides only and
// only after «بدون وجوه» was checked; a refusal carries its reason, deletes
// the image and tells the provider; who may decide; a changed album goes
// back to review; a removed photo's image is deleted.

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const label = `Portfolio ${runId}`;

function passwordHash(value: string): string {
  return createHash("sha256").update(`${runId}:portfolio:${value}`).digest("hex");
}

function code(expected: string) {
  return (error: any) => error?.response?.code === expected;
}

async function main(): Promise<void> {
  const city = await prisma.city.create({ data: { nameAr: label, countryCode: "ZZ", isActive: true } });
  const [forBoth, menOnly] = await Promise.all(
    [
      ["both", true],
      ["men", false],
    ].map(([key, showForBride]) =>
      prisma.providerCategory.create({
        data: {
          nameAr: `${label} ${key}`,
          slug: `portfolio-${key}-${runId}`.toLowerCase(),
          showForGroom: true,
          showForBride: showForBride as boolean,
          isActive: true,
        },
      }),
    ),
  );
  const users = await Promise.all(
    (
      [
        ["provider", UserRole.PROVIDER, null, null],
        ["men-provider", UserRole.PROVIDER, null, null],
        ["pending-provider", UserRole.PROVIDER, null, null],
        ["groom", UserRole.USER, null, WeddingPersona.GROOM],
        ["bride", UserRole.USER, null, WeddingPersona.BRIDE],
        ["moderator", UserRole.ADMIN, AdminRole.MODERATOR, null],
      ] as const
    ).map(([name, role, adminRole, persona]) =>
      prisma.user.create({
        data: {
          name: `${label} ${name}`,
          passwordHash: passwordHash(name),
          role,
          adminRole,
          persona,
          status: UserStatus.ACTIVE,
        },
      }),
    ),
  );
  const [providerUser, menProviderUser, pendingUser, groom, bride, moderator] = users;
  const [provider] = await Promise.all(
    (
      [
        [providerUser, forBoth, ProviderStatus.ACTIVE],
        [menProviderUser, menOnly, ProviderStatus.ACTIVE],
        [pendingUser, forBoth, ProviderStatus.PENDING],
      ] as const
    ).map(([user, category, status], index) =>
      prisma.provider.create({
        data: {
          userId: user.id,
          cityId: city.id,
          primaryCategoryId: category.id,
          businessName: `${label} مزود ${index + 1}`,
          phone: `portfolio-${index}-${runId}`.slice(0, 30),
          status,
        },
      }),
    ),
  );

  const media = new MediaStorageService(new MediaUploadTicketService(prisma as any));
  const permissions = new PermissionService(prisma as any, ownerPorts.plans);
  const notifications = notificationsService(prisma, permissions, new OutboxService());
  const market = marketplaceService(prisma, permissions, notifications, {});
  const dashboard = providerDashboardService(prisma, notifications, media, {});
  const admins = adminService(prisma, { revokeConversationAccess: () => {} }, notifications, media);
  const asUser = (user: (typeof users)[number]) => ({ ...user, sessionScope: "application" }) as any;
  const asAdmin = { ...moderator, adminMfa: true, sessionScope: "admin" } as any;

  /** A real upload: signed, put in the bucket, verified (re-encoded, metadata stripped). */
  async function upload(user: (typeof users)[number]): Promise<string> {
    const bytes = await sharp({
      create: { width: 16, height: 16, channels: 3, background: { r: 120, g: 90, b: 60 } },
    })
      .withMetadata({ exif: { IFD0: { Make: "SmokeCam" } } })
      .jpeg()
      .toBuffer();
    const signed = await media.createUpload(asUser(user), {
      purpose: "provider-portfolio",
      fileName: "work.jpg",
      contentType: "image/jpeg",
      byteSize: bytes.length,
    });
    const put = await fetch(signed.uploadUrl, {
      method: "PUT",
      headers: { "Content-Type": "image/jpeg", "Content-Length": String(bytes.length), "If-None-Match": "*" },
      body: bytes,
    });
    assert.equal(put.ok, true, `upload ${put.status}`);
    const verified = await media.verifyUpload(asUser(user), signed.key, "provider-portfolio");
    const stored = Buffer.from(await (await fetch(verified.publicUrl!)).arrayBuffer());
    assert.equal((await sharp(stored).metadata()).exif, undefined);
    return signed.key;
  }

  try {
    const [a, b, c] = [await upload(providerUser), await upload(providerUser), await upload(providerUser)];
    console.log("PASS - three portfolio uploads verified; the stored images carry no EXIF");

    await assert.rejects(
      dashboard.updatePortfolio(asUser(pendingUser), { items: [] } as any),
      code("PROVIDER_NOT_ACTIVE"),
    );
    await assert.rejects(
      dashboard.updatePortfolio(asUser(providerUser), { items: [{ key: b, album: WOMEN_ALBUM }] } as any),
      code("PORTFOLIO_WOMEN_PHOTO_NEEDS_NO_FACES"),
    );
    await assert.rejects(
      dashboard.updatePortfolio(asUser(menProviderUser), { items: [], socialLinks: { instagram: "https://evil.example/x" } } as any),
      code("PORTFOLIO_SOCIAL_LINK_INVALID"),
    );
    await assert.rejects(
      dashboard.updatePortfolio(asUser(menProviderUser), { items: [{ key: a, album: "الزفة" }] } as any),
      /not owned|unavailable/i,
    );
    const menKey = await upload(menProviderUser);
    await assert.rejects(
      dashboard.updatePortfolio(asUser(menProviderUser), { items: [{ key: menKey, album: WOMEN_ALBUM, noFaces: true }] } as any),
      code("PORTFOLIO_WOMEN_ALBUM_NOT_SERVED"),
    );
    console.log("PASS - only an approved provider; women's photos need «بدون وجوه» and a provider who serves women; links and keys are checked");

    const saved = await dashboard.updatePortfolio(asUser(providerUser), {
      items: [
        { key: a, album: "الزفة" },
        { key: b, album: WOMEN_ALBUM, noFaces: true },
        { key: c, album: "الدرون" },
      ],
      socialLinks: { tiktok: "https://tiktok.com/@daw.sanaa", instagram: "" },
    } as any);
    assert.deepEqual(saved.items.map((item: any) => item.status), ["PENDING", "PENDING", "PENDING"]);
    assert.deepEqual(saved.socialLinks, { tiktok: "https://www.tiktok.com/@daw.sanaa" });
    assert.equal(saved.servesWomen, true);
    const tickets = await prisma.mediaUploadTicket.findMany({ where: { key: { in: [a, b, c] } } });
    assert.ok(tickets.every((ticket) => ticket.consumedByType === "PORTFOLIO_ITEM"));
    const hidden = await market.findProviderPortfolio(asUser(bride), provider.id);
    assert.equal(hidden.items.length, 0);
    assert.deepEqual(hidden.socialLinks, { tiktok: "https://www.tiktok.com/@daw.sanaa" });
    console.log("PASS - new photos are PENDING and hidden from customers; the TikTok link shows");

    const queue = await admins.listPortfolioItems({} as any);
    const ours = queue.items.filter((item: any) => item.provider.id === provider.id);
    assert.deepEqual(ours.map((item: any) => item.album), ["الزفة", WOMEN_ALBUM, "الدرون"]);
    const [itemA, itemB, itemC] = ours;
    console.log("PASS - n07 lists the waiting photos, oldest first, with the provider");

    await admins.decidePortfolioItem(asAdmin, itemA.id, { decision: "APPROVE" } as any);
    assert.deepEqual((await market.findProviderPortfolio(asUser(groom), provider.id)).items.map((i: any) => i.id), [itemA.id]);
    await assert.rejects(
      admins.decidePortfolioItem(asAdmin, itemB.id, { decision: "APPROVE" } as any),
      code("PORTFOLIO_NO_FACES_NOT_CHECKED"),
    );
    await admins.decidePortfolioItem(asAdmin, itemB.id, { decision: "APPROVE", noFacesChecked: true } as any);
    assert.deepEqual((await market.findProviderPortfolio(asUser(groom), provider.id)).items.map((i: any) => i.id), [itemA.id]);
    assert.deepEqual(
      (await market.findProviderPortfolio(asUser(bride), provider.id)).items.map((i: any) => i.id),
      [itemA.id, itemB.id],
    );
    const approvedNotice = await prisma.notification.findFirstOrThrow({
      where: { userId: providerUser.id, type: "PORTFOLIO_REVIEWED", entityId: itemB.id },
    });
    assert.equal(approvedNotice.routeTarget, "/provider/gallery");
    const profile = await dashboard.getProfile(asUser(providerUser));
    assert.deepEqual(profile.portfolio, { photos: 3, pending: 1, rejected: 0, socialNetworks: ["tiktok"] });
    assert.equal(approvedNotice.body, "صورتك في «حفلات النساء» تظهر الحين للعرائس.");
    console.log("PASS - approved photos show; the women's album only after «بدون وجوه» was checked, and to brides only; he is told");

    await assert.rejects(
      admins.decidePortfolioItem(asAdmin, itemC.id, { decision: "REJECT", reason: "  " } as any),
      /reason/,
    );
    await admins.decidePortfolioItem(asAdmin, itemC.id, { decision: "REJECT", reason: "الصورة مأخوذة من حساب ثاني" } as any);
    await assert.rejects(
      admins.decidePortfolioItem(asAdmin, itemC.id, { decision: "APPROVE" } as any),
      code("PORTFOLIO_ITEM_ALREADY_DECIDED"),
    );
    const own = await dashboard.getPortfolio(asUser(providerUser));
    const refused = own.items.find((item: any) => item.id === itemC.id)!;
    assert.equal(refused.status, "REJECTED");
    assert.equal(refused.rejectionReason, "الصورة مأخوذة من حساب ثاني");
    assert.equal(refused.imageUrl, null);
    assert.equal((await prisma.mediaUploadTicket.findUniqueOrThrow({ where: { key: c } })).status, MediaUploadStatus.DELETE_PENDING);
    const refusedNotice = await prisma.notification.findFirstOrThrow({
      where: { userId: providerUser.id, type: "PORTFOLIO_REVIEWED", entityId: itemC.id },
    });
    assert.equal(refusedNotice.body, "صورتك في «الدرون» ما تظهر. السبب: الصورة مأخوذة من حساب ثاني");
    console.log("PASS - a refusal needs its reason, is final, deletes the image and tells him why");

    assert.deepEqual(
      Reflect.getMetadata(ADMIN_PERMISSIONS_KEY, AdminController.prototype.decidePortfolioItem),
      [AdminPermission.REVIEWS_WRITE],
    );
    assert.deepEqual(
      Reflect.getMetadata(ADMIN_PERMISSIONS_KEY, AdminController.prototype.listPortfolioItems),
      [AdminPermission.PROVIDERS_READ],
    );
    for (const role of [AdminRole.SUPER_ADMIN, AdminRole.MODERATOR]) {
      assert.equal(hasAdminPermission(role, AdminPermission.REVIEWS_WRITE), true, role);
    }
    for (const role of [AdminRole.OPERATIONS, AdminRole.SUPPORT]) {
      assert.equal(hasAdminPermission(role, AdminPermission.REVIEWS_WRITE), false, role);
      assert.equal(hasAdminPermission(role, AdminPermission.PROVIDERS_READ), true, role);
    }
    console.log("PASS - the moderation team and the super admin decide; operations and support only read the queue");

    const moved = await dashboard.updatePortfolio(asUser(providerUser), {
      items: [
        { key: b, album: WOMEN_ALBUM, noFaces: true },
        { key: a, album: "الزفة الكبيرة" },
      ],
    } as any);
    assert.deepEqual(moved.items.map((item: any) => [item.key, item.status]), [
      [b, "APPROVED"],
      [a, "PENDING"],
    ]);
    assert.deepEqual(moved.socialLinks, { tiktok: "https://www.tiktok.com/@daw.sanaa" });
    assert.deepEqual(
      (await market.findProviderPortfolio(asUser(bride), provider.id)).items.map((i: any) => i.id),
      [itemB.id],
    );
    assert.equal(await prisma.portfolioItem.count({ where: { id: itemC.id } }), 0);
    console.log("PASS - order kept; a changed album goes back to review; the refused photo he removed is gone");

    const removed = await dashboard.updatePortfolio(asUser(providerUser), { items: [{ key: b, album: WOMEN_ALBUM, noFaces: true }] } as any);
    assert.equal(removed.items.length, 1);
    assert.equal((await prisma.mediaUploadTicket.findUniqueOrThrow({ where: { key: a } })).status, MediaUploadStatus.DELETE_PENDING);
    console.log("PASS - a removed photo's image becomes a deletion job of the media cleanup");
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(async (error) => {
  console.error(error);
  await prisma.$disconnect();
  process.exit(1);
});
