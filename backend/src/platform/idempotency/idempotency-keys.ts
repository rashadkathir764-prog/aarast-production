import type { Prisma } from '@prisma/client';

// Platform owns `IdempotencyKey` (keyed by userId / phone with no User
// foreign key: never cascades). Identity's account deletion and its
// deletion-status endpoint reach the rows through these functions.
export interface IdempotencyReservation {
  id: string;
  method: string;
  path: string;
  completedAt: Date | null;
  createdAt: Date;
}

export async function findIdempotencyReservation(
  tx: Prisma.TransactionClient,
  userId: string,
  key: string,
): Promise<IdempotencyReservation | null> {
  return tx.idempotencyKey.findUnique({
    where: { userId_key: { userId, key } },
    select: {
      id: true,
      method: true,
      path: true,
      completedAt: true,
      createdAt: true,
    },
  });
}

/** Deletes one reservation only while it is still open and older than `staleBefore`. */
export async function deleteStaleIdempotencyReservation(
  tx: Prisma.TransactionClient,
  reservationId: string,
  staleBefore: Date,
): Promise<void> {
  await tx.idempotencyKey.deleteMany({
    where: {
      id: reservationId,
      completedAt: null,
      createdAt: { lte: staleBefore },
    },
  });
}

export async function deleteIdempotencyKeysForUser(
  tx: Prisma.TransactionClient,
  userId: string,
): Promise<void> {
  await tx.idempotencyKey.deleteMany({ where: { userId } });
}

/** Retained administrator identity: deletes the user's keys except those of the admin surfaces. */
export async function deleteApplicationIdempotencyKeysForUser(
  tx: Prisma.TransactionClient,
  userId: string,
): Promise<void> {
  await tx.idempotencyKey.deleteMany({
    where: {
      userId,
      NOT: {
        OR: [
          { path: '/admin' },
          { path: { startsWith: '/admin/' } },
          { path: '/api/v1/admin' },
          { path: { startsWith: '/api/v1/admin/' } },
          { path: '/api/v1/auth/admin' },
          { path: { startsWith: '/api/v1/auth/admin/' } },
        ],
      },
    },
  });
}
