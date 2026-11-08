import { WeddingTaskStatus } from "@prisma/client";

/**
 * R4: a status set by hand stays set, so no link undoes it later
 * (`autoClosedAt` cleared). RA-BE-67: the phone sends the task's status with
 * every edit, so a status sent unchanged is not a hand change; it kept
 * clearing the mark, and a task a booking had closed stayed done after the
 * booking was cancelled (D71: «ترجع إذا انلغيا»). RA-BE-68: a finished task
 * reopened by hand is marked, so the booking that closed it (still there)
 * does not close it again when its agreement is next edited (D71: «ولا يلمس
 * النظام مهمة غيّرها صاحبها بيده»).
 */
export function manualStatusPatch(
  current: WeddingTaskStatus,
  sent: WeddingTaskStatus | undefined,
  at: Date = new Date(),
): {
  status?: WeddingTaskStatus;
  autoClosedAt?: null;
  reopenedByHandAt?: Date | null;
} {
  if (sent === undefined || sent === current) return {};
  const reopened =
    current === WeddingTaskStatus.DONE && sent !== WeddingTaskStatus.DONE;
  return { status: sent, autoClosedAt: null, reopenedByHandAt: reopened ? at : null };
}
