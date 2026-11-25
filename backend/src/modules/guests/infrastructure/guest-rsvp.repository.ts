import {
  GuestAttendanceStatus,
  GuestInvitationSendChannel,
  GuestInvitationSendKind,
  GuestInvitationSendStatus,
  GuestInvitationStatus,
  GuestStatus,
  Prisma,
} from '@prisma/client';

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
  weddingAnsweredVersion: true,
  rsvpLinkHash: true,
  rsvpLinkVersion: true,
  linkOpenedAt: true,
} satisfies Prisma.GuestSelect;

export type RsvpGuest = Prisma.GuestGetPayload<{ select: typeof rsvpGuestSelect }>;

/**
 * D116: the guest a link opens. The stable link, or the last random link
 * sent before D116, which keeps opening until the link is replaced.
 */
export function findRsvpGuestByTokenHash(client: Tx, tokenHash: string) {
  return client.guest.findFirst({
    where: { OR: [{ rsvpLinkHash: tokenHash }, { rsvpTokenHash: tokenHash }] },
    select: rsvpGuestSelect,
  });
}

/** D116: keeps the stable link's hash; nothing is marked sent. */
export function storeRsvpLinkHash(tx: Tx, guestId: string, linkHash: string) {
  return tx.guest.update({
    where: { id: guestId },
    data: { rsvpLinkHash: linkHash },
    select: rsvpGuestSelect,
  });
}

/**
 * D116: a new link for the guest. The version rises, the stable link moves
 * to the new one, and the last random link from before D116 stops too.
 */
export function replaceRsvpLink(
  tx: Tx,
  guestId: string,
  version: number,
  linkHash: string,
) {
  return tx.guest.update({
    where: { id: guestId },
    data: { rsvpLinkVersion: version, rsvpLinkHash: linkHash, rsvpTokenHash: null },
    select: rsvpGuestSelect,
  });
}

/** D116: the page was drawn in a browser; the first time is kept. */
export async function markRsvpLinkOpened(tx: Tx, guestId: string, at: Date): Promise<void> {
  await tx.guest.updateMany({
    where: { id: guestId, linkOpenedAt: null },
    data: { linkOpenedAt: at },
  });
}

export interface RsvpAnswer {
  attendanceStatus: GuestAttendanceStatus;
  status: GuestStatus;
  companionsCount: number;
  respondedAt: Date;
  invitationStatus: GuestInvitationStatus;
  /** D116: the wedding row's version answered. */
  weddingAnsweredVersion: number;
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
      weddingAnsweredVersion: answer.weddingAnsweredVersion,
    },
    select: rsvpGuestSelect,
  });
}

/**
 * RA-BE-190: how many of the plan's guests have answered since [since], by
 * the wedding or by any occasion, this answer included.
 */
export function countGuestsAnsweredSince(tx: Tx, weddingPlanId: string, since: Date) {
  return tx.guest.count({
    where: {
      weddingPlanId,
      OR: [
        { respondedAt: { gte: since } },
        { eventInvites: { some: { respondedAt: { gte: since } } } },
      ],
    },
  });
}

// D116: the record of what each guest was told.

const invitationSendSelect = {
  id: true,
  weddingPlanId: true,
  guestId: true,
  kind: true,
  planEventId: true,
  events: true,
  channel: true,
  status: true,
  createdAt: true,
  settledAt: true,
} satisfies Prisma.GuestInvitationSendSelect;

export type GuestInvitationSendRow = Prisma.GuestInvitationSendGetPayload<{
  select: typeof invitationSendSelect;
}>;

export function createGuestInvitationSend(
  tx: Tx,
  data: {
    weddingPlanId: string;
    guestId: string;
    kind: GuestInvitationSendKind;
    planEventId: string | null;
    events: ReadonlyArray<{ planEventId: string; version: number }>;
    channel: GuestInvitationSendChannel;
    createdByUserId: string;
  },
): Promise<GuestInvitationSendRow> {
  return tx.guestInvitationSend.create({
    data: { ...data, events: data.events.map((event) => ({ ...event })) },
    select: invitationSendSelect,
  });
}

export function findGuestInvitationSend(
  tx: Tx,
  id: string,
): Promise<GuestInvitationSendRow | null> {
  return tx.guestInvitationSend.findUnique({ where: { id }, select: invitationSendSelect });
}

export function settleGuestInvitationSend(
  tx: Tx,
  id: string,
  status: GuestInvitationSendStatus,
  channel: GuestInvitationSendChannel | undefined,
  at: Date,
): Promise<GuestInvitationSendRow> {
  return tx.guestInvitationSend.update({
    where: { id },
    data: { status, settledAt: at, ...(channel ? { channel } : {}) },
    select: invitationSendSelect,
  });
}

/** The sends of [guestIds], oldest first; every status. */
export function listGuestInvitationSends(
  client: Tx,
  guestIds: readonly string[],
): Promise<GuestInvitationSendRow[]> {
  if (guestIds.length === 0) return Promise.resolve([]);
  return client.guestInvitationSend.findMany({
    where: { guestId: { in: [...guestIds] } },
    select: invitationSendSelect,
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
  });
}

/** The occasions a send named, as stored: [{ planEventId, version }]. */
export function sendEvents(
  row: Pick<GuestInvitationSendRow, 'events'>,
): Array<{ planEventId: string; version: number }> {
  if (!Array.isArray(row.events)) return [];
  return row.events.flatMap((entry) => {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) return [];
    const record = entry as Record<string, unknown>;
    return typeof record.planEventId === 'string' && typeof record.version === 'number'
      ? [{ planEventId: record.planEventId, version: record.version }]
      : [];
  });
}
