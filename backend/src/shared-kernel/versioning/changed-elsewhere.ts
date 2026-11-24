import { BadRequestException, ConflictException } from "@nestjs/common";
import { Prisma } from "@prisma/client";

/**
 * RA-MO-344: an edit made from an older read of a field is refused, as the
 * budget's save is (D112, Q-4, `BUDGET_CHANGED_ELSEWHERE`). A guest, a task,
 * a cost or a payment date edited on a phone without a net was sent later
 * over what the partner (or the guest's own answer) changed meanwhile, and
 * the last writer won.
 *
 * The check is by field: the edit sends, in `expected`, the value it last
 * read of each field it changes, and is refused only when one of THOSE
 * fields differs now. Anything else that changed the row since (the guest
 * opening their link, a task closing itself, a payment on the cost) refuses
 * nothing. An edit without `expected` is taken as before.
 */
export const CHANGED_ELSEWHERE = "CHANGED_ELSEWHERE";

/** The values of a row an edit may say it read, by the edit's field names. */
export type CheckableFields = Readonly<Record<string, unknown>>;

export function assertFieldsUnchangedSince(
  expected: Readonly<Record<string, unknown>> | undefined,
  current: CheckableFields,
  message: string,
): void {
  if (expected === undefined) return;
  for (const [field, read] of Object.entries(expected)) {
    if (!Object.prototype.hasOwnProperty.call(current, field)) {
      throw new BadRequestException({
        statusCode: 400,
        code: "EXPECTED_FIELD_UNKNOWN",
        message: `expected.${field} is not a field this edit can check`,
      });
    }
    if (!sameValue(current[field], read)) {
      throw new ConflictException({
        statusCode: 409,
        code: CHANGED_ELSEWHERE,
        message,
      });
    }
  }
}

/** The fields of [row] named in [fields], for [assertFieldsUnchangedSince]. */
export function checkableFields<T extends object, K extends keyof T & string>(
  row: T,
  fields: readonly K[],
): CheckableFields {
  return Object.fromEntries(fields.map((field) => [field, row[field]]));
}

/** The value now against the value read, as JSON carried it. */
function sameValue(now: unknown, read: unknown): boolean {
  if (now === null || now === undefined) return read === null;
  if (read === null || read === undefined) return false;
  if (now instanceof Date) {
    return (
      typeof read === "string" && new Date(read).getTime() === now.getTime()
    );
  }
  if (Prisma.Decimal.isDecimal(now)) {
    if (typeof read !== "string" && typeof read !== "number") return false;
    try {
      return now.equals(read);
    } catch {
      return false;
    }
  }
  return now === read;
}
