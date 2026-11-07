import { Injectable } from '@nestjs/common';
import { GuestAttendanceStatus, type Prisma } from '@prisma/client';
import type {
  GuestsPort,
  ImportedGuestInput,
  PlanGuestCounters,
  ReadableGuest,
} from '../public/guests.port';
import { countPlanGuests } from './guests.repository';

@Injectable()
export class GuestsPortService implements GuestsPort {
  async listReadableGuests(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<ReadableGuest[]> {
    return client.guest.findMany({
      where: { weddingPlanId },
      select: { id: true, name: true, attendanceStatus: true },
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
    });
  }

  async getPlanGuestCounters(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    guestIds?: readonly string[] | null,
  ): Promise<PlanGuestCounters> {
    const base = {
      weddingPlanId,
      ...(guestIds ? { id: { in: [...guestIds] } } : {}),
    };
    // A guest's reply is `attendanceStatus`, the column the guest list, its
    // summary and the guest's own reply page write and read; the old
    // `status` could say something else (an imported «confirmed» with no
    // reply), and the home counted it.
    const [total, confirmed, pending, declined, incomplete] = await Promise.all([
      client.guest.count({ where: base }),
      client.guest.count({ where: { ...base, attendanceStatus: GuestAttendanceStatus.CONFIRMED } }),
      client.guest.count({ where: { ...base, attendanceStatus: GuestAttendanceStatus.PENDING } }),
      client.guest.count({ where: { ...base, attendanceStatus: GuestAttendanceStatus.DECLINED } }),
      client.guest.count({
        where: { ...base, OR: [{ phone: null }, { phone: '' }, { name: '' }] },
      }),
    ]);
    return { total, confirmed, pending, declined, incomplete };
  }

  async createImportedGuestsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    guests: readonly ImportedGuestInput[],
  ): Promise<void> {
    if (guests.length === 0) return;
    await tx.guest.createMany({
      data: guests.map((guest) => ({ weddingPlanId, ...guest })),
      skipDuplicates: true,
    });
  }

  async countPlanGuests(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<number> {
    return countPlanGuests(client, weddingPlanId);
  }

  async deletePlanGuestsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void> {
    const inPlans = { weddingPlanId: { in: [...weddingPlanIds] } };
    // D83: a guest's event invites go with the guest (cascade).
    await tx.guest.deleteMany({ where: inPlans });
    await tx.guestGroup.deleteMany({ where: inPlans });
    await tx.guestInvitationCard.deleteMany({ where: inPlans });
  }
}
