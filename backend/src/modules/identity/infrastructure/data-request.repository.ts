import { Prisma } from '@prisma/client';

// D63: the account rows behind w05's impact and the admin's n06 «طلبات
// البيانات», and the one-time downloads of an account's own data (w40).

/** The names of these accounts, by id. */
export async function findDataRequestAccounts(
  client: Prisma.TransactionClient,
  userIds: readonly string[],
): Promise<Map<string, { name: string }>> {
  const ids = [...new Set(userIds)];
  if (ids.length === 0) return new Map();
  const rows = await client.user.findMany({
    where: { id: { in: ids } },
    select: { id: true, name: true },
  });
  return new Map(rows.map((row) => [row.id, { name: row.name }]));
}

/** Every account waiting out its deletion, soonest erasure first. */
export function listPendingAccountDeletions(client: Prisma.TransactionClient) {
  return client.user.findMany({
    where: { deletionScheduledFor: { not: null } },
    orderBy: [{ deletionScheduledFor: 'asc' }, { id: 'asc' }],
    select: {
      id: true,
      name: true,
      phone: true,
      deletionRequestedAt: true,
      deletionScheduledFor: true,
      deletionPurgeFailedAt: true,
      deletionPurgeFailure: true,
    },
  });
}

/** The downloads asked since `since`, newest first. */
export function listRecentDataExports(
  client: Prisma.TransactionClient,
  since: Date,
) {
  return client.dataExport.findMany({
    where: { createdAt: { gte: since } },
    orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
    select: {
      id: true,
      userId: true,
      createdAt: true,
      expiresAt: true,
      downloadedAt: true,
      user: { select: { name: true, phone: true } },
    },
  });
}

export function countDataExportsSince(
  client: Prisma.TransactionClient,
  userId: string,
  since: Date,
) {
  return client.dataExport.count({ where: { userId, createdAt: { gte: since } } });
}

export function createDataExport(
  client: Prisma.TransactionClient,
  data: { userId: string; tokenHash: string; createdAt: Date; expiresAt: Date },
) {
  return client.dataExport.create({ data, select: { id: true } });
}

/**
 * Takes the one download of a live link: marks it downloaded only when it was
 * not yet and has not expired, so two clicks cannot both read the file.
 */
export async function claimDataExport(
  client: Prisma.TransactionClient,
  tokenHash: string,
  now: Date,
): Promise<{ id: string; userId: string } | null> {
  const row = await client.dataExport.findUnique({
    where: { tokenHash },
    select: { id: true, userId: true },
  });
  if (!row) return null;
  const claimed = await client.dataExport.updateMany({
    where: { id: row.id, downloadedAt: null, expiresAt: { gt: now } },
    data: { downloadedAt: now },
  });
  return claimed.count === 1 ? row : null;
}

/** The downloads older than `before` leave the table (n06 lists a week). */
export function deleteDataExportsBefore(
  client: Prisma.TransactionClient,
  before: Date,
) {
  return client.dataExport.deleteMany({ where: { createdAt: { lt: before } } });
}

/** The account's own profile, for its download. */
export function findExportProfile(client: Prisma.TransactionClient, userId: string) {
  return client.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      name: true,
      phone: true,
      email: true,
      persona: true,
      locale: true,
      reviewFirstNameOnly: true,
      createdAt: true,
      deletionRequestedAt: true,
      deletionScheduledFor: true,
    },
  });
}

/** D63 (w40): the account's privacy choices kept on the server. */
export function findPrivacySettings(client: Prisma.TransactionClient, userId: string) {
  return client.user.findUnique({
    where: { id: userId },
    select: { reviewFirstNameOnly: true },
  });
}

export function updatePrivacySettings(
  client: Prisma.TransactionClient,
  userId: string,
  data: { reviewFirstNameOnly: boolean },
) {
  return client.user.update({
    where: { id: userId },
    data,
    select: { reviewFirstNameOnly: true },
  });
}
