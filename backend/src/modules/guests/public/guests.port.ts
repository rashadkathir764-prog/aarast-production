import type {
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
  Prisma,
} from '@prisma/client';

export const GUESTS_PORT = Symbol('GUESTS_PORT');

export interface ImportedGuestInput {
  name: string;
  normalizedName: string;
  phone: string | null;
  normalizedPhone: string | null;
  side: GuestSide;
  status: GuestStatus;
  invitationStatus: GuestInvitationStatus;
  attendanceStatus: GuestAttendanceStatus;
  seatsCount: number;
  companionsCount: number;
  notes: string | null;
}

// Guests owns `Guest` and `GuestGroup`. Planning's local plan import
// creates the imported guests through this port inside its transaction
// (duplicates skipped, as before) and reports their count.
export interface GuestsPort {
  createImportedGuestsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    guests: readonly ImportedGuestInput[],
  ): Promise<void>;
  countPlanGuests(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<number>;
  /** Account erasure: deletes the plans' guests, then their guest groups. */
  deletePlanGuestsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void>;
}
