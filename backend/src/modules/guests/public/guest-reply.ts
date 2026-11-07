import {
  GuestAttendanceStatus,
  GuestStatus,
} from '@prisma/client';

/**
 * A guest's reply is one fact kept in two columns: the owner's form writes
 * `status`, the guest's own reply page `attendanceStatus`. Every write of one
 * sets the other from it, so the guest list, its summary and the home read
 * the same answer. The one rule, for every place that writes a guest.
 */
export function attendanceFromStatus(
  status: GuestStatus | undefined,
): GuestAttendanceStatus {
  if (status === GuestStatus.CONFIRMED) return GuestAttendanceStatus.CONFIRMED;
  if (status === GuestStatus.DECLINED) return GuestAttendanceStatus.DECLINED;
  return GuestAttendanceStatus.PENDING;
}

export function statusFromAttendance(
  attendance: GuestAttendanceStatus | undefined,
): GuestStatus | null {
  if (attendance === GuestAttendanceStatus.CONFIRMED) return GuestStatus.CONFIRMED;
  if (attendance === GuestAttendanceStatus.DECLINED) return GuestStatus.DECLINED;
  if (attendance === GuestAttendanceStatus.PENDING) return GuestStatus.PENDING;
  return null;
}
