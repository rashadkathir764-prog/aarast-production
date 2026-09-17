// Real owner port implementations for fixture-based unit tests. Each one runs
// the same Prisma delegate calls the service under test used to run itself,
// against whatever fake client the test passes in, so a fixture that stubbed
// `tx.budgetCategory.createMany` keeps working after the call moved to the
// owner (the R4 precedent for supplying a new owner collaborator).
import { CatalogReadService } from '../../src/modules/catalog/internal/catalog-read.service';
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
  catalog: new CatalogReadService(),
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

/**
 * A permission fake completed with the owner-side reads a consumer now asks
 * of the port (the live re-check, membership lookups and locks); each runs the
 * real statements against the fixture's client. The fake's own methods win.
 */
export function completePermissions<T extends object>(fake: T, client: unknown): T {
  const live = new PermissionService(client as any, ownerPorts.plans);
  const owned = {} as Record<string, unknown>;
  for (const method of [
    'liveAuthorizationFilter',
    'getMembership',
    'listMemberships',
    'listMemberPlanIds',
    'lockMembershipForShareInTransaction',
  ] as const) {
    if (typeof (fake as Record<string, unknown>)[method] !== 'function') {
      owned[method] = (live[method] as (...args: unknown[]) => unknown).bind(live);
    }
  }
  if (Object.keys(owned).length === 0) return fake;
  return Object.assign(Object.create(Object.getPrototypeOf(fake ?? {})), owned, fake);
}

export function sharingService(
  prisma: unknown,
  permissions: unknown,
  notifications: unknown,
  invitationDelivery: unknown,
  history: unknown,
  realtime?: unknown,
): SharingService {
  const client = withOwnerTables(prisma as any);
  return new SharingService(
    client,
    completePermissions(permissions as object, client) as any,
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
// Tasks: the live re-check and the assignee membership lock are asked of the
// permission port; fixtures keep their five-argument list.
import { TasksService } from '../../src/tasks/tasks.service';

export function tasksService(
  prisma: unknown,
  permissions: unknown,
  notifications: unknown,
  history: unknown,
  scope: unknown,
): TasksService {
  const client = withOwnerTables(prisma as any);
  return new TasksService(
    client,
    completePermissions(permissions as object, client) as any,
    notifications as any,
    history as any,
    scope as any,
  );
}

// ---------------------------------------------------------------------------
// Marketplace: the catalog, plan, user and cost rows its includes used to
// return are attached through MarketplaceRelationsService; fixtures keep the
// five-to-six-argument list of MarketplaceService and the script helpers.
import { MarketplaceService } from '../../src/marketplace/marketplace.service';
import { MarketplaceRelationsService } from '../../src/marketplace/marketplace-relations';
import { ContributorScopeService } from '../../src/modules/collaboration/internal/contributor-scope.service';
import type { FinancePort } from '../../src/modules/finance/public/finance.port';

export function marketplaceRelations(finance: FinancePort = ownerPorts.finance): MarketplaceRelationsService {
  return new MarketplaceRelationsService(ownerPorts.catalog, ownerPorts.plans, ownerPorts.users, finance);
}

/** The contribution scope over the fixture's client (the same statements the scope service runs). */
export function contributorScope(prisma: unknown): ContributorScopeService {
  return new ContributorScopeService(contributionHistoryService(prisma));
}

export function marketplaceService(
  prisma: unknown,
  permissions: unknown,
  notifications: unknown,
  lifecycle: unknown,
  finance: FinancePort,
  history?: unknown,
): MarketplaceService {
  const client = withOwnerTables(prisma as any);
  return new MarketplaceService(
    client,
    completePermissions(permissions as object, client) as any,
    notifications as any,
    lifecycle as any,
    finance,
    ownerPorts.catalog,
    contributorScope(client),
    marketplaceRelations(finance),
    history as any,
  );
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
type OwnerTable = 'user' | 'weddingPlan' | 'sharedMember' | 'city' | 'providerCategory' | 'weddingCost';
type OwnerStore = Record<OwnerTable, Rows>;

// Which inline relation keys carry which owner's rows.
const RELATION_TABLES: Record<string, OwnerTable> = {
  inviter: 'user', invitee: 'user', user: 'user', owner: 'user',
  weddingPlan: 'weddingPlan',
  city: 'city',
  primaryCategory: 'providerCategory', category: 'providerCategory',
};

export function withOwnerTables<T extends FakeClient>(fake: T): T {
  return install(fake, {
    user: new Map(), weddingPlan: new Map(), sharedMember: new Map(),
    city: new Map(), providerCategory: new Map(), weddingCost: new Map(),
  });
}

function install<T extends FakeClient>(fake: T, store: OwnerStore): T {
  if (!fake || typeof fake !== 'object' || OWNER_TABLES.has(fake)) return fake;
  OWNER_TABLES.add(fake);
  const remember = (table: OwnerTable, row: Record<string, any>) => {
    if (typeof row.id !== 'string') return;
    store[table].set(row.id, { ...store[table].get(row.id), ...row });
  };
  const harvest = (table: string, value: unknown, depth = 0): void => {
    if (depth > 4) return;
    if (Array.isArray(value)) { for (const item of value) harvest(table, item, depth); return; }
    if (!isRow(value)) return;
    if (table === 'sharedMember' && typeof value.weddingPlanId === 'string' && typeof value.userId === 'string') remember('sharedMember', value);
    for (const [key, related] of Object.entries(value)) {
      const owner = RELATION_TABLES[key];
      if (owner && isRow(related)) remember(owner, related);
      // A cost linked to an offer arrives inline on the offer (`offers[].weddingCosts`).
      if (key === 'weddingCosts' && Array.isArray(related) && typeof value.id === 'string') {
        for (const cost of related) if (isRow(cost)) remember('weddingCost', { ...cost, quoteOfferId: value.id });
      }
      if (isRow(related) || Array.isArray(related)) harvest(key === 'sharedMembers' ? 'sharedMember' : key, related, depth + 1);
    }
  };
  const matches = (row: Record<string, any>, where: Record<string, any>) => Object.entries(where ?? {}).every(([key, expected]) => (
    isRow(expected) && Array.isArray(expected.in) ? expected.in.includes(row[key]) : row[key] === expected
  ));
  const registry = (table: OwnerTable) => ({
    findMany: async ({ where }: any = {}) => [...store[table].values()].filter((row) => matches(row, where)),
    findUnique: async ({ where }: any) => store[table].get(where.id) ?? null,
    findFirst: async ({ where }: any) => [...store[table].values()].find((row) => matches(row, where)) ?? null,
  });
  for (const [table, delegate] of Object.entries(fake)) {
    if (table.startsWith('$') || !isRow(delegate)) continue;
    for (const method of Object.keys(delegate)) {
      const own = delegate[method];
      if (typeof own !== 'function') continue;
      delegate[method] = async (...args: unknown[]) => { const result = await own.apply(delegate, args); harvest(table, result); return result; };
    }
  }
  for (const table of Object.keys(store) as OwnerTable[]) {
    if (fake[table] === undefined) (fake as FakeClient)[table] = {};
    if (!isRow(fake[table])) continue;
    for (const [method, implementation] of Object.entries(registry(table))) {
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
