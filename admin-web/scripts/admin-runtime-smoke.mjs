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
let smokeCredentials = null;
let cleanupSmokeAdmin = async () => {};
let isSmokeAdminPhoneVerified = async () => false;

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
      ...(path.startsWith("/api/v1/auth/admin") && adminRefreshCookie
        ? { Cookie: adminRefreshCookie }
        : {}),
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  const setCookieValues =
    typeof response.headers.getSetCookie === "function"
      ? response.headers.getSetCookie()
      : [response.headers.get("set-cookie")].filter(Boolean);
  for (const value of setCookieValues) {
    if (!value.startsWith("aarast_admin_refresh=")) continue;
    adminRefreshCookie =
      /(?:Max-Age=0|Expires=Thu, 01 Jan 1970)/i.test(value)
        ? ""
        : value.split(";", 1)[0];
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

  const { PrismaClient } = backendRequire("@prisma/client");
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

  res = await request("/admin/notifications?limit=5");
  check(
    "admin notifications returns paginated items",
    res.status === 200 && Array.isArray(res.body?.items),
    String(res.status),
  );
  check(
    "admin notifications does not expose passwordHash",
    !hasPasswordHash(res.body),
  );
  check(
    "admin notifications never expose full user phones",
    Array.isArray(res.body?.items) &&
      res.body.items.every(
        (item) =>
          !item.user ||
          (!Object.hasOwn(item.user, "phone") &&
            !Object.hasOwn(item.user, "email")),
      ),
  );
  check(
    "admin financial notifications are redacted",
    Array.isArray(res.body?.items) &&
      res.body.items
        .filter((item) =>
          ["PAYMENT_SCHEDULE_DUE_SOON", "PAYMENT_SCHEDULE_OVERDUE"].includes(
            item.type,
          ),
        )
        .every(
          (item) =>
            item.financialDetailsRedacted === true &&
            item.data === null &&
            item.entityId === null &&
            item.routeTarget === null,
        ),
  );

  res = await request("/admin/notifications/unread-count");
  check(
    "admin unread notifications count returns number",
    res.status === 200 && Number.isFinite(res.body?.count),
    String(res.status),
  );
  check(
    "admin unread notifications count does not expose passwordHash",
    !hasPasswordHash(res.body),
  );

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
