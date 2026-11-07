import { Injectable } from '@nestjs/common';
import {
  AdminRole,
  AuthSessionScope,
  Prisma,
  UserRole,
  UserStatus,
} from '@prisma/client';
import type {
  AccountSearchField,
  AdminAccountCounts,
  AdminAccountLock,
  AdminAccountPage,
  AdminAccountRow,
  AdminAssistantAnswerReportPage,
  AdminAssistantAnswerReportRow,
  CreatedAtRange,
  IdentityAdminPort,
} from '../public/identity-admin.port';
import {
  ARABIC_FOLD_FROM,
  ARABIC_FOLD_TO,
  arabicSearchKey,
} from '../../../shared-kernel/text/arabic-search';

const adminAccountSelect = {
  id: true,
  name: true,
  phone: true,
  email: true,
  role: true,
  status: true,
  avatarUrl: true,
  createdAt: true,
  updatedAt: true,
} as const;

interface TextMatch {
  contains: string;
  mode: 'insensitive';
}

@Injectable()
export class IdentityAdminService implements IdentityAdminPort {
  async lockAccountsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<AdminAccountLock[]> {
    const orderedIds = [...new Set(userIds)].sort();
    if (orderedIds.length === 0) return [];
    return tx.$queryRaw<AdminAccountLock[]>(
      Prisma.sql`
        SELECT "id", "role", "adminRole", "status"
        FROM "User"
        WHERE "id" IN (${Prisma.join(orderedIds)})
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
  }

  async countActiveSuperAdminsInTransaction(
    tx: Prisma.TransactionClient,
  ): Promise<number> {
    return tx.user.count({
      where: {
        role: UserRole.ADMIN,
        adminRole: AdminRole.SUPER_ADMIN,
        status: UserStatus.ACTIVE,
      },
    });
  }

  async setAccountStatusInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    status: UserStatus,
  ): Promise<AdminAccountRow> {
    return tx.user.update({
      where: { id: userId },
      data: { status },
      select: adminAccountSelect,
    });
  }

  async revokeRefreshTokensInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    revokedAt: Date,
  ): Promise<void> {
    await tx.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt },
    });
  }

  async listAccounts(
    client: Prisma.TransactionClient,
    search: string | null,
    page: { skip: number; take: number },
  ): Promise<AdminAccountPage> {
    const where = search
      ? {
          OR: [
            { id: { in: await namedAccountIds(client, search) } },
            { phone: textMatch(search) },
            { email: textMatch(search) },
          ],
        }
      : {};
    const total = await client.user.count({ where });
    const items = await client.user.findMany({
      where,
      select: adminAccountSelect,
      orderBy: { createdAt: 'desc' },
      skip: page.skip,
      take: page.take,
    });
    return { total, items };
  }

  async getAccount(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<AdminAccountRow | null> {
    return client.user.findUnique({
      where: { id: userId },
      select: adminAccountSelect,
    });
  }

  async getAccounts(
    client: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<AdminAccountRow[]> {
    if (userIds.length === 0) return [];
    return client.user.findMany({
      where: { id: { in: [...userIds] } },
      select: adminAccountSelect,
    });
  }

  async searchAccountIds(
    client: Prisma.TransactionClient,
    search: string,
    fields: readonly AccountSearchField[],
  ): Promise<string[]> {
    if (fields.length === 0) return [];
    const named = fields.includes('name')
      ? await namedAccountIds(client, search)
      : [];
    if (!fields.includes('phone')) return named;
    const rows = await client.user.findMany({
      where: { OR: [{ id: { in: named } }, { phone: textMatch(search) }] },
      select: { id: true },
    });
    return rows.map((row) => row.id);
  }

  async countAccounts(client: Prisma.TransactionClient): Promise<number> {
    return client.user.count();
  }

  async countActiveAccountsSince(
    client: Prisma.TransactionClient,
    since: Date,
  ): Promise<number> {
    // A session is issued at sign-in and re-issued on every renewal, so a
    // fresh application session means the account used the app.
    const accounts = await client.refreshToken.groupBy({
      by: ['userId'],
      where: { scope: AuthSessionScope.APPLICATION, createdAt: { gte: since } },
    });
    return accounts.length;
  }

  async getAccountCounts(
    client: Prisma.TransactionClient,
    createdAt?: CreatedAtRange,
  ): Promise<AdminAccountCounts> {
    const [total, active, disabled, admins, providers] = await Promise.all([
      client.user.count({ where: { createdAt } }),
      client.user.count({ where: { createdAt, status: UserStatus.ACTIVE } }),
      client.user.count({ where: { createdAt, status: UserStatus.DISABLED } }),
      client.user.count({ where: { createdAt, role: UserRole.ADMIN } }),
      client.user.count({ where: { createdAt, role: UserRole.PROVIDER } }),
    ]);
    return { total, active, disabled, admins, providers };
  }

  async listAssistantAnswerReports(
    client: Prisma.TransactionClient,
    resolved: boolean,
    page: { skip: number; take: number },
  ): Promise<AdminAssistantAnswerReportPage> {
    const where = { resolvedAt: resolved ? { not: null } : null };
    const total = await client.assistantAnswerReport.count({ where });
    const items = await client.assistantAnswerReport.findMany({
      where,
      select: assistantAnswerReportSelect,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      skip: page.skip,
      take: page.take,
    });
    return { total, items };
  }

  async resolveAssistantAnswerReportInTransaction(
    tx: Prisma.TransactionClient,
    id: string,
    resolvedAt: Date,
  ): Promise<AdminAssistantAnswerReportRow | null> {
    // Conditional: two moderators at once resolve it once.
    const marked = await tx.assistantAnswerReport.updateMany({
      where: { id, resolvedAt: null },
      data: { resolvedAt },
    });
    if (marked.count !== 1) return null;
    return tx.assistantAnswerReport.findUnique({
      where: { id },
      select: assistantAnswerReportSelect,
    });
  }
}

/** RA-ST-04: the report as the team reads it; the reporter stays unnamed. */
const assistantAnswerReportSelect = {
  id: true,
  kind: true,
  question: true,
  answer: true,
  reason: true,
  resolvedAt: true,
  createdAt: true,
} as const;

/** RA-BE-09: the accounts whose name holds the search folded as the phone folds it. */
async function namedAccountIds(
  client: Prisma.TransactionClient,
  search: string,
): Promise<string[]> {
  const key = arabicSearchKey(search);
  if (key.length === 0) return [];
  const rows = await client.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT u."id" FROM "User" u
    WHERE strpos(translate(lower(u."name"), ${ARABIC_FOLD_FROM}, ${ARABIC_FOLD_TO}), ${key}) > 0`);
  return rows.map((row) => row.id);
}

function textMatch(search: string): TextMatch {
  return { contains: search, mode: 'insensitive' };
}
