import 'reflect-metadata';

import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { Prisma, SharedMemberRole } from '@prisma/client';
import { AuthenticatedUser } from '../src/auth/authenticated-user.interface';
import { NotificationsService } from '../src/notifications/notifications.service';
import { PermissionService, PlanAccessContext } from '../src/sharing/permission.service';
import { rolePermissionDefaults } from '../src/sharing/plan-permissions';
import { SharingService } from '../src/sharing/sharing.service';

const permissions = new PermissionService({} as any);
const sharing = new SharingService(
  {} as any,
  permissions,
  {} as any,
  {} as any,
);

function memberContext(
  role: SharedMemberRole,
  overrides: Record<string, boolean> = {},
): PlanAccessContext {
  return {
    plan: { id: 'plan-1', ownerUserId: 'owner-1' } as any,
    isOwner: false,
    sharedMember: {
      role,
      ...rolePermissionDefaults(role),
      ...overrides,
    } as any,
  };
}

function assertCeiling(
  inviter: PlanAccessContext,
  targetRole: SharedMemberRole,
  targetOverrides: Record<string, boolean> = {},
) {
  (sharing as any).assertPermissionCeiling(inviter, targetRole, {
    ...rolePermissionDefaults(targetRole),
    ...targetOverrides,
  });
}

test('owner may delegate every non-owner role', () => {
  assert.doesNotThrow(() =>
    assertCeiling(
      {
        plan: { id: 'plan-1', ownerUserId: 'owner-1' } as any,
        isOwner: true,
        sharedMember: null,
      },
      SharedMemberRole.FINANCE_MANAGER,
    ),
  );
});

test('manager and helper cannot mint finance authority they do not own', () => {
  for (const role of [SharedMemberRole.MANAGER, SharedMemberRole.HELPER]) {
    assert.throws(
      () =>
        assertCeiling(
          memberContext(role, { canInviteMembers: true }),
          SharedMemberRole.FINANCE_MANAGER,
        ),
      /canViewMoney|canManageMoney/,
    );
  }
});

test('manager may delegate an editor role inside the manager ceiling', () => {
  assert.doesNotThrow(() =>
    assertCeiling(
      memberContext(SharedMemberRole.MANAGER, { canInviteMembers: true }),
      SharedMemberRole.EDITOR,
    ),
  );
});

test('explicit finance plus invite delegation may be passed on but not enlarged', () => {
  assert.doesNotThrow(() =>
    assertCeiling(
      memberContext(SharedMemberRole.FINANCE_MANAGER, {
        canInviteMembers: true,
      }),
      SharedMemberRole.FINANCE_MANAGER,
    ),
  );

  assert.throws(
    () =>
      assertCeiling(
        memberContext(SharedMemberRole.FINANCE_MANAGER, {
          canInviteMembers: true,
        }),
        SharedMemberRole.MANAGER,
      ),
    /canEditPlan|canManageTasks/,
  );
});

test('viewer with invite delegation can only create another viewer', () => {
  const inviter = memberContext(SharedMemberRole.VIEWER, {
    canInviteMembers: true,
  });
  assert.doesNotThrow(() => assertCeiling(inviter, SharedMemberRole.VIEWER));
  assert.throws(
    () => assertCeiling(inviter, SharedMemberRole.HELPER),
    /canManageTasks|canManageGuests|canManageProviders/,
  );
});

type StoredInvite = Record<string, any>;

class MemorySharingPrisma {
  readonly plan = {
    id: 'plan-1',
    ownerUserId: 'owner-1',
    title: 'خطة الاختبار',
    city: 'صنعاء',
    weddingDate: new Date('2026-12-01T00:00:00.000Z'),
    estimatedBudget: null,
    currency: 'YER',
    status: 'PLANNING',
    createdAt: new Date('2026-07-01T00:00:00.000Z'),
    updatedAt: new Date('2026-07-01T00:00:00.000Z'),
  };
  readonly users: Array<Record<string, any>>;
  invites: StoredInvite[] = [];
  transactionOptions: Array<Record<string, unknown>> = [];
  serializationFailuresRemaining = 0;
  private inviteSequence = 0;
  private transactionTail = Promise.resolve();

  constructor(users: Array<Record<string, any>>) {
    this.users = users;
  }

  user = {
    findUnique: async ({ where }: any) => {
      if (typeof where.id === 'string') {
        return this.users.find((user) => user.id === where.id) ?? null;
      }
      if (typeof where.phone === 'string') {
        return this.users.find((user) => user.phone === where.phone) ?? null;
      }
      return null;
    },
    findFirst: async ({ where }: any) => {
      if (where.phone?.in) {
        return (
          this.users.find((user) => where.phone.in.includes(user.phone)) ?? null
        );
      }
      if (where.email) {
        return (
          this.users.find((user) => user.email === where.email) ?? null
        );
      }
      return null;
    },
  };

  sharedMember = {
    findUnique: async () => null,
  };

  planInvite = {
    findMany: async ({ where }: any = {}) =>
      this.invites.filter((invite) => this.matchesListWhere(invite, where)),
    findUnique: async ({ where }: any) => this.findUniqueInvite(where),
    findFirst: async ({ where }: any) => this.findFirstInvite(where),
  };

  $transaction = async (
    operation: (tx: Record<string, any>) => Promise<any>,
    options: Record<string, unknown> = {},
  ) => {
    const previous = this.transactionTail;
    let release!: () => void;
    this.transactionTail = new Promise<void>((resolve) => {
      release = resolve;
    });
    await previous;

    this.transactionOptions.push(options);
    const snapshot = structuredClone(this.invites);
    try {
      if (this.serializationFailuresRemaining > 0) {
        this.serializationFailuresRemaining -= 1;
        throw new Prisma.PrismaClientKnownRequestError(
          'serialization conflict',
          {
            code: 'P2034',
            clientVersion: 'test',
          },
        );
      }
      return await operation({
        __transaction: true,
        sharedMember: this.sharedMember,
        planInvite: {
          findFirst: async ({ where }: any) => this.findFirstInvite(where),
          findUnique: async ({ where }: any) => this.findUniqueInvite(where),
          create: async ({ data }: any) => this.createInvite(data),
          updateMany: async ({ where, data }: any) =>
            this.updateInvites(where, data),
        },
      });
    } catch (error) {
      this.invites = snapshot;
      throw error;
    } finally {
      release();
    }
  };

  private findUniqueInvite(where: Record<string, unknown>) {
    if (typeof where.id === 'string') {
      return this.invites.find((invite) => invite.id === where.id) ?? null;
    }
    if (typeof where.tokenHash === 'string') {
      return (
        this.invites.find((invite) => invite.tokenHash === where.tokenHash) ??
        null
      );
    }
    return null;
  }

  private findFirstInvite(where: Record<string, any>) {
    if (where.id) {
      return (
        this.invites.find(
          (invite) =>
            invite.id === where.id &&
            (!where.weddingPlanId ||
              invite.weddingPlanId === where.weddingPlanId),
        ) ?? null
      );
    }
    return (
      this.invites.find((invite) => {
        if (invite.weddingPlanId !== where.weddingPlanId) return false;
        if (where.acceptedAt === null && invite.acceptedAt !== null) return false;
        if (where.declinedAt === null && invite.declinedAt !== null) return false;
        if (where.revokedAt === null && invite.revokedAt !== null) return false;
        if (
          where.expiresAt?.gt &&
          invite.expiresAt.getTime() <= where.expiresAt.gt.getTime()
        ) {
          return false;
        }
        return (where.OR ?? []).some((candidate: Record<string, unknown>) =>
          Object.entries(candidate).every(
            ([key, value]) => invite[key] === value,
          ),
        );
      }) ?? null
    );
  }

  private createInvite(data: Record<string, any>) {
    const now = new Date();
    const invitee =
      this.users.find((user) => user.id === data.inviteeUserId) ?? null;
    const inviter =
      this.users.find((user) => user.id === data.inviterUserId) ?? null;
    const invite = {
      ...data,
      id: `invite-${++this.inviteSequence}`,
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null,
      createdAt: now,
      updatedAt: now,
      weddingPlan: {
        id: this.plan.id,
        title: this.plan.title,
        city: this.plan.city,
        weddingDate: this.plan.weddingDate,
        status: this.plan.status,
      },
      inviter: inviter
        ? { id: inviter.id, name: inviter.name, phone: inviter.phone }
        : undefined,
      invitee: invitee
        ? { id: invitee.id, name: invitee.name, phone: invitee.phone }
        : null,
    };
    this.invites.push(invite);
    return invite;
  }

  private updateInvites(
    where: Record<string, any>,
    data: Record<string, unknown>,
  ) {
    const matching = this.invites.filter((invite) => {
      if (invite.id !== where.id) return false;
      if (invite.weddingPlanId !== where.weddingPlanId) return false;
      if (where.tokenHash && invite.tokenHash !== where.tokenHash) return false;
      if (where.acceptedAt === null && invite.acceptedAt !== null) return false;
      if (where.declinedAt === null && invite.declinedAt !== null) return false;
      if (where.revokedAt === null && invite.revokedAt !== null) return false;
      if (
        where.expiresAt?.gt &&
        invite.expiresAt.getTime() <= where.expiresAt.gt.getTime()
      ) {
        return false;
      }
      return true;
    });
    for (const invite of matching) {
      Object.assign(invite, data, { updatedAt: new Date() });
    }
    return { count: matching.length };
  }

  private matchesListWhere(invite: StoredInvite, where: Record<string, any>) {
    if (
      where.weddingPlanId &&
      invite.weddingPlanId !== where.weddingPlanId
    ) {
      return false;
    }
    if (where.inviterUserId && invite.inviterUserId !== where.inviterUserId) {
      return false;
    }
    if (where.OR) {
      return where.OR.some((candidate: Record<string, unknown>) =>
        Object.entries(candidate).every(
          ([key, value]) => invite[key] === value,
        ),
      );
    }
    return true;
  }
}

function sharingUser(
  id: string,
  phone: string,
  name = id,
): AuthenticatedUser {
  const now = new Date();
  return {
    id,
    name,
    phone,
    email: null,
    role: 'USER',
    adminRole: null,
    appRole: 'WEDDING_USER',
    status: 'ACTIVE',
    phoneVerifiedAt: now,
    lastLoginAt: now,
    avatarUrl: null,
    locale: 'ar',
    activeWeddingPlanId: 'plan-1',
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: now,
    createdAt: now,
    updatedAt: now,
  } as AuthenticatedUser;
}

function inviteHarness(options: { notificationFailure?: Error } = {}) {
  const owner = sharingUser('owner-1', '+967777000001', 'المالك');
  const target = sharingUser('target-1', '+967777000002', 'المشارك');
  const db = new MemorySharingPrisma([owner, target]);
  let currentAccess: PlanAccessContext = {
    plan: db.plan as any,
    isOwner: true,
    sharedMember: null,
  };
  let transactionalAccess = currentAccess;
  const permissionService = new PermissionService({} as any);
  (permissionService as any).assertMemberManageable = async () => currentAccess;
  (permissionService as any).assertMemberManageableInTransaction = async () => {
    if (!permissionService.canManageMembers(transactionalAccess)) {
      throw new Error('Wedding plan not found');
    }
    return transactionalAccess;
  };
  const notificationInputs: Array<Record<string, any>> = [];
  const notificationService = {
    createNotificationInTransaction: async (
      tx: Record<string, any>,
      input: Record<string, any>,
    ) => {
      assert.equal(tx.__transaction, true);
      if (options.notificationFailure) throw options.notificationFailure;
      notificationInputs.push(input);
      return { id: 'notification-1' };
    },
  } as unknown as NotificationsService;
  const service = new SharingService(
    db as any,
    permissionService,
    notificationService,
    { deliver: async () => ({ channel: 'WHATSAPP', status: 'SENT' }) } as any,
  );

  return {
    db,
    owner,
    target,
    service,
    notificationInputs,
    setAccess: (access: PlanAccessContext) => {
      currentAccess = access;
      transactionalAccess = access;
    },
    setTransactionalAccess: (access: PlanAccessContext) => {
      transactionalAccess = access;
    },
  };
}

test('invite creation returns one raw bearer while storage and lists expose no raw token', async () => {
  const harness = inviteHarness();

  const created = await harness.service.createInvite(
    harness.owner,
    'plan-1',
    { phone: harness.target.phone!, role: SharedMemberRole.VIEWER },
  );

  assert.match(created.token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(created.weddingPlan?.title, harness.db.plan.title);
  assert.equal(created.inviter?.id, harness.owner.id);
  assert.equal(created.invitee?.id, harness.target.id);
  assert.equal(harness.db.invites.length, 1);
  assert.equal(
    harness.db.invites[0].tokenHash,
    createHash('sha256').update(created.token).digest('hex'),
  );
  assert.equal(JSON.stringify(harness.db.invites[0]).includes(created.token), false);
  assert.equal(harness.notificationInputs.length, 1);

  const listed = await harness.service.findInvitesForPlan(
    harness.owner,
    'plan-1',
  );
  assert.equal(listed.length, 1);
  assert.equal(listed[0].token, listed[0].id);
  assert.notEqual(listed[0].token, created.token);
  assert.equal(
    harness.db.transactionOptions[0].isolationLevel,
    Prisma.TransactionIsolationLevel.Serializable,
  );
});

test('invite notification failure rolls back the invite and token fingerprint', async () => {
  const harness = inviteHarness({
    notificationFailure: new Error('outbox unavailable'),
  });

  await assert.rejects(
    () =>
      harness.service.createInvite(harness.owner, 'plan-1', {
        phone: harness.target.phone!,
      }),
    /outbox unavailable/,
  );
  assert.equal(harness.db.invites.length, 0);
});

test('invite creation fails closed when delegation is revoked before commit', async () => {
  const harness = inviteHarness();
  harness.setTransactionalAccess(
    memberContext(SharedMemberRole.VIEWER, { canInviteMembers: false }),
  );

  await assert.rejects(
    () =>
      harness.service.createInvite(harness.owner, 'plan-1', {
        phone: harness.target.phone!,
      }),
    /Wedding plan not found/,
  );
  assert.equal(harness.db.invites.length, 0);
  assert.equal(harness.notificationInputs.length, 0);
});

test('invite target lookup prefers the exact canonical phone identity', async () => {
  const harness = inviteHarness();
  const legacy = sharingUser('legacy-target', '777000099');
  const canonical = sharingUser('canonical-target', '+967777000099');
  harness.db.users.push(legacy, canonical);

  const created = await harness.service.createInvite(
    harness.owner,
    'plan-1',
    { phone: '777000099' },
  );

  assert.equal(created.invitee?.id, canonical.id);
  assert.notEqual(created.invitee?.id, legacy.id);
});

test('invite creation retries a serialization abort without duplicating its notification', async () => {
  const harness = inviteHarness();
  harness.db.serializationFailuresRemaining = 1;

  const created = await harness.service.createInvite(
    harness.owner,
    'plan-1',
    { phone: harness.target.phone! },
  );

  assert.match(created.token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(harness.db.invites.length, 1);
  assert.equal(harness.notificationInputs.length, 1);
  assert.equal(harness.db.transactionOptions.length, 2);
});

test('concurrent creates for the same target leave exactly one pending invite', async () => {
  const harness = inviteHarness();
  const create = () =>
    harness.service.createInvite(harness.owner, 'plan-1', {
      phone: '+967777000099',
    });

  const results = await Promise.allSettled([create(), create()]);
  assert.equal(
    results.filter((result) => result.status === 'fulfilled').length,
    1,
  );
  assert.equal(
    results.filter((result) => result.status === 'rejected').length,
    1,
  );
  assert.match(
    String(
      (results.find((result) => result.status === 'rejected') as PromiseRejectedResult)
        .reason?.message,
    ),
    /pending invitation already exists/,
  );
  assert.equal(harness.db.invites.length, 1);
  assert.equal(
    harness.db.transactionOptions.every(
      (options) =>
        options.isolationLevel ===
        Prisma.TransactionIsolationLevel.Serializable,
    ),
    true,
  );
});

test('reissuing a pending invite rotates the bearer atomically and invalidates the old token', async () => {
  const harness = inviteHarness();
  const participant = sharingUser(
    'future-participant',
    '+967777000099',
    'مشارك جديد',
  );
  const created = await harness.service.createInvite(
    harness.owner,
    'plan-1',
    { phone: participant.phone! },
  );

  const before = await harness.service.getInviteForCurrentUser(
    participant,
    created.token,
  );
  assert.equal(before.id, created.id);

  const reissued = await harness.service.reissueInvite(
    harness.owner,
    'plan-1',
    created.id,
  );
  assert.match(reissued.token, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(reissued.token, created.token);
  assert.equal(harness.db.invites.length, 1);
  await assert.rejects(
    () =>
      harness.service.getInviteForCurrentUser(participant, created.token),
    /Invite not found/,
  );
  const after = await harness.service.getInviteForCurrentUser(
    participant,
    reissued.token,
  );
  assert.equal(after.id, created.id);
  assert.equal(after.token, created.id);
});

test('cancelling an invite claims only the still-pending row', async () => {
  const harness = inviteHarness();
  const created = await harness.service.createInvite(
    harness.owner,
    'plan-1',
    { phone: '+967777000099' },
  );

  const cancelled = await harness.service.cancelInvite(
    harness.owner,
    'plan-1',
    created.id,
  );

  assert.equal(cancelled.status, 'CANCELLED');
  assert.ok(harness.db.invites[0].revokedAt instanceof Date);
  const finalTransactionOptions =
    harness.db.transactionOptions[harness.db.transactionOptions.length - 1];
  assert.equal(
    finalTransactionOptions?.isolationLevel,
    Prisma.TransactionIsolationLevel.Serializable,
  );
});

test('cancelling loses safely when acceptance wins between read and claim', async () => {
  const harness = inviteHarness();
  const created = await harness.service.createInvite(
    harness.owner,
    'plan-1',
    { phone: '+967777000099' },
  );
  const pending = harness.db.invites[0];

  (harness.db as any).$transaction = async (
    operation: (tx: Record<string, any>) => Promise<any>,
    options: Record<string, unknown>,
  ) => {
    harness.db.transactionOptions.push(options);
    return operation({
      __transaction: true,
      sharedMember: harness.db.sharedMember,
      planInvite: {
        findFirst: async () => pending,
        updateMany: async () => ({ count: 0 }),
        findUnique: async () => pending,
      },
    });
  };

  await assert.rejects(
    () =>
      harness.service.cancelInvite(
        harness.owner,
        'plan-1',
        created.id,
      ),
    /Invite is no longer pending/,
  );
  assert.equal(pending.revokedAt, null);
});

test('raw invite claims stay bound to the current token fingerprint', () => {
  const harness = inviteHarness();
  const rawToken = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';
  const invite = { id: 'invite-1' } as any;

  assert.deepEqual(
    (harness.service as any).inviteClaimTokenFilter(invite, rawToken),
    { tokenHash: createHash('sha256').update(rawToken).digest('hex') },
  );
  assert.deepEqual(
    (harness.service as any).inviteClaimTokenFilter(invite, invite.id),
    {},
  );
});

test('reissue rejects historical invitations and delegated authority above the inviter ceiling', async () => {
  for (const state of ['acceptedAt', 'declinedAt', 'revokedAt', 'expired']) {
    const harness = inviteHarness();
    const created = await harness.service.createInvite(
      harness.owner,
      'plan-1',
      { phone: '+967777000099' },
    );
    const invite = harness.db.invites[0];
    if (state === 'expired') {
      invite.expiresAt = new Date(Date.now() - 1);
    } else {
      invite[state] = new Date();
    }
    await assert.rejects(
      () =>
        harness.service.reissueInvite(
          harness.owner,
          'plan-1',
          created.id,
        ),
      /Invite is no longer pending/,
    );
  }

  const harness = inviteHarness();
  const created = await harness.service.createInvite(
    harness.owner,
    'plan-1',
    {
      phone: '+967777000099',
      role: SharedMemberRole.FINANCE_MANAGER,
    },
  );
  const delegatedUser = sharingUser(
    'delegate-1',
    '+967777000003',
    'المفوّض',
  );
  harness.setAccess({
    plan: harness.db.plan as any,
    isOwner: false,
    sharedMember: {
      id: 'member-delegate',
      weddingPlanId: 'plan-1',
      userId: delegatedUser.id,
      role: SharedMemberRole.VIEWER,
      ...rolePermissionDefaults(SharedMemberRole.VIEWER),
      canInviteMembers: true,
    } as any,
  });
  await assert.rejects(
    () =>
      harness.service.reissueInvite(
        delegatedUser,
        'plan-1',
        created.id,
      ),
    /Invite not found/,
  );

  harness.db.invites[0].inviterUserId = delegatedUser.id;
  await assert.rejects(
    () =>
      harness.service.reissueInvite(
        delegatedUser,
        'plan-1',
        created.id,
      ),
    /Cannot grant permission above inviter ceiling/,
  );
});

test('invite create and reissue source contract stays transactional and authenticated', () => {
  const serviceSource = readFileSync(
    join(process.cwd(), 'src/sharing/sharing.service.ts'),
    'utf8',
  );
  const controllerSource = readFileSync(
    join(process.cwd(), 'src/sharing/sharing.controller.ts'),
    'utf8',
  );
  const createBlock = serviceSource.slice(
    serviceSource.indexOf('async createInvite('),
    serviceSource.indexOf('async findInvitesForCurrentUser('),
  );
  const reissueBlock = serviceSource.slice(
    serviceSource.indexOf('async reissueInvite('),
    serviceSource.indexOf('async acceptInvite('),
  );

  assert.match(createBlock, /runSerializableTransaction/);
  assert.match(createBlock, /assertMemberManageableInTransaction/);
  assert.match(createBlock, /createNotificationInTransaction\(tx/);
  assert.doesNotMatch(createBlock, /createNotification\(/);
  assert.match(createBlock, /planInvite\.findFirst/);
  assert.match(createBlock, /planInvite\.create/);
  assert.match(reissueBlock, /runSerializableTransaction/);
  assert.match(reissueBlock, /assertMemberManageableInTransaction/);
  assert.match(reissueBlock, /tokenHash:\s*invite\.tokenHash/);
  assert.match(reissueBlock, /acceptedAt:\s*null/);
  assert.match(reissueBlock, /expiresAt:\s*\{\s*gt:\s*now/);
  assert.match(
    controllerSource,
    /@Post\(":inviteId\/reissue"\)[\s\S]*?reissueInvite\(/,
  );
  assert.match(
    controllerSource,
    /@Controller\("api\/v1\/wedding-plans\/:weddingPlanId\/invites"\)[\s\S]*?@UseGuards\(JwtAuthGuard\)/,
  );
});
