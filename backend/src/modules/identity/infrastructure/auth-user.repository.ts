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
        appPasswordHash: passwordHash, appPasswordConfiguredAt: now,
        appName: name, appEmail: null, appAvatarUrl: null, phone,
        phoneVerifiedAt: user.phoneVerifiedAt ?? now, lastLoginAt: now,
      },
    });
  }

  claimApplicationRegistration(tx: Prisma.TransactionClient, userId: string, phone: string, name: string, passwordHash: string, now: Date) {
    return tx.user.updateMany({
      where: {
        id: userId, role: { in: [UserRole.USER, UserRole.PROVIDER] },
        status: 'ACTIVE', phoneVerifiedAt: null,
      },
      data: {
        name, phone, passwordHash, appPasswordConfiguredAt: now,
        phoneVerifiedAt: now, lastLoginAt: now,
      },
    });
  }

  createApplicationUser(tx: Prisma.TransactionClient, name: string, phone: string, passwordHash: string, now: Date) {
    return tx.user.create({
      data: {
        name, phone, email: null, passwordHash,
        appPasswordConfiguredAt: now, phoneVerifiedAt: now, lastLoginAt: now,
      },
    });
  }

  markSuccessfulLogin(tx: Prisma.TransactionClient, user: User, at: Date) {
    const credentialIdentity = user.role === UserRole.ADMIN
      ? { appPasswordHash: user.appPasswordHash! }
      : { passwordHash: user.passwordHash! };
    return tx.user.updateMany({
      where: {
        id: user.id, phone: user.phone, role: user.role, status: 'ACTIVE',
        phoneVerifiedAt: { not: null }, appPasswordConfiguredAt: { not: null },
        ...credentialIdentity,
      },
      data: { lastLoginAt: at },
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
        id: user.id, role: UserRole.ADMIN, status: 'ACTIVE', appPasswordConfiguredAt: null,
      },
      data: {
        appPasswordHash: passwordHash, appPasswordConfiguredAt: now,
        appName: name, appEmail: null, appAvatarUrl: null, phone,
        phoneVerifiedAt: user.phoneVerifiedAt ?? now, lastLoginAt: now,
      },
    });
  }

  completeInviteAccountSetup(tx: Prisma.TransactionClient, userId: string, name: string, phone: string, passwordHash: string, now: Date) {
    return tx.user.update({
      where: { id: userId },
      data: {
        name, phone, passwordHash, appPasswordConfiguredAt: now,
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
          ? { appPasswordHash: passwordHash, appPasswordConfiguredAt: now }
          : { passwordHash, appPasswordConfiguredAt: now }),
        phoneVerifiedAt: user.phoneVerifiedAt ?? now,
      },
    });
  }

  resetAdministratorPassword(tx: Prisma.TransactionClient, userId: string, passwordHash: string) {
    return tx.user.updateMany({
      where: { id: userId, role: UserRole.ADMIN, status: 'ACTIVE' },
      data: { passwordHash },
    });
  }
}
