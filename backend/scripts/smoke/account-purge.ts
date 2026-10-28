// D63: the HTTP smokes ask for an account's deletion through the API; the
// hourly purge is not an HTTP route, so this runs it in the smoke's own
// process, on the isolated database: every pending account's 30 days are
// moved into the past and the purge erases them through the one saga.
import { PrismaClient } from '@prisma/client';
import { MediaStorageService } from '../../src/media/media-storage.service';
import { MediaUploadTicketService } from '../../src/modules/media/infrastructure/media-upload-ticket.service';
import { PermissionService } from '../../src/modules/collaboration/internal/permission.service';
import { UsersService } from '../../src/modules/identity/internal/profile/users.service';
import { accountDeletionService, identityErasurePorts, ownerPorts } from './support/owner-ports';

const { assertManagedSmokeEnvironment } = require('./smoke-utils.js') as {
  assertManagedSmokeEnvironment: (environment?: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);

const DAY_MS = 24 * 60 * 60 * 1000;

export async function purgePendingAccounts(): Promise<{
  erased: number;
  failures: string[];
}> {
  const prisma = new PrismaClient();
  try {
    const now = Date.now();
    await prisma.user.updateMany({
      where: { deletionScheduledFor: { not: null } },
      data: {
        deletionRequestedAt: new Date(now - 31 * DAY_MS),
        deletionScheduledFor: new Date(now - 60_000),
      },
    });
    const media = new MediaStorageService(new MediaUploadTicketService(prisma as never));
    const users = new UsersService(
      prisma as never,
      new PermissionService(prisma as never, ownerPorts.plans),
      media,
      ...identityErasurePorts,
    );
    const summary = await accountDeletionService(prisma, users).purgeDueAccounts(
      new Date(),
    );
    return {
      erased: summary.erased,
      failures: summary.failures.map((failure) => `${failure.userId}:${failure.code}`),
    };
  } finally {
    await prisma.$disconnect();
  }
}
