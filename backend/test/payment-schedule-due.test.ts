import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { scheduleAmountDue } from "../src/modules/finance/domain/payment-schedule-policy";
import { readMoneyPicture } from "../src/modules/finance/infrastructure/money-picture";

// RA-BE-53: an agreement of 1,000,000 with a reminder of 500,000, then a
// payment of 800,000 made straight on the agreement: 200,000 is left. The
// reminder read 500,000 as «the next payment», and paying it was refused as
// more than what was left.

const d = (value: string) => new Prisma.Decimal(value);

test("RA-BE-53: a reminder asks for no more than the agreement still owes", () => {
  assert.equal(scheduleAmountDue(d("500000"), d("1000000"), d("800000")).toString(), "200000");
});

test("RA-BE-53: a reminder inside what is left asks for its own amount", () => {
  assert.equal(scheduleAmountDue(d("500000"), d("1000000"), d("300000")).toString(), "500000");
  assert.equal(scheduleAmountDue(d("700000"), d("1000000"), d("300000")).toString(), "700000");
});

test("RA-BE-53: nothing is asked of an agreement paid in full", () => {
  assert.equal(scheduleAmountDue(d("500000"), d("1000000"), d("1000000")).toString(), "0");
});

test("RA-BE-53: «the next payment» in the money picture asks for what is left", async () => {
  const tx = {
    budgetCategory: {
      findMany: async () => [
        { id: "hall", name: "القاعة", kind: "WEDDING", allocatedAmount: null },
      ],
    },
    weddingCost: {
      findMany: async ({ where }: any) =>
        where.privateToUserId
          ? []
          : [
              {
                id: "hall-cost",
                budgetCategoryId: "hall",
                totalAmount: d("1000000"),
                title: "القاعة",
                payer: null,
                payerName: null,
              },
            ],
    },
    costPayment: {
      findMany: async () => [
        { weddingCostId: "hall-cost", amount: d("800000"), entryType: "PAYMENT" },
      ],
    },
    paymentSchedule: {
      findMany: async () => [
        {
          id: "reminder-1",
          weddingCostId: "hall-cost",
          amount: d("500000"),
          dueDate: new Date("2026-12-01T00:00:00.000Z"),
          status: "PENDING",
          weddingCost: { budgetCategoryId: "hall" },
        },
      ],
    },
    fundingSource: { findMany: async () => [] },
  } as unknown as Prisma.TransactionClient;

  const picture = await readMoneyPicture(tx, {
    weddingPlanId: "plan-1",
    persona: "GROOM",
    totalBudget: null,
    scope: null,
    readerUserId: "owner-1",
    fundingVisible: false,
    now: new Date("2026-11-07T09:00:00.000Z"),
  } as any);

  assert.equal(picture.costs.outstanding, "200000");
  assert.equal(picture.paymentSchedules.next?.amount, "200000");
  // RA-MO-38: the card names the agreement, not «دفعة».
  assert.equal(picture.paymentSchedules.next?.costTitle, "القاعة");
});
