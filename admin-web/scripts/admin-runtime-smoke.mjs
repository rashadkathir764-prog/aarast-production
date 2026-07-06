import { randomBytes } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const baseUrl = (
  process.env.ADMIN_SMOKE_BASE_URL ||
  process.env.VITE_API_BASE_URL ||
  "http://127.0.0.1:3115"
).replace(/\/$/, "");

const checks = [];
let token = "";
let smokeCredentials = null;
let cleanupSmokeAdmin = async () => {};

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
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });

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

function loadBackendEnvIfNeeded() {
  if (process.env.DATABASE_URL) return;

  const backendEnvPath = resolve(
    dirname(fileURLToPath(import.meta.url)),
    "..",
    "..",
    "backend",
    ".env",
  );
  if (!existsSync(backendEnvPath)) return;

  for (const line of readFileSync(backendEnvPath, "utf8").split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const equalsIndex = trimmed.indexOf("=");
    if (equalsIndex === -1) continue;

    const key = trimmed.slice(0, equalsIndex).trim();
    let value = trimmed.slice(equalsIndex + 1).trim();
    if (!key || process.env[key] !== undefined) continue;

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

async function createLocalSmokeAdmin() {
  if (!isLocalTarget()) {
    throw new Error(
      "Set ADMIN_SMOKE_PHONE and ADMIN_SMOKE_PASSWORD for non-local admin runtime smoke.",
    );
  }

  loadBackendEnvIfNeeded();
  if (!process.env.DATABASE_URL) {
    throw new Error(
      "DATABASE_URL is required to auto-provision a local admin smoke account.",
    );
  }

  const backendRequire = createRequire(
    resolve(
      dirname(fileURLToPath(import.meta.url)),
      "..",
      "..",
      "backend",
      "package.json",
    ),
  );
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
        appRole: "WEDDING_USER",
        status: "ACTIVE",
        passwordHash,
      },
    });

    cleanupSmokeAdmin = async () => {
      await prisma.refreshToken.deleteMany({ where: { userId: user.id } });
      await prisma.user.deleteMany({ where: { id: user.id, phone } });
      await prisma.$disconnect();
    };

    return { phone, password, source: "temporary local smoke admin" };
  } catch (error) {
    await prisma.$disconnect();
    throw error;
  }
}

async function resolveCredentials() {
  const phone = process.env.ADMIN_SMOKE_PHONE || "";
  const password = process.env.ADMIN_SMOKE_PASSWORD || "";
  if (phone && password) {
    return { phone, password, source: "provided by env" };
  }

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

  res = await request("/auth/login", {
    method: "POST",
    auth: false,
    body: {
      phone: smokeCredentials.phone,
      password: smokeCredentials.password,
    },
  });
  check(
    "admin login returns 200 or 201",
    res.status === 200 || res.status === 201,
    String(res.status),
  );
  check("admin login returns ADMIN user", res.body?.user?.role === "ADMIN");
  check(
    "admin login returns access token",
    typeof res.body?.accessToken === "string",
  );
  check("admin login does not expose passwordHash", !hasPasswordHash(res.body));

  if (typeof res.body?.accessToken !== "string") {
    throw new Error("Admin login did not return an access token.");
  }
  token = res.body.accessToken;

  res = await request("/auth/me");
  check(
    "auth me returns admin user",
    res.status === 200 && res.body?.role === "ADMIN",
    String(res.status),
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
