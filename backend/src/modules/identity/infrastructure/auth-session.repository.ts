import { UnauthorizedException } from '@nestjs/common';
import { AuthSessionScope, Prisma } from '@prisma/client';
import type { PrismaService } from '../../../platform/database/prisma.service';
import {
  enqueueSessionRevoked, enqueueUserSessionsRevoked,
} from '../../../platform/outbox/realtime-revocation';

type Client = PrismaService | Prisma.TransactionClient;

export interface LockedRefreshTokenRow {
  id: string;
  userId: string;
  scope: AuthSessionScope;
  expiresAt: Date;
  revokedAt: Date | null;
  replacedById: string | null;
}

export interface LockedRefreshTokenFamily {
  rows: LockedRefreshTokenRow[];
  complete: boolean;
}

interface LockedRefreshTokenTraversalRow extends LockedRefreshTokenRow {
  depth: number;
}

export class AuthSessionRepository {
  private static readonly maxRefreshFamilyDepth = 4_096;

  findSeed(tx: Prisma.TransactionClient, tokenHash: string) {
    return tx.refreshToken.findUnique({
      where: { tokenHash }, select: { id: true, userId: true, scope: true },
    });
  }

  findWithUser(tx: Prisma.TransactionClient, id: string) {
    return tx.refreshToken.findUnique({
      where: { id }, include: { user: true },
    });
  }

  create(client: Client, userId: string, tokenHash: string,
    scope: AuthSessionScope, expiresAt: Date,
  ) {
    return client.refreshToken.create({
      data: { userId, tokenHash, scope, expiresAt },
    });
  }

  async rotate(tx: Prisma.TransactionClient, input: {
    id: string; userId: string; tokenHash: string;
    scope: AuthSessionScope; now: Date; expiresAt: Date;
  }): Promise<string> {
    const replacement = await this.create(
      tx, input.userId, input.tokenHash, input.scope, input.expiresAt,
    );
    const revoked = await tx.refreshToken.updateMany({
      where: { id: input.id, revokedAt: null, expiresAt: { gt: input.now } },
      data: { revokedAt: input.now },
    });
    if (revoked.count !== 1) {
      throw new UnauthorizedException('Session is invalid or expired');
    }
    await tx.refreshToken.update({
      where: { id: input.id }, data: { replacedById: replacement.id },
    });
    if (input.scope === AuthSessionScope.APPLICATION) {
      await enqueueSessionRevoked(tx, input.id);
    }
    return replacement.id;
  }

  async lockFamily(tx: Prisma.TransactionClient, startId: string,
    expectedUserId: string, expectedScope: AuthSessionScope,
  ): Promise<LockedRefreshTokenFamily> {
    const traversed = await tx.$queryRaw<LockedRefreshTokenTraversalRow[]>(
      Prisma.sql`
        WITH RECURSIVE "RefreshFamily" AS (
          SELECT token."id", token."userId", token."scope", token."expiresAt",
            token."revokedAt", token."replacedById", 1 AS "depth"
          FROM "RefreshToken" AS token
          WHERE token."id" = ${startId}
          UNION ALL
          SELECT replacement."id", replacement."userId", replacement."scope",
            replacement."expiresAt", replacement."revokedAt", replacement."replacedById",
            family."depth" + 1
          FROM "RefreshFamily" AS family
          JOIN "RefreshToken" AS replacement ON replacement."id" = family."replacedById"
          WHERE family."depth" <= ${AuthSessionRepository.maxRefreshFamilyDepth}
        )
        SELECT family."id", family."userId", family."scope", family."expiresAt",
          family."revokedAt", family."replacedById", family."depth"
        FROM "RefreshFamily" AS family
        JOIN "RefreshToken" AS locked_token ON locked_token."id" = family."id"
        ORDER BY family."depth" ASC
        FOR UPDATE OF locked_token
      `,
    );
    const family: LockedRefreshTokenRow[] = [];
    const visited = new Set<string>();
    let expectedId: string | null = startId;
    for (const current of traversed) {
      if (
        current.depth !== family.length + 1 || current.id !== expectedId ||
        current.userId !== expectedUserId || current.scope !== expectedScope ||
        visited.has(current.id) ||
        family.length >= AuthSessionRepository.maxRefreshFamilyDepth
      ) return { rows: family, complete: false };
      visited.add(current.id);
      family.push(current);
      expectedId = current.replacedById;
    }
    return {
      rows: family,
      complete: family.length > 0 && expectedId === null &&
        family.length <= AuthSessionRepository.maxRefreshFamilyDepth,
    };
  }

  async lockActiveScope(tx: Prisma.TransactionClient, userId: string,
    scope: AuthSessionScope,
  ): Promise<void> {
    await tx.$queryRaw(Prisma.sql`
      SELECT "id" FROM "RefreshToken"
      WHERE "userId" = ${userId}
        AND "scope" = ${scope}::"AuthSessionScope"
        AND "revokedAt" IS NULL
      ORDER BY "id" ASC FOR UPDATE
    `);
  }

  async revokeScope(tx: Prisma.TransactionClient, userId: string,
    scope: AuthSessionScope, now: Date,
  ): Promise<number> {
    await this.lockActiveScope(tx, userId, scope);
    const revoked = await tx.refreshToken.updateMany({
      where: { userId, scope, revokedAt: null }, data: { revokedAt: now },
    });
    if (revoked.count > 0 && scope === AuthSessionScope.APPLICATION) {
      await enqueueUserSessionsRevoked(tx, userId);
    }
    return revoked.count;
  }

  async revokeFamily(tx: Prisma.TransactionClient,
    sessions: readonly LockedRefreshTokenRow[], now: Date,
    publishApplicationRevocations = false,
  ): Promise<string[]> {
    const revokedSessionIds: string[] = [];
    for (const session of sessions) {
      if (session.revokedAt) continue;
      const revoked = await tx.refreshToken.updateMany({
        where: {
          id: session.id, userId: session.userId,
          scope: session.scope, revokedAt: null,
        },
        data: { revokedAt: now },
      });
      if (revoked.count !== 1) continue;
      revokedSessionIds.push(session.id);
      if (publishApplicationRevocations) {
        await enqueueSessionRevoked(tx, session.id);
      }
    }
    return revokedSessionIds;
  }

  /**
   * Revokes every live session of the scope except `keepSessionId` (the
   * caller's own), publishing each application revocation. Returns the ids.
   */
  async revokeOtherActiveSessions(tx: Prisma.TransactionClient, userId: string,
    scope: AuthSessionScope, keepSessionId: string, now: Date,
  ): Promise<string[]> {
    await this.lockActiveScope(tx, userId, scope);
    const others = await tx.refreshToken.findMany({
      where: { userId, scope, revokedAt: null, id: { not: keepSessionId } },
      select: {
        id: true, userId: true, scope: true, expiresAt: true,
        revokedAt: true, replacedById: true,
      },
      orderBy: { id: 'asc' },
    });
    return this.revokeFamily(tx, others, now, scope === AuthSessionScope.APPLICATION);
  }

  revokeActiveScope(tx: Prisma.TransactionClient, userId: string,
    scope: AuthSessionScope, now: Date,
  ) {
    return tx.refreshToken.updateMany({
      where: { userId, scope, revokedAt: null }, data: { revokedAt: now },
    });
  }

  clearLoginThrottle(tx: Prisma.TransactionClient, subjectHash: string) {
    return tx.loginThrottle.deleteMany({ where: { subjectHash } });
  }
}
