import { Prisma, UserRole, type User } from '@prisma/client';
import type { PrismaService } from '../../../platform/database/prisma.service';

type Client = PrismaService | Prisma.TransactionClient;

export class AuthUserRepository {
  findById(client: Client, id: string) {
    return client.user.findUnique({ where: { id } });
  }

  requireById(client: Client, id: string) {
    return client.user.findUniqueOrThrow({ where: { id } });
  }

  findByCanonicalPhone(client: Client, phone: string, variants: readonly string[]) {
    return client.user.findFirst({ where: { phone } }).then(
      (user) => user ?? client.user.findFirst({ where: { phone: { in: [...variants] } } }),
    );
  }

  claimAdminApplicationRegistration(tx: Prisma.TransactionClient, user: User, phone: string, name: string, passwordHash: string, now: Date) {
    return tx.user.updateMany({
      where: { id: user.id, role: UserRole.ADMIN, status: 'ACTIVE', appPasswordHash: null },
      data: {
        appPasswordHash: passwordHash, appAccountActivatedAt: now,
        appName: name, appEmail: null, appAvatarUrl: null, phone,
        phoneVerifiedAt: user.phoneVerifiedAt ?? now, lastLoginAt: now,
      },
    });
  }

  /**
   * Claims an unverified row for the phone that just proved its code. The
   * row's previous password was never proven, so it is replaced, or cleared
   * when the sign-up chose no password.
   */
  claimApplicationRegistration(tx: Prisma.TransactionClient, userId: string, phone: string, name: string, passwordHash: string | null, now: Date) {
    return tx.user.updateMany({
      where: {
        id: userId, role: { in: [UserRole.USER, UserRole.PROVIDER] },
        status: 'ACTIVE', phoneVerifiedAt: null,
      },
      data: {
        name, phone, passwordHash, appAccountActivatedAt: now,
        phoneVerifiedAt: now, lastLoginAt: now,
      },
    });
  }

  createApplicationUser(tx: Prisma.TransactionClient, name: string, phone: string, passwordHash: string | null, now: Date) {
    return tx.user.create({
      data: {
        name, phone, email: null, passwordHash,
        appAccountActivatedAt: now, phoneVerifiedAt: now, lastLoginAt: now,
      },
    });
  }

  async markSuccessfulLogin(tx: Prisma.TransactionClient, user: User, at: Date) {
    const credentialHash = user.role === UserRole.ADMIN ? user.appPasswordHash : user.passwordHash;
    // A password sign-in is only ever pinned to a hash that exists; a
    // passwordless account must never match a `hash IS NULL` filter.
    if (credentialHash === null) return { count: 0 };
    const credentialIdentity = user.role === UserRole.ADMIN
      ? { appPasswordHash: credentialHash }
      : { passwordHash: credentialHash };
    return tx.user.updateMany({
      where: {
        id: user.id, phone: user.phone, role: user.role, status: 'ACTIVE',
        phoneVerifiedAt: { not: null }, appAccountActivatedAt: { not: null },
        ...credentialIdentity,
      },
      data: { lastLoginAt: at },
    });
  }

  /**
   * V1 checklist 4.14: the account moves to a phone it just proved by OTP.
   * RA-BE-19: never an administrator's, whose phone is the admin account's
   * second factor and recovery.
   */
  changePhone(tx: Prisma.TransactionClient, userId: string, phone: string, at: Date) {
    return tx.user.updateMany({
      where: { id: userId, status: 'ACTIVE', role: { not: UserRole.ADMIN } },
      data: { phone, phoneVerifiedAt: at },
    });
  }

  markAdminMfaLogin(tx: Prisma.TransactionClient, user: User, at: Date) {
    return tx.user.updateMany({
      where: { id: user.id, role: UserRole.ADMIN, status: 'ACTIVE' },
      data: { lastLoginAt: at, phoneVerifiedAt: user.phoneVerifiedAt ?? at },
    });
  }

  upgradeAdminPasswordHash(client: Client, userId: string, oldHash: string, newHash: string) {
    return client.user.updateMany({
      where: { id: userId, passwordHash: oldHash, role: UserRole.ADMIN, status: 'ACTIVE' },
      data: { passwordHash: newHash },
    });
  }

  markPhoneVerified(tx: Prisma.TransactionClient, user: User, purposeIsLogin: boolean, now: Date) {
    return tx.user.update({
      where: { id: user.id },
      data: {
        phoneVerifiedAt: user.phoneVerifiedAt ?? now,
        ...(purposeIsLogin ? { lastLoginAt: now } : {}),
      },
    });
  }

  claimInviteAdminApplication(tx: Prisma.TransactionClient, user: User, name: string, phone: string, passwordHash: string, now: Date) {
    return tx.user.updateMany({
      where: {
        id: user.id, role: UserRole.ADMIN, status: 'ACTIVE', appAccountActivatedAt: null,
      },
      data: {
        appPasswordHash: passwordHash, appAccountActivatedAt: now,
        appName: name, appEmail: null, appAvatarUrl: null, phone,
        phoneVerifiedAt: user.phoneVerifiedAt ?? now, lastLoginAt: now,
      },
    });
  }

  completeInviteAccountSetup(tx: Prisma.TransactionClient, userId: string, name: string, phone: string, passwordHash: string | null, now: Date) {
    return tx.user.update({
      where: { id: userId },
      data: {
        name, phone, passwordHash, appAccountActivatedAt: now,
        phoneVerifiedAt: now, lastLoginAt: now,
      },
    });
  }

  touchLastLogin(tx: Prisma.TransactionClient, userId: string, now: Date) {
    return tx.user.update({ where: { id: userId }, data: { lastLoginAt: now } });
  }

  resetApplicationPassword(tx: Prisma.TransactionClient, user: User, passwordHash: string, now: Date) {
    return tx.user.update({
      where: { id: user.id },
      data: {
        ...(user.role === UserRole.ADMIN
          ? { appPasswordHash: passwordHash }
          : { passwordHash }),
        appAccountActivatedAt: user.appAccountActivatedAt ?? now,
        phoneVerifiedAt: user.phoneVerifiedAt ?? now,
      },
    });
  }

  /**
   * `POST /auth/password`: the signed-in account's app password (an
   * administrator's `appPasswordHash`), pinned to the hash the caller just
   * checked (null when the account had none) so a concurrent change wins once.
   */
  setApplicationPassword(tx: Prisma.TransactionClient, user: User, expectedHash: string | null, passwordHash: string) {
    const live = {
      id: user.id, role: user.role, status: 'ACTIVE' as const,
      appAccountActivatedAt: { not: null },
    };
    if (user.role === UserRole.ADMIN) {
      return tx.user.updateMany({
        where: { ...live, appPasswordHash: expectedHash },
        data: { appPasswordHash: passwordHash },
      });
    }
    return tx.user.updateMany({
      where: { ...live, passwordHash: expectedHash },
      data: { passwordHash },
    });
  }

  resetAdministratorPassword(tx: Prisma.TransactionClient, userId: string, passwordHash: string) {
    return tx.user.updateMany({
      where: { id: userId, role: UserRole.ADMIN, status: 'ACTIVE' },
      data: { passwordHash },
    });
  }
}
