import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { SharedMemberRole } from "@prisma/client";
import { NotFoundException } from "@nestjs/common";
import { MarketplaceService } from "../src/marketplace/marketplace.service";
import { PermissionService } from "../src/sharing/permission.service";

const backendRoot = join(__dirname, "..");

test("the final live read predicate revalidates current stored membership and permission", () => {
  const service = new PermissionService({} as any);
  const context = {
    plan: { id: "plan-1", ownerUserId: "owner-1" },
    isOwner: false,
    sharedMember: {
      id: "member-a",
      weddingPlanId: "plan-1",
      userId: "contributor-a",
      role: SharedMemberRole.CONTRIBUTOR,
      canManageTasks: true,
    },
  } as any;

  assert.deepEqual(
    service.livePlanAuthorizationWhere(context, "contributor-a", [
      "canManageTasks",
    ]),
    {
      sharedMembers: {
        some: {
          id: "member-a",
          userId: "contributor-a",
          canManageTasks: true,
        },
      },
    },
  );
  assert.deepEqual(
    service.livePlanAuthorizationWhere(
      { ...context, isOwner: true, sharedMember: null } as any,
      "owner-1",
    ),
    { ownerUserId: "owner-1" },
  );
});

test("transactional money reads use the lock-based plan boundary", () => {
  const source = readFileSync(
    join(backendRoot, "src", "sharing", "permission.service.ts"),
    "utf8",
  );
  const method = source.slice(
    source.indexOf("async assertMoneyReadableInTransaction"),
    source.indexOf("async assertMoneyManageable", source.indexOf("async assertMoneyReadableInTransaction")),
  );

  assert.match(method, /assertPlanReadableInTransaction\(\s*tx/);
  assert.doesNotMatch(method, /getPlanAccessContextWithClient/);
});

test("every wedding-cost live read locks authority and revalidates canViewMoney in its final query", () => {
  const source = readFileSync(
    join(backendRoot, "src", "wedding-costs", "wedding-costs.service.ts"),
    "utf8",
  );
  const contracts = [
    ["async listCosts", "async getCost"],
    ["async getCost", "async updateCost"],
    ["async listPaymentsForCost", "async listPaymentsForPlan"],
    ["async listPaymentsForPlan", "async getPayment"],
    ["async getPayment", "async reversePayment"],
    ["async listSchedulesForCost", "async listDueSchedulesForPlan"],
    ["async listDueSchedulesForPlan", "async updateSchedule"],
  ] as const;

  for (const [startToken, endToken] of contracts) {
    const start = source.indexOf(startToken);
    const end = source.indexOf(endToken, start + startToken.length);
    const method = source.slice(start, end);
    assert.ok(start >= 0 && end > start, startToken);
    assert.match(method, /runRetryableTransaction/, startToken);
    assert.match(method, /assertMoneyReadableInTransaction/, startToken);
    assert.match(method, /livePlanAuthorizationWhere/, startToken);
    assert.match(method, /canViewMoney/, startToken);
  }
});

test("task, plan quote, and contribution-history final queries carry live DB authorization", () => {
  const contracts = [
    ["tasks/tasks.service.ts", "async findForPlan", "async findOne"],
    [
      "marketplace/marketplace.service.ts",
      "async findPlanQuoteRequests",
      "/**",
    ],
    [
      "modules/collaboration/internal/contribution-history.service.ts",
      "async list",
      "async summary",
    ],
  ] as const;

  for (const [relative, startToken, endToken] of contracts) {
    const source = readFileSync(join(backendRoot, "src", relative), "utf8");
    const start = source.indexOf(startToken);
    const end = source.indexOf(endToken, start + startToken.length);
    const method = source.slice(start, end);
    assert.match(method, /livePlanAuthorizationWhere/, relative);
  }
});

test("quote detail does not return the seed row and revalidates provider permission in its final SQL", () => {
  const source = readFileSync(
    join(backendRoot, "src", "marketplace", "marketplace.service.ts"),
    "utf8",
  );
  const start = source.indexOf(
    "private async findAccessibleQuoteRequestOrThrow",
  );
  const end = source.indexOf(
    "private async findAccessibleQuoteOfferOrThrow",
    start,
  );
  const method = source.slice(start, end);
  const scopeSource = readFileSync(
    join(
      backendRoot,
      "src",
      "marketplace",
      "marketplace-contributor-quote-scope.ts",
    ),
    "utf8",
  );
  const helperStart = scopeSource.indexOf(
    "export async function findAccessiblePlanQuoteRequest",
  );
  const helperEnd = scopeSource.indexOf(
    "export async function buildMyQuoteAccessWhere",
    helperStart,
  );
  const helper = scopeSource.slice(helperStart, helperEnd);

  assert.match(method, /const quoteSeed = await this\.prisma\.quoteRequest\.findUnique/);
  assert.match(method, /findAccessiblePlanQuoteRequest/);
  assert.match(helper, /quoteRequest\.findFirst/);
  assert.match(helper, /livePlanAuthorizationWhere\([\s\S]*"canManageProviders"/);
  assert.match(helper, /permissions\.canViewMoney\(context\)/);
  assert.match(helper, /"canViewMoney"/);
  assert.doesNotMatch(method, /return \{\s*quote: quoteSeed/);
});

test("quote detail rejects a stale authorized seed when the final live predicate no longer matches", async () => {
  const quoteId = "11111111-1111-4111-8111-111111111111";
  const context = {
    plan: { id: "plan-1", ownerUserId: "owner-1" },
    isOwner: false,
    sharedMember: {
      id: "member-a",
      userId: "contributor-a",
      canManageProviders: true,
      canViewMoney: true,
    },
  } as any;
  let finalWhere: unknown;
  const service = new MarketplaceService(
    {
      quoteRequest: {
        findUnique: async () => ({ id: quoteId, weddingPlanId: "plan-1" }),
        findFirst: async ({ where }: { where: unknown }) => {
          finalWhere = where;
          return null;
        },
      },
      contributionEvent: {
        findMany: async () => [{ entityId: quoteId }],
      },
    } as any,
    {
      assertPlanReadable: async () => context,
      canManageProviders: () => true,
      canViewMoney: () => true,
    } as any,
    {} as any,
  );

  await assert.rejects(
    () =>
      service.findQuoteRequestForCurrentUser(
        { id: "contributor-a" } as any,
        quoteId,
      ),
    NotFoundException,
  );
  assert.deepEqual(finalWhere, {
    id: quoteId,
    weddingPlanId: "plan-1",
    weddingPlan: {
      is: {
        sharedMembers: {
          some: {
            id: "member-a",
            userId: "contributor-a",
            canManageProviders: true,
            canViewMoney: true,
          },
        },
      },
    },
  });
});

test("member and invite list final queries carry current membership and stored member permission", () => {
  const source = readFileSync(
    join(backendRoot, "src", "sharing", "sharing.service.ts"),
    "utf8",
  );
  const membersStart = source.indexOf("async findMembersForPlan");
  const membersEnd = source.indexOf("async createInvite", membersStart);
  const membersMethod = source.slice(membersStart, membersEnd);
  const invitesStart = source.indexOf("async findInvitesForPlan");
  const invitesEnd = source.indexOf("async cancelInvite", invitesStart);
  const invitesMethod = source.slice(invitesStart, invitesEnd);

  assert.match(membersMethod, /livePlanAuthorizationWhere/);
  assert.match(membersMethod, /weddingPlan:\s*\{\s*is: liveMembershipWhere/);
  assert.match(
    membersMethod,
    /livePlanAuthorizationWhere\([\s\S]*"canInviteMembers"/,
  );
  assert.match(
    invitesMethod,
    /livePlanAuthorizationWhere\([\s\S]*"canInviteMembers"/,
  );
});
