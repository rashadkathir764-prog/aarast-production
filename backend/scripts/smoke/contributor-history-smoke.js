#!/usr/bin/env node
"use strict";

require("./smoke-isolation-hook");

const http = require("node:http");
const { randomUUID } = require("node:crypto");
const { registerVerified } = require("./verified-registration");

const BASE_URL = process.env.SMOKE_BASE_URL ?? "http://127.0.0.1:3115";
const suffix = Date.now().toString().slice(-7);
const password = "ContributorHistory123!";

let passed = 0;
let failed = 0;

function check(label, condition) {
  if (condition) {
    console.log(`PASS - ${label}`);
    passed += 1;
    return;
  }
  console.log(`FAIL - ${label}`);
  failed += 1;
}

function request(method, path, body, token, extraHeaders = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const payload = body === undefined ? undefined : JSON.stringify(body);
    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: `${url.pathname}${url.search}`,
        method,
        headers: {
          "Content-Type": "application/json",
          ...(payload !== undefined
            ? { "Content-Length": Buffer.byteLength(payload) }
            : {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...extraHeaders,
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
    if (payload !== undefined) req.write(payload);
    req.end();
  });
}

async function register(name, phone) {
  const response = await registerVerified(request, {
    name,
    phone,
    password,
  });
  if (response.status !== 201) {
    throw new Error(`${name} registration failed with HTTP ${response.status}`);
  }
  return {
    token: response.body.accessToken,
    userId: response.body.user.id,
    phone,
  };
}

function ids(rows) {
  return new Set(Array.isArray(rows) ? rows.map((row) => row.id) : []);
}

function historyEvent(rows, action, title) {
  return rows.find(
    (event) =>
      event.action === action &&
      (title === undefined || event.snapshot?.title === title),
  );
}

function requireContributorMembershipIdentity(contextsResponse, planId) {
  if (
    contextsResponse.status !== 200 ||
    !Array.isArray(contextsResponse.body)
  ) {
    throw new Error(
      `Cannot load the authoritative contributor context before leave (HTTP ${contextsResponse.status})`,
    );
  }

  const matchingContexts = contextsResponse.body.filter(
    (context) =>
      context?.contextKey === `plan:${planId}:contributor` &&
      context?.weddingPlanId === planId &&
      context?.role === "CONTRIBUTOR",
  );
  if (matchingContexts.length !== 1) {
    throw new Error(
      `Expected exactly one authoritative contributor context before leave; received ${matchingContexts.length}`,
    );
  }

  const { membershipId, membershipAuthorityVersion } = matchingContexts[0];
  if (
    typeof membershipId !== "string" ||
    membershipId.trim().length === 0 ||
    !Number.isInteger(membershipAuthorityVersion) ||
    membershipAuthorityVersion < 1
  ) {
    throw new Error(
      "The authoritative contributor context is missing a valid membership identity",
    );
  }

  return {
    expectedMemberId: membershipId,
    expectedAuthorityVersion: membershipAuthorityVersion,
  };
}

async function run() {
  console.log("\nContributor history and access smoke report");
  console.log(`Target: ${BASE_URL}\n`);

  const owner = await register("History Owner", `+96770${suffix}`);
  const contributorA = await register(
    "History Contributor A",
    `+96771${suffix}`,
  );
  const contributorB = await register(
    "History Contributor B",
    `+96772${suffix}`,
  );
  const contributorC = await register(
    "History Contributor C",
    `+96774${suffix}`,
  );
  const pendingInvitePhone = `+96773${suffix}`;

  const plan = await request(
    "POST",
    "/api/v1/wedding-plans",
    { title: "Contributor isolation plan" },
    owner.token,
  );
  check("owner creates the isolated plan", plan.status === 201);
  const planId = plan.body.id;

  const memberA = await request(
    "POST",
    `/api/v1/wedding-plans/${planId}/members`,
    {
      userId: contributorA.userId,
      role: "VIEWER",
      canManageTasks: true,
      canInviteMembers: true,
    },
    owner.token,
  );
  const memberB = await request(
    "POST",
    `/api/v1/wedding-plans/${planId}/members`,
    {
      userId: contributorB.userId,
      role: "VIEWER",
      canManageTasks: true,
    },
    owner.token,
  );
  check(
    "owner grants explicit stored permissions to contributor A",
    memberA.status === 201,
  );
  check(
    "owner grants explicit stored permissions to contributor B",
    memberB.status === 201,
  );

  const taskA = await request(
    "POST",
    `/api/v1/wedding-plans/${planId}/tasks`,
    { title: "A private contribution", status: "TODO", priority: "HIGH" },
    contributorA.token,
  );
  const taskB = await request(
    "POST",
    `/api/v1/wedding-plans/${planId}/tasks`,
    { title: "B private contribution", status: "TODO", priority: "LOW" },
    contributorB.token,
  );
  const assignedToA = await request(
    "POST",
    `/api/v1/wedding-plans/${planId}/tasks`,
    { title: "Owner assigned to A", status: "TODO", priority: "MEDIUM" },
    owner.token,
  );
  const assignment = await request(
    "PATCH",
    `/api/v1/tasks/${assignedToA.body.id}/assign`,
    { assigneeUserId: contributorA.userId },
    owner.token,
  );
  check("contributor A creates a task", taskA.status === 201);
  check("contributor B creates a task", taskB.status === 201);
  check("owner assigns a task to contributor A", assignment.status === 200);

  const aTasksBeforeRevoke = await request(
    "GET",
    `/api/v1/wedding-plans/${planId}/tasks`,
    undefined,
    contributorA.token,
  );
  const bTasksBeforeRevoke = await request(
    "GET",
    `/api/v1/wedding-plans/${planId}/tasks`,
    undefined,
    contributorB.token,
  );
  const aTaskIds = ids(aTasksBeforeRevoke.body);
  const bTaskIds = ids(bTasksBeforeRevoke.body);
  check(
    "contributor A sees only own and assigned task rows",
    aTasksBeforeRevoke.status === 200 &&
      aTaskIds.has(taskA.body.id) &&
      aTaskIds.has(assignedToA.body.id) &&
      !aTaskIds.has(taskB.body.id),
  );
  check(
    "contributor B cannot see contributor A rows",
    bTasksBeforeRevoke.status === 200 &&
      bTaskIds.has(taskB.body.id) &&
      !bTaskIds.has(taskA.body.id) &&
      !bTaskIds.has(assignedToA.body.id),
  );

  const pendingInvite = await request(
    "POST",
    `/api/v1/wedding-plans/${planId}/invites`,
    {
      name: "Pending historical invite",
      phone: pendingInvitePhone,
      role: "VIEWER",
    },
    contributorA.token,
  );
  check(
    "delegated contributor creates a pending invite",
    pendingInvite.status === 201,
  );

  const staleAuthorityInvite = await request(
    "POST",
    `/api/v1/wedding-plans/${planId}/invites`,
    {
      userId: contributorC.userId,
      role: "VIEWER",
      canManageTasks: true,
    },
    contributorA.token,
  );
  const partialRevoke = await request(
    "PATCH",
    `/api/v1/wedding-plans/${planId}/members/${memberA.body.id}`,
    { canManageTasks: false },
    owner.token,
  );
  const invitesAfterNarrowing = await request(
    "GET",
    `/api/v1/wedding-plans/${planId}/invites`,
    undefined,
    owner.token,
  );
  const cancelledStaleInvite = Array.isArray(invitesAfterNarrowing.body)
    ? invitesAfterNarrowing.body.find(
        (invite) => invite.id === staleAuthorityInvite.body.id,
      )
    : null;
  const staleAuthorityAccept = await request(
    "POST",
    `/api/v1/invites/${staleAuthorityInvite.body.token}/accept`,
    undefined,
    contributorC.token,
  );
  const contributorCContexts = await request(
    "GET",
    "/api/v1/contexts",
    undefined,
    contributorC.token,
  );
  check(
    "narrowing delegated authority atomically cancels an excessive pending invite",
    staleAuthorityInvite.status === 201 &&
      partialRevoke.status === 200 &&
      partialRevoke.body.canManageTasks === false &&
      invitesAfterNarrowing.status === 200 &&
      cancelledStaleInvite?.status === "CANCELLED" &&
      staleAuthorityAccept.status === 400 &&
      staleAuthorityAccept.body?.message === "Invite has been revoked" &&
      contributorCContexts.status === 200 &&
      !contributorCContexts.body.some(
        (context) => context.contextKey === `plan:${planId}:contributor`,
      ),
  );

  const revoke = await request(
    "PATCH",
    `/api/v1/wedding-plans/${planId}/members/${memberA.body.id}`,
    { canInviteMembers: false },
    owner.token,
  );
  check(
    "owner revokes the remaining stored invite authority",
    revoke.status === 200 &&
      revoke.body.canManageTasks === false &&
      revoke.body.canInviteMembers === false,
  );

  const aTasksAfterRevoke = await request(
    "GET",
    `/api/v1/wedding-plans/${planId}/tasks`,
    undefined,
    contributorA.token,
  );
  check(
    "revoked contributor receives no live task rows",
    aTasksAfterRevoke.status === 200 &&
      Array.isArray(aTasksAfterRevoke.body) &&
      aTasksAfterRevoke.body.length === 0,
  );

  const deniedCompletion = await request(
    "PATCH",
    `/api/v1/tasks/${taskA.body.id}`,
    { status: "DONE" },
    contributorA.token,
  );
  check(
    "revoked task mutation returns the stable Arabic 403 contract",
    deniedCompletion.status === 403 &&
      deniedCompletion.body?.code === "TASK_PERMISSION_REVOKED" &&
      deniedCompletion.body?.message === "لم تعد لديك صلاحية لتنفيذ هذه المهمة",
  );

  const historyAfterRevoke = await request(
    "GET",
    `/api/v1/wedding-plans/${planId}/contributions?limit=100`,
    undefined,
    contributorA.token,
  );
  const frozenTask = historyEvent(
    historyAfterRevoke.body?.events ?? [],
    "CREATED",
    "A private contribution",
  );
  check(
    "revocation preserves the action-time snapshot without recapturing the live task",
    historyAfterRevoke.status === 200 &&
      Boolean(frozenTask) &&
      !(historyAfterRevoke.body?.events ?? []).some(
        (event) => event.action === "ACCESS_REVOKED_SNAPSHOT",
      ),
  );

  const frozenJson = JSON.stringify(frozenTask);
  const ownerUpdate = await request(
    "PATCH",
    `/api/v1/tasks/${taskA.body.id}`,
    { title: "Owner changed live task after revoke", status: "DONE" },
    owner.token,
  );
  check(
    "owner can continue updating the live task",
    ownerUpdate.status === 200,
  );

  const historyAfterOwnerUpdate = await request(
    "GET",
    `/api/v1/wedding-plans/${planId}/contributions?limit=100`,
    undefined,
    contributorA.token,
  );
  const frozenTaskAfterUpdate = historyEvent(
    historyAfterOwnerUpdate.body?.events ?? [],
    "CREATED",
    "A private contribution",
  );
  check(
    "owner edits do not mutate the frozen historical snapshot",
    frozenJson === JSON.stringify(frozenTaskAfterUpdate),
  );

  const bTasksAfterOwnerUpdate = await request(
    "GET",
    `/api/v1/wedding-plans/${planId}/tasks`,
    undefined,
    contributorB.token,
  );
  check(
    "contributor B remains isolated after owner updates A data",
    bTasksAfterOwnerUpdate.status === 200 &&
      !ids(bTasksAfterOwnerUpdate.body).has(taskA.body.id),
  );

  const ownerInvites = await request(
    "GET",
    `/api/v1/wedding-plans/${planId}/invites`,
    undefined,
    owner.token,
  );
  const revokedPendingInvite = Array.isArray(ownerInvites.body)
    ? ownerInvites.body.find((invite) => invite.id === pendingInvite.body.id)
    : null;
  check(
    "revoking invite authority also revokes contributor-created pending invites",
    ownerInvites.status === 200 && revokedPendingInvite?.status === "CANCELLED",
  );

  const historyText = JSON.stringify(historyAfterOwnerUpdate.body);
  check(
    "history response excludes phones, credentials, and raw invite tokens",
    !historyText.includes(owner.phone) &&
      !historyText.includes(contributorA.phone) &&
      !historyText.includes(contributorB.phone) &&
      !historyText.includes(pendingInvitePhone) &&
      !historyText.includes(password) &&
      !historyText.includes(pendingInvite.body.token),
  );

  const contextsBeforeLeave = await request(
    "GET",
    "/api/v1/contexts",
    undefined,
    contributorA.token,
  );
  const leaveMembership = requireContributorMembershipIdentity(
    contextsBeforeLeave,
    planId,
  );
  const leaveRequestId = randomUUID();
  const leave = await request(
    "DELETE",
    `/api/v1/wedding-plans/${planId}/members/me`,
    leaveMembership,
    contributorA.token,
    { "X-Client-Request-Id": leaveRequestId },
  );
  const leaveReplay = await request(
    "DELETE",
    `/api/v1/wedding-plans/${planId}/members/me`,
    leaveMembership,
    contributorA.token,
    { "X-Client-Request-Id": leaveRequestId },
  );
  if (leave.status !== 200 || leaveReplay.status !== 200) {
    console.error(
      `Leave diagnostic: ${JSON.stringify({ leave, leaveReplay })}`,
    );
  }
  check(
    "leave is successful and safe to replay with the same request id",
    leave.status === 200 &&
      leave.body?.deleted === true &&
      leaveReplay.status === 200 &&
      leaveReplay.body?.weddingPlanId === planId,
  );

  const contextsAfterLeave = await request(
    "GET",
    "/api/v1/contexts",
    undefined,
    contributorA.token,
  );
  const sharedPlansAfterLeave = await request(
    "GET",
    "/api/v1/shared/wedding-plans",
    undefined,
    contributorA.token,
  );
  check(
    "the plan disappears from contributor contexts after leave",
    contextsAfterLeave.status === 200 &&
      Array.isArray(contextsAfterLeave.body) &&
      !contextsAfterLeave.body.some(
        (context) => context.weddingPlanId === planId,
      ),
  );
  check(
    "the plan disappears from shared plans after leave",
    sharedPlansAfterLeave.status === 200 &&
      Array.isArray(sharedPlansAfterLeave.body) &&
      !sharedPlansAfterLeave.body.some(
        (sharedPlan) => sharedPlan.id === planId,
      ),
  );

  const directReentry = await request(
    "POST",
    `/api/v1/wedding-plans/${planId}/members`,
    {
      userId: contributorA.userId,
      role: "VIEWER",
      canManageTasks: true,
    },
    owner.token,
  );
  check(
    "a departed contributor cannot be re-added directly without consent",
    directReentry.status === 409 &&
      directReentry.body.code === "MEMBER_REENTRY_REQUIRES_INVITE",
  );

  const loginAgain = await request("POST", "/api/v1/auth/login", {
    phone: contributorA.phone,
    password,
  });
  check(
    "contributor account can log in after leaving one plan",
    loginAgain.status === 200,
  );
  const contributorANewToken = loginAgain.body.accessToken;

  const reinvite = await request(
    "POST",
    `/api/v1/wedding-plans/${planId}/invites`,
    {
      userId: contributorA.userId,
      role: "VIEWER",
      canManageTasks: true,
    },
    owner.token,
  );
  const reaccept = await request(
    "POST",
    `/api/v1/invites/${reinvite.body.token}/accept`,
    undefined,
    contributorANewToken,
  );
  check(
    "a new invitation is required and can be accepted",
    reinvite.status === 201 && reaccept.status === 201,
  );

  const contextsAfterReinvite = await request(
    "GET",
    "/api/v1/contexts",
    undefined,
    contributorANewToken,
  );
  check(
    "the contributor context returns only after the new invitation",
    contextsAfterReinvite.status === 200 &&
      contextsAfterReinvite.body.some(
        (context) => context.contextKey === `plan:${planId}:contributor`,
      ),
  );

  const tasksAfterReinvite = await request(
    "GET",
    `/api/v1/wedding-plans/${planId}/tasks`,
    undefined,
    contributorANewToken,
  );
  check(
    "a new authorized tenure restores only the same contributor previous work",
    tasksAfterReinvite.status === 200 &&
      ids(tasksAfterReinvite.body).has(taskA.body.id) &&
      !ids(tasksAfterReinvite.body).has(taskB.body.id),
  );

  const historyAfterReinvite = await request(
    "GET",
    `/api/v1/wedding-plans/${planId}/contributions?limit=100`,
    undefined,
    contributorANewToken,
  );
  const retainedFrozenTask = historyEvent(
    historyAfterReinvite.body?.events ?? [],
    "CREATED",
    "A private contribution",
  );
  check(
    "re-invitation preserves the earlier frozen history unchanged",
    historyAfterReinvite.status === 200 &&
      frozenJson === JSON.stringify(retainedFrozenTask),
  );

  console.log(`\nOverall Result: ${failed === 0 ? "PASS" : "FAIL"}`);
  console.log(`Checks: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exitCode = 1;
}

run().catch((error) => {
  console.error("Contributor history smoke error:", error.message);
  process.exitCode = 1;
});
