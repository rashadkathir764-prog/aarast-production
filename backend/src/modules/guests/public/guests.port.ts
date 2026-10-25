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
export interface PlanGuestCounters {
  total: number;
  confirmed: number;
  pending: number;
  declined: number;
  incomplete: number;
}

/**
 * A guest as every plan member reads it (D52): the name and the reply.
 * Never the phone, the notes or the invitation link; those stay with the
 * members who manage guests.
 */
export interface ReadableGuest {
  id: string;
  name: string;
  attendanceStatus: GuestAttendanceStatus;
}

export interface GuestsPort {
  /** D52: every guest of the plan by name and reply, in name order. */
  listReadableGuests(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<ReadableGuest[]>;
  /** The plan dashboard's guest counters; `guestIds` narrows to a contributor's guests. */
  getPlanGuestCounters(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    guestIds?: readonly string[] | null,
  ): Promise<PlanGuestCounters>;
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
