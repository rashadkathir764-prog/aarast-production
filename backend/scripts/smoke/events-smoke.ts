import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { PrismaClient } from "@prisma/client";
import { PlanEventsService } from "../../src/wedding-plans/plan-events.service";
import { PlanErasureService } from "../../src/modules/planning/infrastructure/plan-erasure.service";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { ownerPorts } from "./support/owner-ports";

// D65 on a real database: the wedding's events (b12, b13). The main event
// is the plan's date, the customary kinds are once per plan, a member reads
// them (D52) and only the owner or a plan editor changes them, an archived
// plan stays read-only, and erasing the plan takes its events.

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const label = `Events smoke ${runId}`;

async function user(name: string) {
  return prisma.user.create({
    data: {
      name: `${label} ${name}`,
      passwordHash: createHash("sha256").update(`${runId}:${name}`).digest("hex"),
    },
  });
}

async function rejectsWith(promise: Promise<unknown>, pattern: RegExp) {
  await assert.rejects(promise, (error: any) => {
    const text = JSON.stringify(error?.response ?? error?.message ?? error);
    assert.match(text, pattern);
    return true;
  });
}

async function main(): Promise<void> {
  const owner = await user("owner");
  const viewer = await user("viewer");
  const editor = await user("editor");
  const stranger = await user("stranger");
  const plan = await prisma.weddingPlan.create({
    data: {
      ownerUserId: owner.id,
      title: "عرس محمد",
      persona: "GROOM",
      // The start of 21 January in Sanaa.
      weddingDate: new Date("2027-01-20T21:00:00.000Z"),
    },
  });
  await prisma.sharedMember.create({
    data: { weddingPlanId: plan.id, userId: viewer.id, role: "VIEWER" },
  });
  await prisma.sharedMember.create({
    data: {
      weddingPlanId: plan.id,
      userId: editor.id,
      role: "FAMILY",
      canEditPlan: true,
    },
  });

  const permissions = new PermissionService(prisma as any, ownerPorts.plans);
  const events = new PlanEventsService(prisma as any, permissions);

  try {
    let view = await events.list(owner as any, plan.id);
    assert.equal(view.party, "GROOM");
    assert.equal(view.canEdit, true);
    assert.equal(view.items.length, 1);
    assert.equal(view.items[0].type, "WEDDING");
    assert.equal(view.items[0].id, null);
    assert.equal(view.items[0].date, "2027-01-21");
    assert.deepEqual(view.suggestions, ["SAMRA", "MAQEEL", "AQD", "LUNCH", "DINNER", "CUSTOM"]);
    console.log("PASS - a new plan reads its wedding on the plan's day, with the groom's nights to add");

    const wedding = await events.create(owner as any, plan.id, {
      type: "WEDDING",
      timeSlot: "AFTER_ASR",
      placeLabel: "قاعة سبأ · حدة",
    });
    await rejectsWith(
      events.update(owner as any, plan.id, wedding.id!, { date: "2027-01-22" }),
      /EVENT_WEDDING_DATE_IS_PLAN_DATE/,
    );
    await rejectsWith(
      events.create(owner as any, plan.id, { type: "WEDDING" }),
      /EVENT_TYPE_EXISTS/,
    );
    await rejectsWith(events.remove(owner as any, plan.id, wedding.id!), /EVENT_IS_MAIN/);
    console.log("PASS - the main event is once per plan, keeps the plan's day and stays");

    const samra = await events.create(owner as any, plan.id, {
      type: "SAMRA",
      date: "2027-01-19",
      timeSlot: "AFTER_ISHA",
      placeLabel: "الديوان",
    });
    const maqeel = await events.create(editor as any, plan.id, {
      type: "MAQEEL",
      date: "2027-01-20",
      timeSlot: "AFTER_DHUHR",
      placeLabel: "بيت الوالد",
      responsibleName: "صالح أخوي",
      note: "القات عند صالح",
    });
    await events.create(owner as any, plan.id, {
      type: "LUNCH",
      date: "2027-01-21",
      timeSlot: "DHUHR",
      placeLabel: "بيت الوالد",
    });
    await rejectsWith(
      events.create(owner as any, plan.id, { type: "SAMRA", date: "2027-01-18" }),
      /EVENT_TYPE_EXISTS/,
    );
    await rejectsWith(
      events.create(owner as any, plan.id, { type: "CUSTOM", title: "  " }),
      /EVENT_CUSTOM_TITLE_REQUIRED/,
    );
    await rejectsWith(
      events.create(owner as any, plan.id, { type: "CUSTOM", title: "الحناء", timeSlot: "EXACT" }),
      /EVENT_EXACT_TIME_REQUIRED/,
    );
    const henna = await events.create(owner as any, plan.id, {
      type: "CUSTOM",
      title: "الحناء",
      date: "2027-01-18",
      timeSlot: "EXACT",
      exactTime: "20:30",
    });
    console.log("PASS - the owner and a plan editor add events; kinds are once, a custom one needs its name");

    view = await events.list(viewer as any, plan.id);
    assert.equal(view.canEdit, false);
    assert.deepEqual(
      view.items.map((item) => item.type),
      ["CUSTOM", "SAMRA", "MAQEEL", "LUNCH", "WEDDING"],
    );
    assert.equal(view.items[2].note, "القات عند صالح");
    assert.deepEqual(view.suggestions, ["AQD", "DINNER", "CUSTOM"]);
    await rejectsWith(
      events.update(viewer as any, plan.id, samra.id!, { placeLabel: "البيت" }),
      /not found/i,
    );
    await rejectsWith(events.list(stranger as any, plan.id), /not found/i);
    console.log("PASS - a member who only follows reads the week in order and changes nothing (D52)");

    const moved = await events.update(owner as any, plan.id, maqeel.id!, {
      timeSlot: "EXACT",
      exactTime: "14:00",
      note: null,
    });
    assert.equal(moved.exactTime, "14:00");
    assert.equal(moved.note, null);
    assert.equal(moved.responsibleName, "صالح أخوي");
    const back = await events.update(owner as any, plan.id, maqeel.id!, { timeSlot: "AFTER_ASR" });
    assert.equal(back.exactTime, null);
    await events.remove(owner as any, plan.id, henna.id!);
    view = await events.list(owner as any, plan.id);
    assert.equal(view.items.length, 4);
    console.log("PASS - an edit keeps what it does not name, a slot drops the hour, an event is removed");

    await prisma.weddingPlan.update({
      where: { id: plan.id },
      data: { status: "ARCHIVED" },
    });
    view = await events.list(owner as any, plan.id);
    assert.equal(view.canEdit, false);
    await rejectsWith(
      events.create(owner as any, plan.id, { type: "AQD" }),
      /PLAN_ARCHIVED_READ_ONLY/,
    );
    console.log("PASS - an archived plan reads its events and changes none");

    await prisma.$transaction(async (tx) => {
      await tx.sharedMember.deleteMany({ where: { weddingPlanId: plan.id } });
      await new PlanErasureService().deletePlansInTransaction(tx, [plan.id]);
    });
    assert.equal(await prisma.planEvent.count({ where: { weddingPlanId: plan.id } }), 0);
    assert.equal(await prisma.weddingPlan.count({ where: { id: plan.id } }), 0);
    console.log("PASS - erasing the plan takes its events");
  } finally {
    await prisma.planEvent.deleteMany({ where: { weddingPlanId: plan.id } });
    await prisma.sharedMember.deleteMany({ where: { weddingPlanId: plan.id } });
    await prisma.weddingPlan.deleteMany({ where: { id: plan.id } });
    await prisma.user.deleteMany({
      where: { id: { in: [owner.id, viewer.id, editor.id, stranger.id] } },
    });
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
