import {
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
  Prisma,
} from '@prisma/client';
import { ListQueryDto, pageArgs } from '../../../platform/http/list-query.dto';
import { PrismaService } from '../../../platform/database/prisma.service';

export function listPlanGuests(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  contributorIds: readonly string[] | null,
  query?: ListQueryDto,
) {
  return tx.guest.findMany({
    where: {
      weddingPlanId,
      ...(contributorIds ? { id: { in: [...contributorIds] } } : {}),
    },
    orderBy: [{ createdAt: 'desc' }],
    ...pageArgs(query),
  });
}

export function findGuestById(client: PrismaService | Prisma.TransactionClient, id: string) {
  return client.guest.findUnique({ where: { id } });
}

export function updateGuest(
  tx: Prisma.TransactionClient,
  id: string,
  values: {
    name?: string;
    normalizedName?: string;
    phone?: string | null;
    normalizedPhone?: string | null;
    groupId?: string | null;
    side?: GuestSide;
    status?: GuestStatus;
    invitationStatus?: GuestInvitationStatus;
    attendanceStatus?: GuestAttendanceStatus;
    seatsCount?: number;
    companionsCount?: number;
    notes?: string | null;
  },
) {
  return tx.guest.update({
    where: { id },
    data: {
      ...(values.name !== undefined
        ? { name: values.name, normalizedName: values.normalizedName }
        : {}),
      ...(values.phone !== undefined
        ? { phone: values.phone, normalizedPhone: values.normalizedPhone }
        : {}),
      ...(values.groupId !== undefined
        ? {
            group: values.groupId
              ? { connect: { id: values.groupId } }
              : { disconnect: true },
          }
        : {}),
      ...(values.side !== undefined ? { side: values.side } : {}),
      ...(values.status !== undefined ? { status: values.status } : {}),
      ...(values.invitationStatus !== undefined
        ? { invitationStatus: values.invitationStatus }
        : {}),
      ...(values.attendanceStatus !== undefined
        ? { attendanceStatus: values.attendanceStatus }
        : {}),
      ...(values.seatsCount !== undefined ? { seatsCount: values.seatsCount } : {}),
      ...(values.companionsCount !== undefined
        ? { companionsCount: values.companionsCount }
        : {}),
      ...(values.notes !== undefined ? { notes: values.notes } : {}),
    },
  });
}

export function deleteGuest(tx: Prisma.TransactionClient, id: string) {
  return tx.guest.delete({ where: { id } });
}

export function listPlanGuestGroups(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  contributorIds: readonly string[] | null,
) {
  return tx.guestGroup.findMany({
    where: {
      weddingPlanId,
      ...(contributorIds ? { id: { in: [...contributorIds] } } : {}),
    },
    orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
  });
}

export function createGuestGroup(
  tx: Prisma.TransactionClient,
  data: { weddingPlanId: string; name: string; notes: string | null; sortOrder: number },
) {
  return tx.guestGroup.create({ data });
}

export function updateGuestGroup(
  tx: Prisma.TransactionClient,
  id: string,
  values: { name?: string; notes?: string | null; sortOrder?: number },
) {
  return tx.guestGroup.update({
    where: { id },
    data: {
      ...(values.name !== undefined ? { name: values.name } : {}),
      ...(values.notes !== undefined ? { notes: values.notes } : {}),
      ...(values.sortOrder !== undefined ? { sortOrder: values.sortOrder } : {}),
    },
  });
}

export function deleteGuestGroup(tx: Prisma.TransactionClient, id: string) {
  return tx.guestGroup.delete({ where: { id } });
}

export function listGuestsForSummary(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  contributorIds: readonly string[] | null,
) {
  return tx.guest.findMany({
    where: {
      weddingPlanId,
      ...(contributorIds ? { id: { in: [...contributorIds] } } : {}),
    },
    include: { group: { select: { name: true } } },
  });
}

export function countGuestGroupsForSummary(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  contributorIds: readonly string[] | null,
) {
  return tx.guestGroup.count({
    where: {
      weddingPlanId,
      ...(contributorIds ? { id: { in: [...contributorIds] } } : {}),
    },
  });
}

export function createGuest(
  tx: Prisma.TransactionClient,
  values: {
    weddingPlanId: string;
    groupId: string | null;
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
  },
) {
  return tx.guest.create({
    data: {
      weddingPlanId: values.weddingPlanId,
      groupId: values.groupId,
      name: values.name,
      normalizedName: values.normalizedName,
      phone: values.phone,
      normalizedPhone: values.normalizedPhone,
      side: values.side,
      status: values.status,
      invitationStatus: values.invitationStatus,
      attendanceStatus: values.attendanceStatus,
      seatsCount: values.seatsCount,
      companionsCount: values.companionsCount,
      notes: values.notes,
    },
  });
}

export function findGuestGroupById(client: PrismaService | Prisma.TransactionClient, id: string) {
  return client.guestGroup.findUnique({ where: { id } });
}

export async function lockGuestForUpdate(
  tx: Prisma.TransactionClient,
  id: string,
  weddingPlanId: string,
): Promise<boolean> {
  const locked = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id"
      FROM "Guest"
      WHERE "id" = ${id}
        AND "weddingPlanId" = ${weddingPlanId}
      FOR UPDATE
    `,
  );
  return locked.length === 1;
}

export async function lockGuestGroupForUpdate(
  tx: Prisma.TransactionClient,
  id: string,
  weddingPlanId: string,
): Promise<boolean> {
  const locked = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id"
      FROM "GuestGroup"
      WHERE "id" = ${id}
        AND "weddingPlanId" = ${weddingPlanId}
      FOR UPDATE
    `,
  );
  return locked.length === 1;
}

export function findDuplicateGuest(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  normalizedPhone: string,
  excludeGuestId?: string,
) {
  return tx.guest.findFirst({
    where: {
      weddingPlanId,
      normalizedPhone,
      ...(excludeGuestId ? { NOT: { id: excludeGuestId } } : {}),
    },
    select: { id: true },
  });
}

export async function lockGuestGroupForShare(
  tx: Prisma.TransactionClient,
  groupId: string,
  weddingPlanId: string,
): Promise<boolean> {
  const locked = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id"
      FROM "GuestGroup"
      WHERE "id" = ${groupId}
        AND "weddingPlanId" = ${weddingPlanId}
      FOR SHARE
    `,
  );
  return locked.length === 1;
}

// D83: a guest's invitations to the plan's events beyond the wedding, with
// their reply to each; and the plan's one invitation card.

const guestEventInviteSelect = {
  guestId: true,
  planEventId: true,
  attendanceStatus: true,
  companionsCount: true,
  respondedAt: true,
} satisfies Prisma.GuestEventInviteSelect;

export type GuestEventInviteRow = Prisma.GuestEventInviteGetPayload<{
  select: typeof guestEventInviteSelect;
}>;

export function listGuestEventInvites(
  client: PrismaService | Prisma.TransactionClient,
  guestIds: readonly string[],
): Promise<GuestEventInviteRow[]> {
  if (guestIds.length === 0) return Promise.resolve([]);
  return client.guestEventInvite.findMany({
    where: { guestId: { in: [...guestIds] } },
    select: guestEventInviteSelect,
    orderBy: [{ createdAt: 'asc' }, { planEventId: 'asc' }],
  });
}

export function findGuestEventInvite(
  tx: Prisma.TransactionClient,
  guestId: string,
  planEventId: string,
): Promise<GuestEventInviteRow | null> {
  return tx.guestEventInvite.findFirst({
    where: { guestId, planEventId },
    select: guestEventInviteSelect,
  });
}

/** The guest's events become exactly [planEventIds]; replies to kept events stay. */
export async function replaceGuestEventInvites(
  tx: Prisma.TransactionClient,
  guestId: string,
  planEventIds: readonly string[],
): Promise<void> {
  const ids = [...new Set(planEventIds)];
  await tx.guestEventInvite.deleteMany({
    where: { guestId, planEventId: { notIn: ids } },
  });
  if (ids.length === 0) return;
  await tx.guestEventInvite.createMany({
    data: ids.map((planEventId) => ({ guestId, planEventId })),
    skipDuplicates: true,
  });
}

export function recordGuestEventAnswer(
  tx: Prisma.TransactionClient,
  guestId: string,
  planEventId: string,
  answer: {
    attendanceStatus: GuestAttendanceStatus;
    companionsCount: number;
    respondedAt: Date;
  },
): Promise<GuestEventInviteRow> {
  return tx.guestEventInvite.update({
    where: { guestId_planEventId: { guestId, planEventId } },
    data: answer,
    select: guestEventInviteSelect,
  });
}

const invitationCardSelect = {
  id: true,
  weddingPlanId: true,
  hostLine: true,
  freeText: true,
  photoUrl: true,
  mapUrl: true,
  address: true,
  updatedAt: true,
} satisfies Prisma.GuestInvitationCardSelect;

export type GuestInvitationCardRow = Prisma.GuestInvitationCardGetPayload<{
  select: typeof invitationCardSelect;
}>;

export function findGuestInvitationCard(
  client: PrismaService | Prisma.TransactionClient,
  weddingPlanId: string,
): Promise<GuestInvitationCardRow | null> {
  return client.guestInvitationCard.findUnique({
    where: { weddingPlanId },
    select: invitationCardSelect,
  });
}

export function upsertGuestInvitationCard(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  values: {
    hostLine: string | null;
    freeText: string | null;
    photoUrl: string | null;
    mapUrl: string | null;
    address: string | null;
  },
): Promise<GuestInvitationCardRow> {
  return tx.guestInvitationCard.upsert({
    where: { weddingPlanId },
    create: { weddingPlanId, ...values },
    update: values,
    select: invitationCardSelect,
  });
}

export function deleteGuestInvitationCards(
  tx: Prisma.TransactionClient,
  weddingPlanIds: readonly string[],
) {
  return tx.guestInvitationCard.deleteMany({
    where: { weddingPlanId: { in: [...weddingPlanIds] } },
  });
}
