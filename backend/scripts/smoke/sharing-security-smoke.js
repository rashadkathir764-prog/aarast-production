#!/usr/bin/env node
"use strict";

const { configureSmokeDatabaseUrl } = require("./smoke-utils");

configureSmokeDatabaseUrl();

const { createHash } = require("node:crypto");
const http = require("node:http");
const { PrismaClient } = require("@prisma/client");
const { registerVerified } = require("./verified-registration");
const { inviteAndAccept } = require("./invite-member");

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
  const staleInviteTarget = await register(
    "Security Stale Invite Target",
    `+96775${suffix}`,
  );

  const plan = await request(
    "POST",
    "/api/v1/wedding-plans",
    { title: "Sharing Security Plan" },
    owner.token,
  );
  check("owner creates security plan", plan.status === 201);

  const staleHighAuthorityInvite = await request(
    "POST",
    `/api/v1/wedding-plans/${plan.body.id}/invites`,
    {
      // RA-BE-33: an invite goes by number.
      phone: staleInviteTarget.user.phone,
      role: "MANAGER",
      canViewMoney: true,
      canManageMoney: true,
      canManageProviders: true,
    },
    owner.token,
  );
  check(
    "owner creates a high-authority invite before membership exists",
    staleHighAuthorityInvite.status === 201 &&
      staleHighAuthorityInvite.body?.role === "MANAGER" &&
      staleHighAuthorityInvite.body?.canViewMoney === true &&
      staleHighAuthorityInvite.body?.canManageMoney === true &&
      staleHighAuthorityInvite.body?.canManageProviders === true &&
      typeof staleHighAuthorityInvite.body?.token === "string",
  );

  const participationCity = await prisma.city.create({
    data: {
      nameAr: `Sharing participation ${suffix}`,
      nameEn: `Sharing participation ${suffix}`,
      countryCode: "YE",
      isActive: true,
    },
  });
  const participationProvider = await prisma.provider.create({
    data: {
      cityId: participationCity.id,
      businessName: `Sharing participation provider ${suffix}`,
      phone: `+96776${suffix}`,
      status: "ACTIVE",
    },
  });
  const participationConversation = await prisma.conversation.create({
    data: {
      scope: "PLAN",
      weddingPlanId: plan.body.id,
      providerId: participationProvider.id,
      createdByUserId: owner.user.id,
    },
  });

  // RA-BE-42: nobody joins without accepting an invite now, so the API can no
  // longer make a membership while an older invite waits (the review's
  // finding (13): not reachable). The guard behind it still matters: an
  // older invite never overwrites a newer membership. That newer membership,
  // and the provider participation its rights opened, are made here as rows
  // (the direct add made them before); the downgrade below is the real API.
  const staleTargetMember = await prisma.sharedMember.create({
    data: {
      weddingPlanId: plan.body.id,
      userId: staleInviteTarget.user.id,
      role: "MANAGER",
      canViewMoney: true,
      canManageMoney: true,
      canManageProviders: true,
    },
  });
  await prisma.conversationParticipant.create({
    data: {
      conversationId: participationConversation.id,
      userId: staleInviteTarget.user.id,
    },
  });

  const staleTargetViewerUpdate = await request(
    "PATCH",
    `/api/v1/wedding-plans/${plan.body.id}/members/${staleTargetMember.id}`,
    {
      role: "VIEWER",
      canViewMoney: false,
      canManageMoney: false,
      canManageProviders: false,
    },
    owner.token,
  );
  check(
    "newer membership update removes money and provider authority",
    staleTargetViewerUpdate.status === 200 &&
      staleTargetViewerUpdate.body?.role === "VIEWER" &&
      staleTargetViewerUpdate.body?.canViewMoney === false &&
      staleTargetViewerUpdate.body?.canManageMoney === false &&
      staleTargetViewerUpdate.body?.canManageProviders === false,
  );
  const viewerMemberBeforeStaleAccept = await prisma.sharedMember.findUnique({
    where: { id: staleTargetMember.id },
  });
  const revokedParticipationBeforeStaleAccept =
    await prisma.conversationParticipant.findUnique({
      where: {
        conversationId_userId: {
          conversationId: participationConversation.id,
          userId: staleInviteTarget.user.id,
        },
      },
    });
  check(
    "viewer downgrade revokes provider participation before invite acceptance",
    typeof revokedParticipationBeforeStaleAccept?.id === "string" &&
      revokedParticipationBeforeStaleAccept.revokedAt instanceof Date,
  );

  const staleHighAuthorityAccept = await request(
    "POST",
    `/api/v1/invites/${staleHighAuthorityInvite.body.token}/accept`,
    null,
    staleInviteTarget.token,
  );
  check(
    "target accepts the older high-authority invite",
    staleHighAuthorityAccept.status === 201,
  );
  const viewerMemberAfterStaleAccept = await prisma.sharedMember.findUnique({
    where: { id: staleTargetMember.id },
  });
  check(
    "older invite does not overwrite the newer viewer membership",
    viewerMemberAfterStaleAccept?.id === viewerMemberBeforeStaleAccept?.id &&
      viewerMemberAfterStaleAccept?.role === "VIEWER" &&
      viewerMemberAfterStaleAccept?.canViewMoney === false &&
      viewerMemberAfterStaleAccept?.canManageMoney === false &&
      viewerMemberAfterStaleAccept?.canManageProviders === false &&
      viewerMemberAfterStaleAccept?.updatedAt.getTime() ===
        viewerMemberBeforeStaleAccept?.updatedAt.getTime(),
  );
  check(
    "invite acceptance returns the preserved viewer authority",
    staleHighAuthorityAccept.body?.member?.id ===
      viewerMemberBeforeStaleAccept?.id &&
      staleHighAuthorityAccept.body?.member?.role === "VIEWER" &&
      staleHighAuthorityAccept.body?.member?.canViewMoney === false &&
      staleHighAuthorityAccept.body?.member?.canManageMoney === false &&
      staleHighAuthorityAccept.body?.member?.canManageProviders === false,
  );
  const revokedParticipationAfterStaleAccept =
    await prisma.conversationParticipant.findUnique({
      where: {
        conversationId_userId: {
          conversationId: participationConversation.id,
          userId: staleInviteTarget.user.id,
        },
      },
    });
  check(
    "older invite does not reopen revoked provider participation",
    revokedParticipationAfterStaleAccept?.id ===
      revokedParticipationBeforeStaleAccept?.id &&
      revokedParticipationAfterStaleAccept?.revokedAt?.getTime() ===
        revokedParticipationBeforeStaleAccept?.revokedAt?.getTime(),
  );

  // RA-BE-42: the manager joins by accepting an invite (P5).
  const managerMember = await inviteAndAccept(request, {
    planId: plan.body.id,
    inviterToken: owner.token,
    member: { phone: manager.user.phone, token: manager.token },
    access: {
      role: "MANAGER",
      canEditPlan: true,
      canManageTasks: true,
      canManageGuests: true,
      canInviteMembers: true,
    },
  });
  check(
    "owner explicitly delegates invite management",
    managerMember.status === 201 &&
      managerMember.body?.canEditPlan === true &&
      managerMember.body?.canManageTasks === true &&
      managerMember.body?.canManageGuests === true &&
      managerMember.body?.canInviteMembers === true,
  );

  // RA-BE-96: whose wedding the plan is (groom or bride) is the owner's to
  // say: it sets the mahr's side and «معك». An editor's request carrying it
  // is refused; the owner's goes through.
  {
    const byEditor = await request(
      "PATCH",
      `/api/v1/wedding-plans/${plan.body.id}`,
      { persona: "BRIDE" },
      manager.token,
    );
    check(
      "an editor cannot change whose wedding the plan is",
      byEditor.status === 403 && byEditor.body?.code === "PLAN_PERSONA_OWNER_ONLY",
    );
    const byEditorTitle = await request(
      "PATCH",
      `/api/v1/wedding-plans/${plan.body.id}`,
      { title: "Renamed by editor" },
      manager.token,
    );
    check("an editor still edits the plan itself", byEditorTitle.status === 200);
    const byOwner = await request(
      "PATCH",
      `/api/v1/wedding-plans/${plan.body.id}`,
      { persona: "GROOM" },
      owner.token,
    );
    check("the owner says whose wedding it is", byOwner.status === 200 && byOwner.body?.persona === "GROOM");
  }

  // RA-BE-11: no account learns whether a phone number has an Aarast
  // account, or its name. The plan guard of the old lookup proved nothing:
  // anyone can make a plan of their own and ask through it. The app invites
  // by phone (D81) and never asked; the lookup is gone.
  const outsiderPlan = await request(
    "POST",
    "/api/v1/wedding-plans",
    { title: "Outsider Own Plan" },
    outsider.token,
  );
  check("an outsider makes a plan of their own", outsiderPlan.status === 201);
  for (const [label, token, planId] of [
    ["an outsider through their own plan", outsider.token, outsiderPlan.body?.id],
    ["the plan owner", owner.token, plan.body.id],
    ["a delegated invite manager", manager.token, plan.body.id],
  ]) {
    const lookup = await request(
      "GET",
      `/api/v1/users/lookup?${new URLSearchParams({
        weddingPlanId: planId,
        phone: target.user.phone,
      })}`,
      null,
      token,
    );
    check(
      `${label} cannot learn an account by its phone`,
      lookup.status === 404 &&
        !JSON.stringify(lookup.body ?? {}).includes(target.user.id),
    );
  }

  const financeEscalation = await request(
    "POST",
    `/api/v1/wedding-plans/${plan.body.id}/invites`,
    { phone: target.user.phone, role: "FINANCE_MANAGER" },
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
    { phone: target.user.phone, role: "EDITOR" },
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

  const firstTimePhone = `+96774${suffix}`;
  const firstTimePassword = "FirstInvite123!";
  const firstTimeInvite = await request(
    "POST",
    `/api/v1/wedding-plans/${plan.body.id}/invites`,
    {
      name: "First Invite Contributor",
      phone: firstTimePhone,
      role: "VIEWER",
    },
    owner.token,
  );
  check(
    "owner can invite a contributor without an existing account",
    firstTimeInvite.status === 201 &&
      typeof firstTimeInvite.body?.token === "string",
  );
  const firstTimeOtp = await request(
    "POST",
    `/api/v1/invites/${firstTimeInvite.body.token}/request-otp`,
    { phone: firstTimePhone },
  );
  const firstTimeCode =
    process.env.SMOKE_OTP_CODE ?? firstTimeOtp.body?.code;
  check(
    "private invite OTP explicitly requires one-time account setup",
    firstTimeOtp.status === 201 &&
      firstTimeOtp.body?.accountSetupRequired === true &&
      typeof firstTimeCode === "string",
  );
  const firstTimeSession = await request(
    "POST",
    `/api/v1/invites/${firstTimeInvite.body.token}/verify-otp`,
    {
      phone: firstTimePhone,
      code: firstTimeCode,
      name: "First Invite Contributor",
      password: firstTimePassword,
    },
  );
  check(
    "the same private OTP creates a durable contributor session",
    firstTimeSession.status === 201 &&
      typeof firstTimeSession.body?.accessToken === "string" &&
      typeof firstTimeSession.body?.refreshToken === "string",
  );
  const firstTimeLogin = await request("POST", "/api/v1/auth/login", {
    phone: firstTimePhone,
    password: firstTimePassword,
  });
  check(
    "the contributor can return later with phone and chosen password",
    firstTimeLogin.status === 200 &&
      firstTimeLogin.body?.user?.id === firstTimeSession.body?.user?.id,
  );
  const firstTimeAccepted = await request(
    "POST",
    `/api/v1/invites/${firstTimeInvite.body.token}/accept`,
    null,
    firstTimeSession.body?.accessToken,
  );
  check(
    "the new contributor session accepts its exact invitation",
    firstTimeAccepted.status === 201 &&
      firstTimeAccepted.body?.invite?.status === "ACCEPTED" &&
      firstTimeAccepted.body?.contextKey ===
        `plan:${plan.body.id}:contributor`,
  );
  const firstTimeAcceptedReplay = await request(
    "POST",
    `/api/v1/invites/${firstTimeInvite.body.token}/accept`,
    null,
    firstTimeSession.body?.accessToken,
  );
  check(
    "a lost accept response can be retried without changing the result",
    firstTimeAcceptedReplay.status === 201 &&
      firstTimeAcceptedReplay.body?.invite?.id ===
        firstTimeAccepted.body?.invite?.id &&
      firstTimeAcceptedReplay.body?.member?.id ===
        firstTimeAccepted.body?.member?.id &&
      firstTimeAcceptedReplay.body?.contextKey ===
        firstTimeAccepted.body?.contextKey,
  );
  const ownerInvitesAfterFirstAcceptance = await request(
    "GET",
    `/api/v1/wedding-plans/${plan.body.id}/invites`,
    null,
    owner.token,
  );
  const acceptedInviteRows = Array.isArray(
    ownerInvitesAfterFirstAcceptance.body,
  )
    ? ownerInvitesAfterFirstAcceptance.body.filter(
        (invite) => invite.id === firstTimeInvite.body.id,
      )
    : [];
  check(
    "owner invite list has zero pending rows for the accepted contributor",
    ownerInvitesAfterFirstAcceptance.status === 200 &&
      acceptedInviteRows.length === 1 &&
      acceptedInviteRows[0]?.status === "ACCEPTED" &&
      acceptedInviteRows.filter((invite) => invite.status === "PENDING")
        .length === 0,
  );
  const contributorContexts = await request(
    "GET",
    "/api/v1/contexts",
    null,
    firstTimeSession.body?.accessToken,
  );
  check(
    "accepted contributor context is available immediately",
    contributorContexts.status === 200 &&
      Array.isArray(contributorContexts.body) &&
      contributorContexts.body.some(
        (context) =>
          context.contextKey === `plan:${plan.body.id}:contributor` &&
          context.role === "CONTRIBUTOR" &&
          context.weddingPlanId === plan.body.id,
      ),
  );
  const firstTimeAcceptedNotifications = await prisma.notification.count({
    where: {
      entityType: "plan_invite",
      entityId: firstTimeInvite.body.id,
      type: "SHARING_INVITE_ACCEPTED",
    },
  });
  check(
    "accept replay does not duplicate the owner notification",
    firstTimeAcceptedNotifications === 1,
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
    // RA-BE-33: an invite goes by number.
    { phone: outsider.user.phone, role: "FINANCE_MANAGER" },
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
    "delegated manager cannot discover or modify superior authority",
    downgradeSuperior.status === 404,
  );

  const removeSuperior = await request(
    "DELETE",
    `/api/v1/wedding-plans/${plan.body.id}/members/${financeAccepted.body.member.id}`,
    null,
    manager.token,
  );
  check(
    "delegated manager cannot discover or remove superior authority",
    removeSuperior.status === 404,
  );

  const concurrent = await Promise.all([
    request("POST", `/api/v1/invites/${rawToken}/accept`, null, target.token),
    request("POST", `/api/v1/invites/${rawToken}/accept`, null, target.token),
  ]);
  const concurrentFailures = concurrent
    .filter((response) => response.status !== 201)
    .map((response) => ({
      status: response.status,
      code: response.body?.code,
      message: response.body?.message,
    }));
  if (concurrentFailures.length > 0) {
    console.error(
      `Concurrent invite acceptance diagnostic: ${JSON.stringify(concurrentFailures)}`,
    );
  }
  check(
    "concurrent invite acceptance and its replay both return success",
    concurrent.every((response) => response.status === 201),
  );
  check(
    "concurrent invite replay returns the same member and context",
    new Set(concurrent.map((response) => response.body?.member?.id)).size ===
      1 &&
      concurrent.every(
        (response) =>
          response.body?.invite?.status === "ACCEPTED" &&
          response.body?.contextKey === `plan:${plan.body.id}:contributor`,
      ),
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
