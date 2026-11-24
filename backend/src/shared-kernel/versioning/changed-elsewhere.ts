import { ConflictException } from "@nestjs/common";

/**
 * RA-MO-344: an edit made from an older read of a row is refused, as the
 * budget's save is (D112, Q-4, `BUDGET_CHANGED_ELSEWHERE`). A guest, a task,
 * a cost or a payment date edited on a phone without a net was sent later
 * over what the partner (or the guest's own answer) changed meanwhile, and
 * the last writer won.
 *
 * The version is the row's `updatedAt` as the server last returned it: the
 * phone sends it back as `expectedVersion`. An edit without one is taken as
 * before.
 */
export const CHANGED_ELSEWHERE = "CHANGED_ELSEWHERE";

export function assertUnchangedSince(
  expectedVersion: string | undefined,
  updatedAt: Date,
  message: string,
): void {
  if (expectedVersion === undefined) return;
  if (new Date(expectedVersion).getTime() === updatedAt.getTime()) return;
  throw new ConflictException({
    statusCode: 409,
    code: CHANGED_ELSEWHERE,
    message,
  });
}
