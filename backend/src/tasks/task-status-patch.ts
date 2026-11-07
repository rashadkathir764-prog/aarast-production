import { WeddingTaskStatus } from "@prisma/client";

/**
 * R4: a status set by hand stays set, so no link undoes it later
 * (`autoClosedAt` cleared). RA-BE-67: the phone sends the task's status with
 * every edit, so a status sent unchanged is not a hand change; it kept
 * clearing the mark, and a task a booking had closed stayed done after the
 * booking was cancelled (D71: «ترجع إذا انلغيا»).
 */
export function manualStatusPatch(
  current: WeddingTaskStatus,
  sent: WeddingTaskStatus | undefined,
): { status?: WeddingTaskStatus; autoClosedAt?: null } {
  if (sent === undefined || sent === current) return {};
  return { status: sent, autoClosedAt: null };
}
