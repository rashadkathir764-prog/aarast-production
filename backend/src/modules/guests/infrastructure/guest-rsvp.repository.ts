import { GuestAttendanceStatus, GuestInvitationStatus, GuestStatus, Prisma } from '@prisma/client';

// Guests-owned rows behind the personal RSVP link (V1 checklist 4.7). The
// link token is never stored: only its SHA-256 hash.

type Tx = Prisma.TransactionClient;

const rsvpGuestSelect = {
  id: true,
  weddingPlanId: true,
  name: true,
  normalizedPhone: true,
  invitationStatus: true,
  attendanceStatus: true,
  seatsCount: true,
  companionsCount: true,
  respondedAt: true,
} satisfies Prisma.GuestSelect;

export type RsvpGuest = Prisma.GuestGetPayload<{ select: typeof rsvpGuestSelect }>;

export function findRsvpGuestByTokenHash(client: Tx, tokenHash: string) {
  return client.guest.findUnique({
    where: { rsvpTokenHash: tokenHash },
    select: rsvpGuestSelect,
  });
}

/** Issues a new link (the previous one stops working) and marks the invitation sent. */
export function storeRsvpTokenHash(
  tx: Tx,
  guestId: string,
  tokenHash: string,
  markSent: boolean,
) {
  return tx.guest.update({
    where: { id: guestId },
    data: {
      rsvpTokenHash: tokenHash,
      ...(markSent ? { invitationStatus: GuestInvitationStatus.SENT } : {}),
    },
    select: rsvpGuestSelect,
  });
}

export interface RsvpAnswer {
  attendanceStatus: GuestAttendanceStatus;
  status: GuestStatus;
  companionsCount: number;
  respondedAt: Date;
  invitationStatus: GuestInvitationStatus;
}

export function recordRsvpAnswer(tx: Tx, guestId: string, answer: RsvpAnswer) {
  return tx.guest.update({
    where: { id: guestId },
    data: {
      attendanceStatus: answer.attendanceStatus,
      status: answer.status,
      companionsCount: answer.companionsCount,
      respondedAt: answer.respondedAt,
      invitationStatus: answer.invitationStatus,
    },
    select: rsvpGuestSelect,
  });
}
