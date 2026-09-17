import type { Prisma } from '@prisma/client';

export const PROVIDER_ACCOUNT_PORT = Symbol('PROVIDER_ACCOUNT_PORT');

// Whether an application identity may become a provider account, and the
// role change itself, are identity's decisions over its `User` row. The
// marketplace provider application calls this inside its serializable
// transaction after it has locked the applicant's lifecycle row.
export interface ProviderAccountPort {
  /**
   * Promotes the active application identity to a provider account: an
   * ordinary user or an existing provider gains the PROVIDER roles; an admin
   * keeps the ADMIN role and gains the PROVIDER app role only when an
   * application password is configured. False when the account is not
   * eligible (inactive, missing, or an admin without an app password).
   */
  promoteToProviderInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<boolean>;
}
