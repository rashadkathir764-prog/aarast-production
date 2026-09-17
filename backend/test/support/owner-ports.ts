// Real owner port implementations for fixture-based unit tests. Each one runs
// the same Prisma delegate calls the service under test used to run itself,
// against whatever fake client the test passes in, so a fixture that stubbed
// `tx.budgetCategory.createMany` keeps working after the call moved to the
// owner (the R4 precedent for supplying a new owner collaborator).
import { ContributionHistoryService } from '../../src/modules/collaboration/internal/contribution-history.service';
import { PermissionService } from '../../src/modules/collaboration/internal/permission.service';
import { FinancePortService } from '../../src/modules/finance/internal/finance-port.service';
import { GuestsPortService } from '../../src/modules/guests/internal/guests-port.service';
import { IdentityUserPortService } from '../../src/modules/identity/internal/identity-user-port.service';
import { ProviderReadService } from '../../src/modules/marketplace/internal/provider-read.service';
import { QuoteReadService } from '../../src/modules/marketplace/internal/quote-read.service';
import { PlanReadService } from '../../src/modules/planning/internal/plan-read.service';
import { TasksPortService } from '../../src/modules/tasks/internal/tasks-port.service';

export const ownerPorts = {
  plans: new PlanReadService(),
  users: new IdentityUserPortService(),
  finance: new FinancePortService(),
  tasks: new TasksPortService(),
  guests: new GuestsPortService(),
  providers: new ProviderReadService(),
  quotes: new QuoteReadService(),
};

const realPermissions = new PermissionService({} as any, ownerPorts.plans);
const realHistory = new ContributionHistoryService({} as any, ownerPorts.plans, realPermissions);

/**
 * A collaboration permission fake completed with the owner-side methods a
 * planning service calls on the port (`listMemberPlanIds`,
 * `revokeLivePlanInvitesInTransaction`); the fake's own methods win.
 */
export function collaborationPermissions<T extends object>(fake: T) {
  return {
    listMemberPlanIds: realPermissions.listMemberPlanIds.bind(realPermissions),
    revokeLivePlanInvitesInTransaction:
      realPermissions.revokeLivePlanInvitesInTransaction.bind(realPermissions),
    ...fake,
  };
}

/** A collaboration history fake completed with the history-scope methods planning calls. */
export function collaborationHistory<T extends object>(fake: T) {
  return {
    createHistoryScopeInTransaction:
      realHistory.createHistoryScopeInTransaction.bind(realHistory),
    archiveHistoryScopeInTransaction:
      realHistory.archiveHistoryScopeInTransaction.bind(realHistory),
    ...fake,
  };
}

/** The five owner ports `WeddingPlansService` takes after the collaboration ports. */
export const planningOwnerPorts = [
  ownerPorts.users,
  ownerPorts.users,
  ownerPorts.finance,
  ownerPorts.tasks,
  ownerPorts.guests,
] as const;

// ---------------------------------------------------------------------------
// Identity services. `UsersService` and `AuthService` take the owner ports the
// account-deletion saga, the invite-OTP flow and the settings endpoints call;
// these constructors keep every fixture's original argument list and add the
// real owner implementations (each runs the same statements against the
// fixture's fake client).
import { AuthService } from '../../src/modules/identity/internal/auth/auth.service';
import { UsersService } from '../../src/modules/identity/internal/profile/users.service';
import { MessagingErasureService } from '../../src/modules/messaging/internal/messaging-erasure.service';
import { MarketplaceErasureService } from '../../src/modules/marketplace/internal/marketplace-erasure.service';
import { NotificationsErasureService } from '../../src/modules/notifications/internal/notifications-erasure.service';
import { CollaborationErasureService } from '../../src/modules/collaboration/internal/collaboration-erasure.service';
import { PlanErasureService } from '../../src/modules/planning/internal/plan-erasure.service';
import { MediaStorageService } from '../../src/media/media-storage.service';
import { MediaUploadTicketService } from '../../src/media/media-upload-ticket.service';

const realMediaStorage = new MediaStorageService(new MediaUploadTicketService({} as any));

/** A media storage fake completed with the chat-attachment deletion step the saga calls. */
export function mediaStorageWithOwners<T extends object>(fake: T) {
  return {
    scheduleChatAttachmentDeletion: (attachmentIds: readonly string[], transaction: unknown) =>
      realMediaStorage.scheduleChatAttachmentDeletion(attachmentIds, transaction as any),
    ...fake,
  };
}

export const identityErasurePorts = [
  new PlanErasureService(),
  new MarketplaceErasureService(),
  new MessagingErasureService(),
  new NotificationsErasureService(),
  new CollaborationErasureService(),
  ownerPorts.finance,
  ownerPorts.tasks,
  ownerPorts.guests,
] as const;

type UsersServiceOptional = [realtime?: unknown, firebasePush?: unknown];

export function usersService(
  prisma: unknown,
  permissions: unknown,
  mediaStorage: object,
  ...optional: UsersServiceOptional
): UsersService {
  return new UsersService(
    prisma as any,
    permissions as any,
    mediaStorageWithOwners(mediaStorage) as any,
    ...identityErasurePorts,
    optional[0] as any,
    optional[1] as any,
  );
}

export function authService(
  prisma: unknown,
  jwtService: unknown,
  loginThrottle: unknown,
  otpDispatchQuota: unknown,
  realtime: unknown,
): AuthService {
  return new AuthService(
    prisma as any,
    jwtService as any,
    loginThrottle as any,
    otpDispatchQuota as any,
    realtime as any,
    realPermissions,
  );
}

// ---------------------------------------------------------------------------
// Collaboration services: the same rule — the fixture's argument list stays,
// the real owner ports are appended.
import { InviteAccessService } from '../../src/modules/collaboration/internal/invite-access.service';
import { SharingService } from '../../src/modules/collaboration/internal/sharing.service';
import { MessagingParticipationService } from '../../src/modules/messaging/internal/messaging-participation.service';

export const messagingParticipation = new MessagingParticipationService(
  ownerPorts.providers,
  ownerPorts.plans,
);

export function sharingService(
  prisma: unknown,
  permissions: unknown,
  notifications: unknown,
  invitationDelivery: unknown,
  history: unknown,
  realtime?: unknown,
): SharingService {
  const client = withOwnerTables(prisma as any);
  // A permission fake without the live re-check gets the real one over the
  // fixture's client; the fake's own methods win.
  const livePermissions = new PermissionService(client, ownerPorts.plans);
  const completedPermissions = permissions && typeof (permissions as any).liveAuthorizationFilter === 'function'
    ? permissions
    : Object.assign(
        Object.create(Object.getPrototypeOf(permissions ?? {})),
        { liveAuthorizationFilter: livePermissions.liveAuthorizationFilter.bind(livePermissions) },
        permissions,
      );
  return new SharingService(
    client,
    completedPermissions as any,
    notifications as any,
    invitationDelivery as any,
    history as any,
    ownerPorts.plans,
    ownerPorts.users,
    ownerPorts.users,
    messagingParticipation,
    realtime as any,
  );
}

/** A history service over the fixture's client; the live re-check runs through a permission service over the same client. */
export function contributionHistoryService(prisma: unknown): ContributionHistoryService {
  const client = withOwnerTables(prisma as any);
  return new ContributionHistoryService(
    client,
    ownerPorts.plans,
    new PermissionService(client, ownerPorts.plans),
  );
}

export function inviteAccessService(prisma: unknown, auth: unknown): InviteAccessService {
  return new InviteAccessService(withOwnerTables(prisma as any), auth as any, ownerPorts.users);
}

// ---------------------------------------------------------------------------
// Fixture relation tables. Sharing fixtures describe their invite and member
// rows with the related plan and people inline — the shape the old Prisma
// includes returned. The owners now read those rows through their ports
// (`user.findMany`, `weddingPlan.findMany`, `sharedMember.findFirst`, ...).
// This shim completes a fixture client *in place* (fixtures compare client
// identity) with owner-table methods that serve exactly the inline rows the
// fixture already returned, and only where the fixture defines no such method.
type FakeClient = Record<string, any>;

function isRow(value: unknown): value is Record<string, any> {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value) && !(value instanceof Date);
}

const OWNER_TABLES = new WeakSet<object>();

type Rows = Map<string, Record<string, any>>;
interface OwnerStore { users: Rows; plans: Rows; members: Rows }

export function withOwnerTables<T extends FakeClient>(fake: T): T {
  return install(fake, { users: new Map(), plans: new Map(), members: new Map() });
}

function install<T extends FakeClient>(fake: T, store: OwnerStore): T {
  if (!fake || typeof fake !== 'object' || OWNER_TABLES.has(fake)) return fake;
  OWNER_TABLES.add(fake);
  const { users, plans, members } = store;
  const remember = (rows: Rows, row: Record<string, any>) => rows.set(row.id, { ...rows.get(row.id), ...row });
  const harvest = (table: string, value: unknown, depth = 0): void => {
    if (depth > 3) return;
    if (Array.isArray(value)) { for (const item of value) harvest(table, item, depth); return; }
    if (!isRow(value)) return;
    for (const key of ['inviter', 'invitee', 'user', 'owner'] as const) {
      const related = value[key];
      if (isRow(related) && typeof related.id === 'string') remember(users, related);
    }
    const plan = value.weddingPlan;
    if (isRow(plan) && typeof plan.id === 'string') remember(plans, plan);
    if (table === 'sharedMember' && typeof value.id === 'string' && typeof value.weddingPlanId === 'string' && typeof value.userId === 'string') {
      remember(members, value);
    }
  };
  const ids = (where: any): string[] | null => (where?.id?.in ? [...where.id.in] : typeof where?.id === 'string' ? [where.id] : null);
  const matches = (row: Record<string, any>, where: Record<string, any>) => Object.entries(where ?? {}).every(([key, expected]) => (
    key === 'id' && isRow(expected) ? (expected.in as string[]).includes(row.id) : row[key] === expected
  ));
  const registries: Record<string, Record<string, (args: any) => Promise<unknown>>> = {
    user: {
      findMany: async ({ where }: any) => { const wanted = ids(where); return [...users.values()].filter((row) => (wanted ? wanted.includes(row.id) : true)); },
      findUnique: async ({ where }: any) => users.get(where.id) ?? null,
      findFirst: async ({ where }: any) => [...users.values()].find((row) => matches(row, where)) ?? null,
    },
    weddingPlan: {
      findMany: async ({ where }: any) => [...plans.values()].filter((row) => matches(row, where)),
      findUnique: async ({ where }: any) => plans.get(where.id) ?? null,
      findFirst: async ({ where }: any) => [...plans.values()].find((row) => matches(row, where)) ?? null,
    },
    sharedMember: {
      findFirst: async ({ where }: any) => [...members.values()].find((row) => matches(row, where)) ?? null,
      findMany: async ({ where }: any) => [...members.values()].filter((row) => matches(row, where)),
    },
  };
  for (const table of ['planInvite', 'sharedMember', 'user', 'weddingPlan']) {
    const delegate = fake[table];
    if (!isRow(delegate)) continue;
    for (const method of Object.keys(delegate)) {
      const own = delegate[method];
      if (typeof own !== 'function') continue;
      delegate[method] = async (...args: unknown[]) => { const result = await own.apply(delegate, args); harvest(table, result); return result; };
    }
  }
  for (const [table, methods] of Object.entries(registries)) {
    if (fake[table] === undefined) (fake as FakeClient)[table] = {};
    if (!isRow(fake[table])) continue;
    for (const [method, implementation] of Object.entries(methods)) {
      if (fake[table][method] === undefined) fake[table][method] = implementation;
    }
  }
  // Rows read or written inside a transaction are the rows the client serves
  // afterwards, so the transaction client shares the store. The wrapping is an
  // accessor because some fixtures replace `$transaction` after the service
  // was built; the replacement is wrapped the same way.
  let transaction: unknown = fake.$transaction;
  if (typeof transaction === 'function') {
    const wrapped = (operation: unknown, ...rest: unknown[]) => (transaction as (...args: unknown[]) => unknown).call(
      fake,
      typeof operation === 'function' ? (tx: FakeClient) => (operation as (client: unknown) => unknown)(install(tx, store)) : operation,
      ...rest,
    );
    Object.defineProperty(fake, '$transaction', {
      configurable: true,
      enumerable: true,
      get: () => wrapped,
      set: (value: unknown) => { transaction = value; },
    });
  }
  return fake;
}
