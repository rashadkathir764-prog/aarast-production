import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { BadRequestException, ConflictException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { validate } from "class-validator";
import { UpdateGuestDto } from "../src/guests/dto/update-guest.dto";
import {
  assertFieldsUnchangedSince,
  CHANGED_ELSEWHERE,
  checkableFields,
} from "../src/shared-kernel/versioning/changed-elsewhere";
import { UpdateTaskDto } from "../src/tasks/dto/update-task.dto";
import { UpdatePaymentScheduleDto } from "../src/wedding-costs/dto/update-payment-schedule.dto";
import { UpdateWeddingCostDto } from "../src/wedding-costs/dto/update-wedding-cost.dto";

// RA-MO-344: a guest, a task, a cost or a payment date edited on a phone
// without a net was sent later over what the partner (or the guest's own
// answer) changed meanwhile: the last writer won. As the budget (D112,
// Q-4), an edit made from an older read is refused, by field: the edit says
// what it last read of each field it changes, and only a change to one of
// THOSE fields refuses it. Anything else that touched the row since (the
// guest opening their link, a task closing itself, a payment on the cost)
// refuses nothing.

const refusedAsChangedElsewhere = (message: string) => (error: unknown) => {
  assert.ok(error instanceof ConflictException);
  assert.deepEqual(error.getResponse(), {
    statusCode: 409,
    code: CHANGED_ELSEWHERE,
    message,
  });
  return true;
};

const guestFields = ["name", "phone", "notes", "attendanceStatus"] as const;
const guestWords = "الضيف تغيّر من جهاز ثاني. حدّث الشاشة وعدّل من جديد.";
const guestRead = {
  name: "خلد",
  phone: "+967777123456",
  notes: null,
  attendanceStatus: "PENDING",
  linkOpenedAt: null as Date | null,
  rsvpLinkHash: null as string | null,
  updatedAt: new Date("2026-11-24T10:00:00.000Z"),
};

test("the guest opened their link, then the owner renames: accepted", () => {
  const now = {
    ...guestRead,
    linkOpenedAt: new Date("2026-11-24T10:30:00.000Z"),
    rsvpLinkHash: "hash",
    updatedAt: new Date("2026-11-24T10:30:00.000Z"),
  };
  assert.doesNotThrow(() =>
    assertFieldsUnchangedSince(
      { name: guestRead.name },
      checkableFields(now, guestFields),
      guestWords,
    ),
  );
});

test(
  "the guest answered, then the owner renames: accepted; the owner's " +
    "answer from the old read: refused",
  () => {
    const now = { ...guestRead, attendanceStatus: "CONFIRMED" };
    assert.doesNotThrow(() =>
      assertFieldsUnchangedSince(
        { name: guestRead.name },
        checkableFields(now, guestFields),
        guestWords,
      ),
    );
    assert.throws(
      () =>
        assertFieldsUnchangedSince(
          { attendanceStatus: "PENDING" },
          checkableFields(now, guestFields),
          guestWords,
        ),
      refusedAsChangedElsewhere(guestWords),
    );
  },
);

test(
  "the partner renamed the guest, then the owner renames from the old " +
    "read: refused",
  () => {
    const now = { ...guestRead, name: "خالد الحمدي" };
    assert.throws(
      () =>
        assertFieldsUnchangedSince(
          { name: guestRead.name },
          checkableFields(now, guestFields),
          guestWords,
        ),
      refusedAsChangedElsewhere(guestWords),
    );
  },
);

test(
  "a task that closed itself still takes a title edit; a status edit " +
    "from before it closed is refused",
  () => {
    const words = "المهمة تغيّرت من جهاز ثاني. حدّث الشاشة وعدّل من جديد.";
    const fields = ["title", "status", "dueDate"] as const;
    const now = {
      title: "حجز القاعة",
      status: "DONE",
      dueDate: new Date("2027-04-10T00:00:00.000Z"),
      autoClosedAt: new Date("2026-11-24T11:00:00.000Z"),
    };
    assert.doesNotThrow(() =>
      assertFieldsUnchangedSince(
        { title: "حجز القاعة", dueDate: "2027-04-10T00:00:00.000Z" },
        checkableFields(now, fields),
        words,
      ),
    );
    assert.throws(
      () =>
        assertFieldsUnchangedSince(
          { status: "TODO" },
          checkableFields(now, fields),
          words,
        ),
      refusedAsChangedElsewhere(words),
    );
  },
);

test(
  "a cost's amount: the same figure in another writing passes; a figure " +
    "changed since is refused; a payment on it refuses nothing",
  () => {
    const words = "التكلفة تغيّرت من جهاز ثاني. حدّث الشاشة وعدّل من جديد.";
    const fields = ["title", "totalAmount"] as const;
    const now = {
      title: "القاعة",
      totalAmount: new Prisma.Decimal("500000"),
      paidAmount: new Prisma.Decimal("100000"),
    };
    assert.doesNotThrow(() =>
      assertFieldsUnchangedSince(
        { totalAmount: "500000.00", title: "القاعة" },
        checkableFields(now, fields),
        words,
      ),
    );
    assert.throws(
      () =>
        assertFieldsUnchangedSince(
          { totalAmount: "450000" },
          checkableFields(now, fields),
          words,
        ),
      refusedAsChangedElsewhere(words),
    );
  },
);

test(
  "an edit without what it read is taken as before; a field the edit " +
    "cannot check is refused as a bad request",
  () => {
    assert.doesNotThrow(() =>
      assertFieldsUnchangedSince(
        undefined,
        checkableFields(guestRead, guestFields),
        guestWords,
      ),
    );
    assert.throws(
      () =>
        assertFieldsUnchangedSince(
          { linkOpenedAt: null },
          checkableFields(guestRead, guestFields),
          guestWords,
        ),
      BadRequestException,
    );
  },
);

test("the four edits carry what they read as an object only", async () => {
  for (const Dto of [
    UpdateGuestDto,
    UpdateTaskDto,
    UpdateWeddingCostDto,
    UpdatePaymentScheduleDto,
  ]) {
    const ok = Object.assign(new Dto(), { expected: { note: null } });
    assert.deepEqual(await validate(ok), [], Dto.name);
    for (const expected of [42, "2026-11-24"]) {
      const bad = Object.assign(new Dto(), { expected });
      assert.equal((await validate(bad)).length, 1, Dto.name);
    }
  }
});

test(
  "each edit checks its own fields against the row it locked, never a " +
    "field only the server writes",
  () => {
    const source = (file: string) =>
      readFileSync(join(__dirname, "../src", file), "utf8");
    // The edits and the deletes read the same list of fields (RA-MO-344), so
    // each list is declared once, per entity.
    const checks = [
      ["guests/guests.service.ts", "current", "GUEST_CHECKABLE_FIELDS"],
      ["tasks/tasks.service.ts", "current", "TASK_CHECKABLE_FIELDS"],
      ["wedding-costs/wedding-costs.service.ts", "snapshot", "COST_CHECKABLE_FIELDS"],
      ["wedding-costs/wedding-costs.service.ts", "schedule", "SCHEDULE_CHECKABLE_FIELDS"],
    ] as const;
    for (const [file, row, list] of checks) {
      const text = source(file);
      assert.match(
        text,
        new RegExp(
          `assertFieldsUnchangedSince\\(\\s*dto\\.expected,\\s*checkableFields\\(${row}, ${list}\\)`,
        ),
        `${file}: ${row}`,
      );
      const declared = new RegExp(
        `export const ${list} = \\[([^\\]]*)\\] as const`,
      ).exec(text);
      assert.ok(declared, `${file}: ${list}`);
      for (const serverOnly of [
        "updatedAt",
        "linkOpenedAt",
        "respondedAt",
        "rsvpLinkHash",
        "rsvpTokenHash",
        "autoClosedAt",
        "paidAmount",
        "paidAt",
      ]) {
        assert.doesNotMatch(declared[1], new RegExp(`"${serverOnly}"`), file);
      }
    }
  },
);
