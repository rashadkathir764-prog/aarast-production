import { randomBytes } from "node:crypto";
import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const backendRequire = createRequire(
  resolve(
    dirname(fileURLToPath(import.meta.url)),
    "..",
    "..",
    "backend",
    "package.json",
  ),
);
const { assertManagedSmokeEnvironment } = backendRequire(
  "./scripts/smoke/smoke-utils.js",
);
assertManagedSmokeEnvironment(process.env);

if (
  !process.env.ADMIN_SMOKE_BASE_URL ||
  process.env.ADMIN_SMOKE_BASE_URL !== process.env.SMOKE_BASE_URL
) {
  throw new Error("ADMIN_SMOKE_BASE_URL must be owned by managed smoke isolation.");
}
if (
  !process.env.ADMIN_SMOKE_DATABASE_URL ||
  process.env.ADMIN_SMOKE_DATABASE_URL !== process.env.SMOKE_DATABASE_URL
) {
  throw new Error(
    "ADMIN_SMOKE_DATABASE_URL must be the managed disposable database.",
  );
}

const baseUrl = process.env.ADMIN_SMOKE_BASE_URL.replace(/\/$/, "");

const checks = [];
let token = "";
let adminRefreshCookie = "";
// RA-AD-11: the remembered-device cookie, kept and sent like a browser would.
let adminDeviceCookie = "";
let smokeCredentials = null;
let cleanupSmokeAdmin = async () => {};
let isSmokeAdminPhoneVerified = async () => false;
let setSmokeAdminRoleToSupport = async () => {};

function check(name, passed, detail = "") {
  checks.push({ name, passed, detail });
  console.log(
    `${passed ? "PASS" : "FAIL"} - ${name}${detail && !passed ? ` (${detail})` : ""}`,
  );
}

function hasPasswordHash(value) {
  return JSON.stringify(value).includes("passwordHash");
}

async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    method: options.method || "GET",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      ...(options.auth === false || !token
        ? {}
        : { Authorization: `Bearer ${token}` }),
      ...(path.startsWith("/api/v1/auth/admin") && (adminRefreshCookie || adminDeviceCookie)
        ? { Cookie: [adminRefreshCookie, adminDeviceCookie].filter(Boolean).join("; ") }
        : {}),
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  const setCookieValues =
    typeof response.headers.getSetCookie === "function"
      ? response.headers.getSetCookie()
      : [response.headers.get("set-cookie")].filter(Boolean);
  for (const value of setCookieValues) {
    const cleared = /(?:Max-Age=0|Expires=Thu, 01 Jan 1970)/i.test(value);
    if (value.startsWith("aarast_admin_refresh=")) {
      adminRefreshCookie = cleared ? "" : value.split(";", 1)[0];
    } else if (value.startsWith("aarast_admin_device=")) {
      adminDeviceCookie = cleared ? "" : value.split(";", 1)[0];
    }
  }

  const text = await response.text();
  let body = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }

  return { status: response.status, body };
}

function isLocalTarget() {
  try {
    const url = new URL(baseUrl);
    return ["127.0.0.1", "localhost", "::1"].includes(url.hostname);
  } catch {
    return false;
  }
}

async function createLocalSmokeAdmin() {
  if (!isLocalTarget()) {
    throw new Error(
      "Set ADMIN_SMOKE_PHONE and ADMIN_SMOKE_PASSWORD for non-local admin runtime smoke.",
    );
  }

  const { AdminRole, PrismaClient } = backendRequire("@prisma/client");
  const bcryptjs = backendRequire("bcryptjs");
  const prisma = new PrismaClient();

  const randomDigits = randomBytes(5)
    .toString("hex")
    .replace(/\D/g, "")
    .padEnd(8, "0")
    .slice(0, 8);
  const phone = `+9677${randomDigits}`;
  const password = randomBytes(24).toString("base64url");
  const passwordHash = await bcryptjs.hash(password, 10);

  try {
    const user = await prisma.user.create({
      data: {
        phone,
        name: "Admin Runtime Smoke",
        role: "ADMIN",
        adminRole: "SUPER_ADMIN",
        appRole: "WEDDING_USER",
        status: "ACTIVE",
        // Regression coverage: a pre-MFA administrator must be able to prove
        // ownership through the MFA code instead of remaining locked out.
        phoneVerifiedAt: null,
        passwordHash,
      },
    });

    cleanupSmokeAdmin = async () => {
      await prisma.adminLoginChallenge.deleteMany({ where: { userId: user.id } });
      await prisma.refreshToken.deleteMany({ where: { userId: user.id } });
      await prisma.otpCode.deleteMany({ where: { phone } });
      await prisma.user.deleteMany({ where: { id: user.id, phone } });
      await prisma.$disconnect();
    };
    isSmokeAdminPhoneVerified = async () => {
      const currentUser = await prisma.user.findUnique({
        where: { id: user.id },
        select: { phoneVerifiedAt: true },
      });
      return Boolean(currentUser?.phoneVerifiedAt);
    };
    setSmokeAdminRoleToSupport = async () => {
      await prisma.user.update({
        where: { id: user.id },
        data: { adminRole: AdminRole.SUPPORT },
      });
    };

    return { phone, password, source: "temporary local smoke admin" };
  } catch (error) {
    await prisma.$disconnect();
    throw error;
  }
}

async function resolveCredentials() {
  return createLocalSmokeAdmin();
}

async function run() {
  smokeCredentials = await resolveCredentials();

  console.log("Admin Runtime Smoke Report");
  console.log(`Target: ${baseUrl}`);
  console.log(`Credentials: ${smokeCredentials.source}\n`);

  let res = await request("/health", { auth: false });
  check("backend health returns 200", res.status === 200, String(res.status));
  check(
    "health response does not expose passwordHash",
    !hasPasswordHash(res.body),
  );

  res = await request("/admin/dashboard/stats", { auth: false });
  check(
    "admin stats rejects unauthenticated access",
    res.status === 401,
    String(res.status),
  );

  res = await request("/api/v1/auth/admin/login", {
    method: "POST",
    auth: false,
    body: {
      phone: smokeCredentials.phone,
      password: smokeCredentials.password,
    },
  });
  check(
    "admin password step returns MFA challenge",
    res.status === 200 &&
      res.body?.mfaRequired === true &&
      typeof res.body?.challengeToken === "string",
    String(res.status),
  );
  check(
    "admin password step does not return an access token",
    !Object.hasOwn(res.body ?? {}, "accessToken"),
  );
  check(
    "admin password step does not set a refresh cookie",
    adminRefreshCookie === "",
  );
  check("admin password step does not expose passwordHash", !hasPasswordHash(res.body));

  const challengeToken = res.body?.challengeToken;
  const otpCode = process.env.ADMIN_SMOKE_OTP_CODE || res.body?.code;
  if (typeof challengeToken !== "string" || typeof otpCode !== "string") {
    throw new Error(
      "Admin MFA challenge or OTP is unavailable. Set ADMIN_SMOKE_OTP_CODE outside local dev mode.",
    );
  }

  res = await request("/api/v1/auth/admin/login/complete", {
    method: "POST",
    auth: false,
    body: { challengeToken, code: otpCode },
  });
  check("admin MFA completion returns 200", res.status === 200, String(res.status));
  check(
    "a code sign-in does not remember the browser unless asked (RA-AD-11)",
    adminDeviceCookie === "",
  );
  check(
    "admin MFA completion returns SUPER_ADMIN permissions",
    res.body?.user?.role === "ADMIN" &&
      res.body?.user?.adminRole === "SUPER_ADMIN" &&
      Array.isArray(res.body?.user?.adminPermissions) &&
      res.body.user.adminPermissions.includes("AUDIT_READ"),
  );
  check(
    "admin MFA completion returns access token",
    typeof res.body?.accessToken === "string",
  );
  check(
    "admin refresh token exists only in HttpOnly cookie",
    adminRefreshCookie.startsWith("aarast_admin_refresh=") &&
      !Object.hasOwn(res.body ?? {}, "refreshToken"),
  );
  check("admin MFA completion does not expose passwordHash", !hasPasswordHash(res.body));

  if (typeof res.body?.accessToken !== "string") {
    throw new Error("Admin MFA completion did not return an access token.");
  }
  token = res.body.accessToken;

  res = await request("/api/v1/auth/me");
  check(
    "application auth me rejects admin-scoped access token",
    res.status === 401,
    String(res.status),
  );
  check(
    "admin MFA verifies a pre-MFA administrator phone",
    await isSmokeAdminPhoneVerified(),
  );
  check("auth me does not expose passwordHash", !hasPasswordHash(res.body));

  res = await request("/admin/dashboard/stats");
  check(
    "admin stats returns totals",
    res.status === 200 && Number.isFinite(res.body?.totalUsers),
    String(res.status),
  );
  check("admin stats does not expose passwordHash", !hasPasswordHash(res.body));

  // D56 (B4): the desk has no notifications page, so the server reads and
  // changes no one's notifications for it: the five routes are gone.
  for (const path of [
    "/admin/notifications?limit=5",
    "/admin/notifications/unread-count",
  ]) {
    res = await request(path);
    check(`admin ${path} is not served`, res.status === 404, String(res.status));
  }

  res = await request("/admin/reports/overview");
  check(
    "admin reports overview returns operational report",
    res.status === 200 && res.body?.source === "admin_operational_database",
    String(res.status),
  );
  check(
    "admin reports overview excludes payment/deposit data",
    res.body?.paymentOrDepositDataIncluded === false,
  );
  check(
    "admin reports overview does not expose passwordHash",
    !hasPasswordHash(res.body),
  );

  res = await request("/admin/conversation-reports?limit=5");
  check(
    "admin conversation reports returns paginated items",
    res.status === 200 && Array.isArray(res.body?.items),
    String(res.status),
  );
  check(
    "admin conversation reports does not expose passwordHash",
    !hasPasswordHash(res.body),
  );

  res = await request("/admin/users?limit=5");
  check(
    "admin users list returns paginated items",
    res.status === 200 && Array.isArray(res.body?.items),
    String(res.status),
  );
  check(
    "admin users list does not expose passwordHash",
    !hasPasswordHash(res.body),
  );
  const firstUserId = res.body?.items?.[0]?.id;

  if (firstUserId) {
    res = await request(`/admin/users/${encodeURIComponent(firstUserId)}`);
    check(
      "admin user detail returns safe user",
      res.status === 200 && res.body?.id === firstUserId,
      String(res.status),
    );
    check(
      "admin user detail does not expose passwordHash",
      !hasPasswordHash(res.body),
    );
  } else {
    check("admin user detail skipped because users list is empty", true);
  }

  res = await request("/admin/cities");
  check(
    "admin cities list returns array",
    res.status === 200 && Array.isArray(res.body),
    String(res.status),
  );
  check(
    "admin cities list does not expose passwordHash",
    !hasPasswordHash(res.body),
  );

  res = await request("/admin/provider-categories");
  check(
    "admin provider categories list returns array",
    res.status === 200 && Array.isArray(res.body),
    String(res.status),
  );
  check(
    "admin provider categories list does not expose passwordHash",
    !hasPasswordHash(res.body),
  );

  const catalogSuffix = randomBytes(5).toString("hex");
  const catalogKey = `runtime-smoke-${catalogSuffix}`;
  const initialCatalogName = `تصنيف تشغيل ${catalogSuffix}`;
  const updatedCatalogName = `تصنيف تشغيل محدث ${catalogSuffix}`;

  res = await request("/admin/reference-catalogs");
  check(
    "admin managed catalog list returns the Money catalog",
    res.status === 200 &&
      Array.isArray(res.body) &&
      res.body.some((catalog) => catalog.key === "money.starter.categories"),
    String(res.status),
  );

  res = await request("/api/v1/catalogs/bootstrap", { auth: false });
  const catalogVersionBeforeDraft = res.body?.version;
  check(
    "public catalog bootstrap is available",
    res.status === 200 && typeof catalogVersionBeforeDraft === "string",
    String(res.status),
  );

  res = await request("/admin/reference-catalogs/money.starter.categories/items", {
    method: "POST",
    body: {
      key: catalogKey,
      nameAr: initialCatalogName,
      groupKey: "runtime-smoke",
      groupNameAr: "اختبار التشغيل",
      icon: "shield-check",
      sortOrder: 9999,
      showForGroom: true,
      showForBride: false,
      showForCustomer: true,
      showForProvider: false,
      isActive: true,
    },
  });
  const catalogItemId = res.body?.id;
  check(
    "admin creates an unpublished catalog draft",
    res.status === 201 &&
      typeof catalogItemId === "string" &&
      res.body?.currentRevision === 1 &&
      res.body?.publishedRevision === 0,
    String(res.status),
  );

  res = await request("/api/v1/catalogs/bootstrap", { auth: false });
  check(
    "draft creation does not change the public catalog version",
    res.status === 200 && res.body?.version === catalogVersionBeforeDraft,
    String(res.status),
  );
  check(
    "unpublished draft is absent from the public payload",
    !res.body?.catalogs
      ?.flatMap((catalog) => catalog.items ?? [])
      .some((item) => item.key === catalogKey),
  );

  if (typeof catalogItemId === "string") {
    res = await request(
      `/admin/reference-catalogs/money.starter.categories/items/${encodeURIComponent(catalogItemId)}/publish`,
      { method: "POST", body: {} },
    );
    check(
      "admin publishes the first catalog revision",
      res.status === 201 && res.body?.publishedRevision === 1,
      String(res.status),
    );

    res = await request("/api/v1/catalogs/bootstrap", { auth: false });
    const versionAfterFirstPublish = res.body?.version;
    check(
      "publication changes the public catalog version",
      res.status === 200 &&
        typeof versionAfterFirstPublish === "string" &&
        versionAfterFirstPublish !== catalogVersionBeforeDraft,
      String(res.status),
    );
    check(
      "published revision appears in the public payload",
      res.body?.catalogs
        ?.flatMap((catalog) => catalog.items ?? [])
        .some(
          (item) => item.key === catalogKey && item.nameAr === initialCatalogName,
        ),
    );

    res = await request(
      `/admin/reference-catalogs/money.starter.categories/items/${encodeURIComponent(catalogItemId)}`,
      { method: "PATCH", body: { nameAr: updatedCatalogName } },
    );
    check(
      "admin edit creates a second unpublished revision",
      res.status === 200 &&
        res.body?.currentRevision === 2 &&
        res.body?.publishedRevision === 1,
      String(res.status),
    );

    res = await request("/api/v1/catalogs/bootstrap", { auth: false });
    check(
      "editing a draft keeps the published content unchanged",
      res.body?.version === versionAfterFirstPublish &&
        res.body?.catalogs
          ?.flatMap((catalog) => catalog.items ?? [])
          .some(
            (item) =>
              item.key === catalogKey && item.nameAr === initialCatalogName,
          ),
    );

    res = await request(
      `/admin/reference-catalogs/money.starter.categories/items/${encodeURIComponent(catalogItemId)}/publish`,
      { method: "POST", body: { revision: 2 } },
    );
    check(
      "admin publishes the edited catalog revision",
      res.status === 201 && res.body?.publishedRevision === 2,
      String(res.status),
    );

    res = await request(
      `/admin/reference-catalogs/money.starter.categories/items/${encodeURIComponent(catalogItemId)}/publish`,
      { method: "POST", body: { revision: 1 } },
    );
    check(
      "admin can roll back by publishing a historical revision",
      res.status === 201 && res.body?.publishedRevision === 1,
      String(res.status),
    );

    res = await request("/api/v1/catalogs/bootstrap", { auth: false });
    check(
      "rollback restores the historical public content",
      res.body?.catalogs
        ?.flatMap((catalog) => catalog.items ?? [])
        .some(
          (item) => item.key === catalogKey && item.nameAr === initialCatalogName,
        ),
    );

    res = await request(
      `/admin/reference-catalogs/money.starter.categories/items/${encodeURIComponent(catalogItemId)}`,
      { method: "DELETE" },
    );
    check(
      "admin disable publishes an inactive revision without deleting history",
      res.status === 200 &&
        res.body?.published?.isActive === false &&
        Array.isArray(res.body?.revisions) &&
        res.body.revisions.length === 3,
      String(res.status),
    );

    res = await request("/api/v1/catalogs/bootstrap", { auth: false });
    check(
      "disabled catalog item disappears from the public payload",
      !res.body?.catalogs
        ?.flatMap((catalog) => catalog.items ?? [])
        .some((item) => item.key === catalogKey),
    );
  }

  const geographySuffix = randomBytes(4).toString("hex").toUpperCase();
  res = await request("/admin/governorates", {
    method: "POST",
    body: {
      code: `SMG-${geographySuffix}`,
      nameAr: `محافظة اختبار ${geographySuffix}`,
      nameEn: `Smoke Governorate ${geographySuffix}`,
      sortOrder: 9999,
    },
  });
  const smokeGovernorateId = res.body?.id;
  check(
    "admin creates a governorate",
    res.status === 201 && typeof smokeGovernorateId === "string",
    String(res.status),
  );

  let smokeDistrictId;
  if (typeof smokeGovernorateId === "string") {
    res = await request(
      `/admin/governorates/${encodeURIComponent(smokeGovernorateId)}/districts`,
      {
        method: "POST",
        body: {
          code: `SMD-${geographySuffix}`,
          nameAr: `مديرية اختبار ${geographySuffix}`,
          nameEn: `Smoke District ${geographySuffix}`,
          sortOrder: 9999,
        },
      },
    );
    smokeDistrictId = res.body?.id;
    check(
      "admin creates a district under the governorate",
      res.status === 201 && typeof smokeDistrictId === "string",
      String(res.status),
    );
  }

  let smokeLocalityId;
  if (typeof smokeDistrictId === "string") {
    res = await request(
      `/admin/districts/${encodeURIComponent(smokeDistrictId)}/localities`,
      {
        method: "POST",
        body: {
          code: `SML-${geographySuffix}`,
          type: "NEIGHBORHOOD",
          nameAr: `حي اختبار ${geographySuffix}`,
          nameEn: `Smoke Neighborhood ${geographySuffix}`,
          sortOrder: 1,
        },
      },
    );
    smokeLocalityId = res.body?.id;
    check(
      "admin creates a neighborhood under the district",
      res.status === 201 && typeof smokeLocalityId === "string",
      String(res.status),
    );

    res = await request(
      `/api/v1/districts/${encodeURIComponent(smokeDistrictId)}/localities`,
      { auth: false },
    );
    check(
      "published locality is immediately visible to Mobile",
      res.status === 200 &&
        Array.isArray(res.body) &&
        res.body.some((item) => item.id === smokeLocalityId),
      String(res.status),
    );
  }

  if (typeof smokeLocalityId === "string") {
    res = await request(`/admin/localities/${encodeURIComponent(smokeLocalityId)}`, {
      method: "DELETE",
    });
    check(
      "admin soft-disables the neighborhood",
      res.status === 200 && res.body?.isActive === false,
      String(res.status),
    );

    res = await request(
      `/api/v1/districts/${encodeURIComponent(smokeDistrictId)}/localities`,
      { auth: false },
    );
    check(
      "disabled neighborhood is hidden from Mobile",
      res.status === 200 &&
        Array.isArray(res.body) &&
        !res.body.some((item) => item.id === smokeLocalityId),
      String(res.status),
    );
  }

  if (typeof smokeDistrictId === "string") {
    res = await request(`/admin/districts/${encodeURIComponent(smokeDistrictId)}`, {
      method: "DELETE",
    });
    check(
      "admin soft-disables the district",
      res.status === 200 && res.body?.isActive === false,
      String(res.status),
    );
  }

  if (typeof smokeGovernorateId === "string") {
    res = await request(
      `/admin/governorates/${encodeURIComponent(smokeGovernorateId)}`,
      { method: "DELETE" },
    );
    check(
      "admin soft-disables the governorate",
      res.status === 200 && res.body?.isActive === false,
      String(res.status),
    );
  }

  res = await request("/admin/providers/applications?limit=5");
  check(
    "admin provider applications list returns paginated items",
    res.status === 200 && Array.isArray(res.body?.items),
    String(res.status),
  );
  check(
    "admin provider applications list does not expose passwordHash",
    !hasPasswordHash(res.body),
  );

  res = await request("/admin/providers?limit=5");
  check(
    "admin providers list returns paginated items",
    res.status === 200 && Array.isArray(res.body?.items),
    String(res.status),
  );
  check(
    "admin providers list does not expose passwordHash",
    !hasPasswordHash(res.body),
  );

  res = await request("/admin/services?limit=5");
  check(
    "admin services list returns paginated items",
    res.status === 200 && Array.isArray(res.body?.items),
    String(res.status),
  );
  check(
    "admin services list does not expose passwordHash",
    !hasPasswordHash(res.body),
  );

  res = await request("/admin/reviews?limit=5");
  check(
    "admin reviews list returns paginated items",
    res.status === 200 && Array.isArray(res.body?.items),
    String(res.status),
  );
  check(
    "admin reviews list does not expose passwordHash",
    !hasPasswordHash(res.body),
  );
  check(
    "admin reviews never expose reviewer contact details",
    Array.isArray(res.body?.items) &&
      res.body.items.every(
        (item) =>
          !item.user ||
          (!Object.hasOwn(item.user, "phone") &&
            !Object.hasOwn(item.user, "email")),
      ),
  );

  res = await request("/admin/audit-logs?limit=5");
  check(
    "admin audit log returns append-only paginated entries",
    res.status === 200 && Array.isArray(res.body?.items),
    String(res.status),
  );
  check("admin audit log does not expose passwordHash", !hasPasswordHash(res.body));

  res = await request("/api/v1/auth/admin/refresh", {
    method: "POST",
    auth: false,
  });
  check(
    "admin refresh rotates the cookie session",
    res.status === 200 &&
      typeof res.body?.accessToken === "string" &&
      adminRefreshCookie.startsWith("aarast_admin_refresh="),
    String(res.status),
  );
  if (typeof res.body?.accessToken === "string") token = res.body.accessToken;

  res = await request("/api/v1/auth/admin/logout", {
    method: "POST",
    auth: false,
  });
  check(
    "admin logout revokes the cookie session",
    res.status === 200 && adminRefreshCookie === "",
    String(res.status),
  );

  res = await request("/admin/dashboard/stats");
  check(
    "admin logout immediately invalidates the access token",
    res.status === 401,
    String(res.status),
  );

  await setSmokeAdminRoleToSupport();

  res = await request("/api/v1/auth/admin/login", {
    method: "POST",
    auth: false,
    body: {
      phone: smokeCredentials.phone,
      password: smokeCredentials.password,
    },
  });
  check(
    "restricted admin fresh password step returns a new MFA challenge",
    res.status === 200 &&
      res.body?.mfaRequired === true &&
      typeof res.body?.challengeToken === "string" &&
      res.body.challengeToken !== challengeToken,
    String(res.status),
  );
  const restrictedChallengeToken = res.body?.challengeToken;
  const restrictedOtpCode = process.env.ADMIN_SMOKE_OTP_CODE || res.body?.code;
  if (
    typeof restrictedChallengeToken !== "string" ||
    typeof restrictedOtpCode !== "string"
  ) {
    throw new Error(
      "Restricted Admin MFA challenge or OTP is unavailable. Set ADMIN_SMOKE_OTP_CODE outside local dev mode.",
    );
  }

  res = await request("/api/v1/auth/admin/login/complete", {
    method: "POST",
    auth: false,
    body: {
      challengeToken: restrictedChallengeToken,
      code: restrictedOtpCode,
    },
  });
  check(
    "fresh MFA returns SUPPORT with catalog read and without catalog write",
    res.status === 200 &&
      res.body?.user?.adminRole === "SUPPORT" &&
      Array.isArray(res.body?.user?.adminPermissions) &&
      res.body.user.adminPermissions.includes("CATALOG_READ") &&
      !res.body.user.adminPermissions.includes("CATALOG_WRITE"),
    String(res.status),
  );
  check(
    "fresh restricted MFA returns a new access session",
    typeof res.body?.accessToken === "string" &&
      adminRefreshCookie.startsWith("aarast_admin_refresh="),
  );
  if (typeof res.body?.accessToken !== "string") {
    throw new Error("Restricted Admin MFA completion did not return an access token.");
  }
  token = res.body.accessToken;

  res = await request("/admin/reference-catalogs/money.starter.categories");
  check(
    "SUPPORT catalog read remains allowed",
    res.status === 200 && res.body?.key === "money.starter.categories",
    String(res.status),
  );

  const restrictedWriteKey = `runtime-smoke-denied-${randomBytes(5).toString("hex")}`;
  res = await request("/admin/reference-catalogs/money.starter.categories/items", {
    method: "POST",
    body: {
      key: restrictedWriteKey,
      nameAr: "تصنيف يجب رفض كتابته",
      groupKey: "runtime-smoke",
      groupNameAr: "اختبار التشغيل",
      icon: "shield-check",
      sortOrder: 9999,
      showForGroom: true,
      showForBride: false,
      showForCustomer: true,
      showForProvider: false,
      isActive: true,
    },
  });
  check(
    "SUPPORT valid catalog write propagates the structured RBAC denial",
    res.status === 403 &&
      res.body?.statusCode === 403 &&
      res.body?.message === "Admin permission is required",
    String(res.status),
  );

  const missingCatalogKey = `runtime-smoke-missing-${randomBytes(12).toString("hex")}`;
  res = await request(
    `/admin/reference-catalogs/${encodeURIComponent(missingCatalogKey)}`,
  );
  check(
    "authorized missing catalog read propagates the structured not-found response",
    res.status === 404 &&
      res.body?.statusCode === 404 &&
      res.body?.message === "Reference catalog not found",
    String(res.status),
  );

  res = await request("/api/v1/auth/admin/logout", {
    method: "POST",
    auth: false,
  });
  check(
    "restricted admin logout revokes the fresh cookie session",
    res.status === 200 && adminRefreshCookie === "",
    String(res.status),
  );

  // RA-AD-11: an admin who asks is remembered on this browser for 30 days,
  // and then signs in with the password alone; the logout keeps that.
  res = await request("/api/v1/auth/admin/login", {
    method: "POST",
    auth: false,
    body: { phone: smokeCredentials.phone, password: smokeCredentials.password },
  });
  const rememberChallengeToken = res.body?.challengeToken;
  const rememberOtpCode = process.env.ADMIN_SMOKE_OTP_CODE || res.body?.code;
  res = await request("/api/v1/auth/admin/login/complete", {
    method: "POST",
    auth: false,
    body: { challengeToken: rememberChallengeToken, code: rememberOtpCode, rememberDevice: true },
  });
  check(
    "a code sign-in that asks remembers the browser",
    res.status === 200 && adminDeviceCookie.startsWith("aarast_admin_device="),
    String(res.status),
  );
  res = await request("/api/v1/auth/admin/logout", { method: "POST", auth: false });
  res = await request("/api/v1/auth/admin/login", {
    method: "POST",
    auth: false,
    body: { phone: smokeCredentials.phone, password: smokeCredentials.password },
  });
  check(
    "a remembered browser signs in with the password alone",
    res.status === 200 &&
      typeof res.body?.accessToken === "string" &&
      res.body?.mfaRequired !== true,
    String(res.status),
  );
  await request("/api/v1/auth/admin/logout", { method: "POST", auth: false });

  const failed = checks.filter((item) => !item.passed);
  console.log(`\nOverall Result: ${failed.length ? "FAIL" : "PASS"}`);
  if (failed.length) process.exit(1);
}

run()
  .catch((error) => {
    console.error("\nOverall Result: FAIL");
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  })
  .finally(async () => {
    await cleanupSmokeAdmin();
  });
