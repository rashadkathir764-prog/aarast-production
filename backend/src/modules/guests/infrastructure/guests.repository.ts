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
