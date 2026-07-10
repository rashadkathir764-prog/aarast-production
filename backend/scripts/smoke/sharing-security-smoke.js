#!/usr/bin/env node
"use strict";

const { configureSmokeDatabaseUrl } = require("./smoke-utils");

configureSmokeDatabaseUrl();

const { createHash } = require("node:crypto");
const http = require("node:http");
const { PrismaClient } = require("@prisma/client");
const { registerVerified } = require("./verified-registration");

const BASE_URL = process.env.SMOKE_BASE_URL ?? "http://127.0.0.1:3115";
const suffix = Date.now().toString().slice(-7);
const PASSWORD = "SharingSecurity123!";
const prisma = new PrismaClient();

let passed = 0;
let failed = 0;

function check(label, condition) {
  if (condition) {
    console.log(`PASS - ${label}`);
    passed += 1;
  } else {
    console.log(`FAIL - ${label}`);
    failed += 1;
  }
}

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const payload = body ? JSON.stringify(body) : undefined;
    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: `${url.pathname}${url.search}`,
        method,
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => {
          data += chunk;
        });
        res.on("end", () => {
          try {
            resolve({ status: res.statusCode, body: JSON.parse(data) });
          } catch {
            resolve({ status: res.statusCode, body: data });
          }
        });
      },
    );
    req.on("error", reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function register(name, phone) {
  const response = await registerVerified(request, {
    name,
    phone,
    password: PASSWORD,
  });
  if (response.status !== 201) {
    throw new Error(`${name} registration failed with HTTP ${response.status}`);
  }
  return { token: response.body.accessToken, user: response.body.user };
}

async function run() {
  console.log("\nSharing Security Smoke Report");
  console.log(`Target: ${BASE_URL}\n`);

  const owner = await register("Security Owner", `+96770${suffix}`);
  const manager = await register("Security Manager", `+96771${suffix}`);
  const target = await register("Security Target", `+96772${suffix}`);
  const outsider = await register("Security Outsider", `+96773${suffix}`);

  const plan = await request(
    "POST",
    "/api/v1/wedding-plans",
    { title: "Sharing Security Plan" },
    owner.token,
  );
  check("owner creates security plan", plan.status === 201);

  const managerMember = await request(
    "POST",
    `/wedding-plans/${plan.body.id}/shared-members`,
    {
      userId: manager.user.id,
      role: "MANAGER",
      canInviteMembers: true,
    },
    owner.token,
  );
  check(
    "owner explicitly delegates invite management",
    managerMember.status === 201,
  );

  const lookupQuery = new URLSearchParams({
    weddingPlanId: plan.body.id,
    phone: target.user.phone,
  });
  const ownerLookup = await request(
    "GET",
    `/users/lookup?${lookupQuery}`,
    null,
    owner.token,
  );
  check("plan owner can confirm an invite target", ownerLookup.status === 200);

  const managerLookup = await request(
    "GET",
    `/users/lookup?${lookupQuery}`,
    null,
    manager.token,
  );
  check(
    "delegated invite manager can confirm an invite target",
    managerLookup.status === 200,
  );

  const outsiderLookup = await request(
    "GET",
    `/users/lookup?${lookupQuery}`,
    null,
    outsider.token,
  );
  check(
    "unrelated account cannot enumerate users through another plan",
    outsiderLookup.status === 404,
  );

  const financeEscalation = await request(
    "POST",
    `/api/v1/wedding-plans/${plan.body.id}/invites`,
    { userId: target.user.id, role: "FINANCE_MANAGER" },
    manager.token,
  );
  check(
    "manager cannot mint finance authority",
    financeEscalation.status === 400,
  );

  const emailInvite = await request(
    "POST",
    `/api/v1/wedding-plans/${plan.body.id}/invites`,
    { email: `unverified-${suffix}@example.test`, role: "VIEWER" },
    owner.token,
  );
  check(
    "unverified email invitations are rejected",
    emailInvite.status === 400,
  );

  const inviteResponse = await request(
    "POST",
    `/api/v1/wedding-plans/${plan.body.id}/invites`,
    { userId: target.user.id, role: "EDITOR" },
    manager.token,
  );
  check(
    "manager can delegate an editor inside the ceiling",
    inviteResponse.status === 201,
  );
  const rawToken = inviteResponse.body?.token;
  check(
    "create response returns a one-time external token",
    typeof rawToken === "string",
  );

  const stored = await prisma.planInvite.findUnique({
    where: { id: inviteResponse.body.id },
    select: { tokenHash: true },
  });
  const expectedHash = createHash("sha256").update(rawToken).digest("hex");
  check(
    "database stores the SHA-256 token fingerprint",
    stored?.tokenHash === expectedHash,
  );
  check(
    "database does not store the raw token",
    stored?.tokenHash !== rawToken,
  );

  const inviteNotification = await prisma.notification.findFirst({
    where: { entityType: "plan_invite", entityId: inviteResponse.body.id },
    select: { routeTarget: true, data: true },
  });
  check(
    "notification route stores only the authenticated invite id handle",
    inviteNotification?.routeTarget === `/invites/${inviteResponse.body.id}`,
  );
  check(
    "notification JSON contains no raw invite token",
    !JSON.stringify(inviteNotification?.data ?? {}).includes(rawToken),
  );

  const wrongPreview = await request(
    "GET",
    `/api/v1/invites/${rawToken}`,
    null,
    outsider.token,
  );
  check(
    "wrong token holder cannot preview the invite",
    wrongPreview.status === 404,
  );

  const financeInvite = await request(
    "POST",
    `/api/v1/wedding-plans/${plan.body.id}/invites`,
    { userId: outsider.user.id, role: "FINANCE_MANAGER" },
    owner.token,
  );
  const financeAccepted = await request(
    "POST",
    `/api/v1/invites/${financeInvite.body.token}/accept`,
    null,
    outsider.token,
  );
  check("owner may appoint a finance manager", financeAccepted.status === 201);

  const downgradeSuperior = await request(
    "PATCH",
    `/api/v1/wedding-plans/${plan.body.id}/members/${financeAccepted.body.member.id}`,
    { role: "VIEWER" },
    manager.token,
  );
  check(
    "delegated manager cannot modify superior authority",
    downgradeSuperior.status === 400,
  );

  const removeSuperior = await request(
    "DELETE",
    `/api/v1/wedding-plans/${plan.body.id}/members/${financeAccepted.body.member.id}`,
    null,
    manager.token,
  );
  check(
    "delegated manager cannot remove superior authority",
    removeSuperior.status === 400,
  );

  const concurrent = await Promise.all([
    request("POST", `/api/v1/invites/${rawToken}/accept`, null, target.token),
    request("POST", `/api/v1/invites/${rawToken}/accept`, null, target.token),
  ]);
  check(
    "concurrent invite acceptance succeeds exactly once",
    concurrent.filter((response) => response.status === 201).length === 1,
  );
  check(
    "concurrent invite replay is rejected",
    concurrent.filter((response) => response.status === 409).length === 1,
  );

  const memberCount = await prisma.sharedMember.count({
    where: { weddingPlanId: plan.body.id, userId: target.user.id },
  });
  check("concurrent acceptance creates exactly one member", memberCount === 1);

  console.log(`\nOverall Result: ${failed === 0 ? "PASS" : "FAIL"}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exitCode = 1;
}

run()
  .catch((error) => {
    console.error("Sharing security smoke error:", error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
