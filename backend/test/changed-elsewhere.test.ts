import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { ConflictException } from "@nestjs/common";
import { validate } from "class-validator";
import { UpdateGuestDto } from "../src/guests/dto/update-guest.dto";
import {
  assertUnchangedSince,
  CHANGED_ELSEWHERE,
} from "../src/shared-kernel/versioning/changed-elsewhere";
import { UpdateTaskDto } from "../src/tasks/dto/update-task.dto";
import { UpdatePaymentScheduleDto } from "../src/wedding-costs/dto/update-payment-schedule.dto";
import { UpdateWeddingCostDto } from "../src/wedding-costs/dto/update-wedding-cost.dto";

// RA-MO-344: a guest, a task, a cost or a payment date edited on a phone
// without a net was sent later over what the partner (or the guest's own
// answer) changed meanwhile: the last writer won. As the budget (D112, Q-4),
// an edit made from an older read is refused. The version is the row's
// `updatedAt` as the server last returned it.

const read = new Date("2026-11-24T10:00:00.000Z");

test("an edit made from the row as it is now passes", () => {
  assert.doesNotThrow(() =>
    assertUnchangedSince(read.toISOString(), read, "تغيّر"),
  );
  // The same instant, written another way.
  assert.doesNotThrow(() =>
    assertUnchangedSince("2026-11-24T13:00:00.000+03:00", read, "تغيّر"),
  );
});

test("an edit without a version is taken as before", () => {
  assert.doesNotThrow(() => assertUnchangedSince(undefined, read, "تغيّر"));
});

test("an edit made from an older read is refused with the row's words", () => {
  assert.throws(
    () =>
      assertUnchangedSince(
        "2026-11-24T09:59:59.999Z",
        read,
        "الضيف تغيّر من جهاز ثاني. حدّث الشاشة وعدّل من جديد.",
      ),
    (error: unknown) => {
      assert.ok(error instanceof ConflictException);
      assert.deepEqual(error.getResponse(), {
        statusCode: 409,
        code: CHANGED_ELSEWHERE,
        message: "الضيف تغيّر من جهاز ثاني. حدّث الشاشة وعدّل من جديد.",
      });
      return true;
    },
  );
});

test("the four edits carry the version as a time only", async () => {
  for (const Dto of [
    UpdateGuestDto,
    UpdateTaskDto,
    UpdateWeddingCostDto,
    UpdatePaymentScheduleDto,
  ]) {
    const ok = Object.assign(new Dto(), {
      expectedVersion: read.toISOString(),
    });
    assert.deepEqual(await validate(ok), [], Dto.name);
    for (const expectedVersion of [42, "yesterday"]) {
      const bad = Object.assign(new Dto(), { expectedVersion });
      assert.equal((await validate(bad)).length, 1, Dto.name);
    }
  }
});

test("each edit checks the version against the row it locked", () => {
  const source = (file: string) =>
    readFileSync(join(__dirname, "../src", file), "utf8");
  for (const [file, row] of [
    ["guests/guests.service.ts", "current.updatedAt"],
    ["tasks/tasks.service.ts", "current.updatedAt"],
    ["wedding-costs/wedding-costs.service.ts", "snapshot.updatedAt"],
    ["wedding-costs/wedding-costs.service.ts", "schedule.updatedAt"],
  ]) {
    assert.match(
      source(file),
      new RegExp(
        `assertUnchangedSince\\(\\s*dto\\.expectedVersion,\\s*${row.replace(".", "\\.")},`,
      ),
      `${file}: ${row}`,
    );
  }
});
