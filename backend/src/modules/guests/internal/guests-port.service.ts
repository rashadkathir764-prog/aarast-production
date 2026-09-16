import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import type { GuestsPort, ImportedGuestInput } from '../public/guests.port';

@Injectable()
export class GuestsPortService implements GuestsPort {
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
    return client.guest.count({ where: { weddingPlanId } });
  }

  async deletePlanGuestsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void> {
    const inPlans = { weddingPlanId: { in: [...weddingPlanIds] } };
    await tx.guest.deleteMany({ where: inPlans });
    await tx.guestGroup.deleteMany({ where: inPlans });
  }
}
