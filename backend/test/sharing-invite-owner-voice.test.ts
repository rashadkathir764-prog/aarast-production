import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";

import { sharingService } from "./support/owner-ports";

// D75: an invite speaks of the plan's owner in their gender, and tells an
// invite from the owner apart from one sent by a relative who may invite.
// The owner's id itself is never sent.

function harness() {
  const plans = [
    {
      id: "plan-bride",
      ownerUserId: "bride",
      title: "عرس سلمى",
      city: "عدن",
      weddingDate: null,
      status: "PLANNING",
      persona: "BRIDE",
    },
  ];
  const users = [
    { id: "bride", name: "سلمى", phone: "+967777000001" },
    { id: "sister", name: "أمل", phone: "+967777000002" },
  ];
  const prisma = {
    weddingPlan: {
      findMany: async ({ where }: any) =>
        plans.filter((plan) => where.id.in.includes(plan.id)),
    },
    user: {
      findMany: async ({ where }: any) =>
        users.filter((user) => where.id.in.includes(user.id)),
    },
  };
  const service = sharingService(prisma, {}, {}, {}, {}) as any;
  const invite = (inviterUserId: string) => ({
    id: `invite-${inviterUserId}`,
    weddingPlanId: "plan-bride",
    inviterUserId,
    inviteeUserId: null,
    status: "PENDING",
    expiresAt: new Date(Date.now() + 86_400_000),
    acceptedAt: null,
    declinedAt: null,
    revokedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    deliveryStatus: "DELIVERED",
    deliveryAttemptedAt: new Date(),
  });
  return { service, prisma, invite };
}

test("an invite from the bride carries her side and says she owns it", async () => {
  const { service, prisma, invite } = harness();
  const [hydrated] = await service.withInvitesRelations(prisma, [
    invite("bride"),
  ]);
  const response = service.toInviteResponse(hydrated);

  assert.equal(response.weddingPlan.persona, "BRIDE");
  assert.equal(response.inviterIsOwner, true);
  assert.equal(response.inviter.name, "سلمى");
  assert.equal(JSON.stringify(response).includes("ownerUserId"), false);
});

test("an invite from a relative says the inviter is not the owner", async () => {
  const { service, prisma, invite } = harness();
  const [hydrated] = await service.withInvitesRelations(prisma, [
    invite("sister"),
  ]);
  const response = service.toInviteResponse(hydrated);

  assert.equal(response.inviterIsOwner, false);
  assert.equal(response.inviter.name, "أمل");
});
