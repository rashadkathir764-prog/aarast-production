import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { ConflictException } from "@nestjs/common";
import { validate } from "class-validator";
import { GuestsService } from "../src/guests/guests.service";
import { ExpectedReadDto } from "../src/shared-kernel/versioning/expected-read.dto";

// RA-MO-344 (the rest): a delete of a guest, a task, a cost or a payment date
// made on a phone from an older read went through over what the partner had
// changed meanwhile. As the edit, it says what it last read (`expected`) and
// is refused 409 CHANGED_ELSEWHERE when a field of the row differs now.

const source = (file: string) =>
  readFileSync(join(__dirname, "../src", file), "utf8");

const now = new Date("2026-11-24T10:00:00.000Z");
const guest = {
  id: "guest-1",
  weddingPlanId: "plan-1",
  groupId: null,
  name: "خالد الحمدي",
  normalizedName: "خالد الحمدي",
  phone: null,
  normalizedPhone: null,
  side: "OTHER",
  status: "INVITED",
  invitationStatus: "NOT_SENT",
  attendanceStatus: "PENDING",
  seatsCount: 1,
  companionsCount: 0,
  notes: null,
  createdAt: now,
  updatedAt: now,
};

function guests() {
  const deleted: string[] = [];
  const tx: any = {
    $queryRaw: async () => [{ id: "locked" }],
    guest: {
      findUnique: async ({ where }: any) => (where.id === guest.id ? guest : null),
      delete: async ({ where }: any) => {
        deleted.push(where.id);
        return guest;
      },
    },
  };
  tx.$transaction = async (operation: (client: any) => Promise<unknown>) =>
    operation(tx);
  const ownerContext = {
    plan: { id: "plan-1", ownerUserId: "owner-1", status: "ACTIVE" },
    isOwner: true,
    sharedMember: null,
  };
  const service = new (GuestsService as any)(
    tx,
    {
      assertGuestManageableInTransaction: async () => ownerContext,
      canManageGuests: () => true,
    },
    { recordForContextInTransaction: async () => undefined },
    { qualifyingEntityIdsInTransaction: async () => [] },
    { listPlanEvents: async () => [] },
  ) as GuestsService;
  return { service, deleted };
}

const owner = { id: "owner-1" } as any;

test("a guest renamed since the phone read it is not deleted", async () => {
  const { service, deleted } = guests();
  await assert.rejects(
    () => service.remove(owner, guest.id, { name: "اسم قديم" }),
    (error: unknown) => {
      assert.ok(error instanceof ConflictException);
      const response = error.getResponse() as Record<string, unknown>;
      assert.equal(response.code, "CHANGED_ELSEWHERE");
      assert.match(String(response.message), /[؀-ۿ]/);
      return true;
    },
  );
  assert.deepEqual(deleted, []);
});

test("a guest as the phone read it is deleted; the guest's own link refuses nothing", async () => {
  const { service, deleted } = guests();
  assert.deepEqual(
    await service.remove(owner, guest.id, {
      name: guest.name,
      attendanceStatus: "PENDING",
      notes: null,
    }),
    { id: guest.id, deleted: true },
  );
  assert.deepEqual(deleted, [guest.id]);
});

test("a delete that read nothing is taken as before", async () => {
  const { service, deleted } = guests();
  await service.remove(owner, guest.id);
  assert.deepEqual(deleted, [guest.id]);
});

test("a field a delete cannot check is a bad request, never a silent pass", async () => {
  const { service, deleted } = guests();
  await assert.rejects(
    () => service.remove(owner, guest.id, { linkOpenedAt: null }),
    (error: any) => error.getStatus?.() === 400,
  );
  assert.deepEqual(deleted, []);
});

test("a delete carries what it read as an object only", async () => {
  const ok = Object.assign(new ExpectedReadDto(), { expected: { name: "خالد" } });
  assert.deepEqual(await validate(ok), []);
  assert.deepEqual(await validate(new ExpectedReadDto()), []);
  for (const expected of [42, "2026-11-24"]) {
    const bad = Object.assign(new ExpectedReadDto(), { expected });
    assert.equal((await validate(bad)).length, 1);
  }
});

test(
  "the four deletes check the same fields as their edits, against the row " +
    "they locked, and the controllers pass what the phone read",
  () => {
    const deletes = [
      ["guests/guests.service.ts", "async remove(", "current", "GUEST_CHECKABLE_FIELDS"],
      ["tasks/tasks.service.ts", "async remove(", "current", "TASK_CHECKABLE_FIELDS"],
      ["wedding-costs/wedding-costs.service.ts", "async deleteCost(", "locked", "COST_CHECKABLE_FIELDS"],
      ["wedding-costs/wedding-costs.service.ts", "async deleteSchedule(", "schedule", "SCHEDULE_CHECKABLE_FIELDS"],
    ] as const;
    for (const [file, head, row, fields] of deletes) {
      const text = source(file);
      const start = text.indexOf(head);
      assert.ok(start >= 0, `${file}: ${head}`);
      const body = text.slice(start, text.indexOf("\n  async ", start + head.length));
      assert.match(
        body,
        new RegExp(
          `assertFieldsUnchangedSince\\(\\s*expected,\\s*checkableFields\\(${row}, ${fields}\\)`,
        ),
        `${file}: ${head}`,
      );
      // The edit reads the same list, so the two cannot drift apart.
      assert.match(
        text,
        new RegExp(
          `assertFieldsUnchangedSince\\(\\s*dto\\.expected,\\s*checkableFields\\(\\w+, ${fields}\\)`,
        ),
        `${file}: the edit uses ${fields}`,
      );
    }
    for (const [file, call] of [
      ["guests/guests.controller.ts", "this.guestsService.remove("],
      ["tasks/tasks.controller.ts", "this.tasksService.remove("],
      ["wedding-costs/wedding-costs.controller.ts", "this.service.deleteCost("],
      ["wedding-costs/wedding-costs.controller.ts", "this.service.deleteSchedule("],
    ] as const) {
      const text = source(file);
      const at = text.indexOf(call);
      assert.ok(at >= 0, `${file}: ${call}`);
      assert.match(
        text.slice(at, text.indexOf(");", at)),
        /dto\.expected/,
        `${file}: ${call}`,
      );
    }
  },
);
