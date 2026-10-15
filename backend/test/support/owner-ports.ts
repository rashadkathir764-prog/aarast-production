// Real owner port implementations for fixture-based unit tests. Each one runs
// the same Prisma delegate calls the service under test used to run itself,
// against whatever fake client the test passes in, so a fixture that stubbed
// `tx.budgetCategory.createMany` keeps working after the call moved to the
// owner (the R4 precedent for supplying a new owner collaborator).
import { CatalogReadService } from '../../src/modules/catalog/infrastructure/catalog-read.service';
import { ContributionHistoryService } from '../../src/modules/collaboration/internal/contribution-history.service';
import { PermissionService } from '../../src/modules/collaboration/internal/permission.service';
import { FinancePortService } from '../../src/modules/finance/infrastructure/finance-port.service';
import { GuestsPortService } from '../../src/modules/guests/infrastructure/guests-port.service';
import { IdentityUserPortService } from '../../src/modules/identity/infrastructure/identity-user-port.service';
import { ProviderReadService } from '../../src/modules/marketplace/infrastructure/provider-read.service';
import { QuoteReadService } from '../../src/modules/marketplace/infrastructure/quote-read.service';
import { PlanReadService } from '../../src/modules/planning/infrastructure/plan-read.service';
import { TasksPortService } from '../../src/modules/tasks/infrastructure/tasks-port.service';

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
import { MessagingErasureService } from '../../src/modules/messaging/infrastructure/messaging-erasure.service';
import { MarketplaceErasureService } from '../../src/modules/marketplace/infrastructure/marketplace-erasure.service';
import { NotificationsErasureService } from '../../src/modules/notifications/infrastructure/notifications-erasure.service';
import { CollaborationErasureService } from '../../src/modules/collaboration/infrastructure/collaboration-erasure.service';
import { PlanErasureService } from '../../src/modules/planning/infrastructure/plan-erasure.service';
import { MediaStorageService } from '../../src/media/media-storage.service';
import { MediaUploadTicketService } from '../../src/modules/media/infrastructure/media-upload-ticket.service';

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
import { MessagingParticipationService } from '../../src/modules/messaging/infrastructure/messaging-participation.service';

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
    'listPlanMembers',
    'countPlanMembers',
    'countLivePlanInvites',
    'lockMembershipForShareInTransaction',
    'lockMembershipsForShareInTransaction',
    'lockPlanMembershipsForShareInTransaction',
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
import { ProviderDashboardService } from '../../src/provider-dashboard/provider-dashboard.service';
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

/** `ProviderDashboardService` with the catalog and provider-account ports and the relations service. */
export function providerDashboardService(
  prisma: unknown,
  notifications: unknown,
  mediaStorage: unknown,
  lifecycle: unknown,
): ProviderDashboardService {
  return new ProviderDashboardService(
    withOwnerTables(prisma as any),
    notifications as any,
    mediaStorage as any,
    lifecycle as any,
    ownerPorts.catalog,
    ownerPorts.users,
    marketplaceRelations(),
  );
}

// ---------------------------------------------------------------------------
// Messaging: the provider, plan, members, identities and quote requests a
// conversation shows are attached through ConversationRelationsService; the
// gateway asks identity whether a socket's account may hold a channel.
import { ConversationRelationsService } from '../../src/conversations/conversation-relations';
import { ConversationsGateway } from '../../src/conversations/conversations.gateway';
import { ConversationsService } from '../../src/conversations/conversations.service';
import { IdentityRealtimeSessionService } from '../../src/modules/identity/infrastructure/identity-realtime-session.service';

export function conversationRelations(client: unknown): ConversationRelationsService {
  return new ConversationRelationsService(
    ownerPorts.providers,
    ownerPorts.users,
    ownerPorts.plans,
    new PermissionService(client as any, ownerPorts.plans),
    ownerPorts.quotes,
  );
}

export function conversationsService(
  prisma: unknown,
  notifications: unknown,
  realtime: unknown,
  mediaStorage: unknown,
  outbox: unknown,
): ConversationsService {
  const client = withOwnerTables(prisma as any);
  return new ConversationsService(
    client,
    notifications as any,
    realtime as any,
    mediaStorage as any,
    outbox as any,
    conversationRelations(client),
  );
}

/** The realtime session decision over the fixture's client (the same user and session statements the gateway ran). */
export function realtimeSessions(prisma: unknown): IdentityRealtimeSessionService {
  return new IdentityRealtimeSessionService(prisma as any);
}

export function conversationsGateway(
  jwt: unknown,
  prisma: unknown,
  conversations: unknown,
  realtime: unknown,
): ConversationsGateway {
  return new ConversationsGateway(
    jwt as any,
    realtimeSessions(prisma),
    conversations as any,
    realtime as any,
  );
}

// ---------------------------------------------------------------------------
// Notifications: the plans, members, due tasks and schedules, contributions,
// provider and conversation rows the reminders and the visibility rules
// read are the owners'; fixtures keep their three-argument list.
import { NotificationsService } from '../../src/notifications/notifications.service';
import { NotificationsRepository } from '../../src/modules/notifications/infrastructure/notifications.repository';
import { ConversationLifecycleService } from '../../src/modules/messaging/internal/conversation-lifecycle.internal.module';

export function notificationsService(
  prisma: unknown,
  permissions: unknown,
  outbox: unknown,
): NotificationsService {
  const client = withOwnerTables(prisma as any);
  return new NotificationsService(
    client,
    completePermissions(permissions as object, client) as any,
    outbox as any,
    ownerPorts.plans,
    contributorScope(client),
    ownerPorts.tasks,
    ownerPorts.finance,
    ownerPorts.providers,
    new ConversationLifecycleService(ownerPorts.plans, ownerPorts.providers),
  );
}

// ---------------------------------------------------------------------------
// Insights: the dashboard and timeline compose the owners' reads through
// InsightsReadPorts; fixtures keep their argument lists. A notifications
// fake without the plan dashboard preview gets the real preview statements,
// run under the fake's own visibility filter.
import { DashboardService } from '../../src/dashboard/dashboard.service';
import { InsightsReadPorts } from '../../src/dashboard/insights-read-ports';
import { TimelineService } from '../../src/timeline/timeline.service';

export const insightsReadPorts = new InsightsReadPorts(
  ownerPorts.plans,
  ownerPorts.tasks,
  ownerPorts.guests,
  ownerPorts.finance,
  ownerPorts.providers,
  ownerPorts.quotes,
  ownerPorts.users,
  ownerPorts.catalog,
);

function completeNotifications<T extends object>(fake: T): T {
  if (typeof (fake as Record<string, unknown>).getPlanNotificationDashboard === 'function') return fake;
  return Object.assign(Object.create(fake), {
    getPlanNotificationDashboard: NotificationsService.prototype.getPlanNotificationDashboard,
    repository: new NotificationsRepository(),
  });
}

export function dashboardService(
  prisma: unknown,
  permissions: unknown,
  notifications: unknown,
  scope?: unknown,
  history?: unknown,
): DashboardService {
  const client = withOwnerTables(prisma as any);
  return new DashboardService(
    client,
    completePermissions(permissions as object, client) as any,
    completeNotifications(notifications as object) as any,
    insightsReadPorts,
    scope as any,
    history as any,
  );
}

export function timelineService(
  prisma: unknown,
  permissions: unknown,
  scope: unknown,
): TimelineService {
  const client = withOwnerTables(prisma as any);
  return new TimelineService(
    client,
    completePermissions(permissions as object, client) as any,
    scope as any,
    insightsReadPorts,
  );
}

// ---------------------------------------------------------------------------
// Backoffice: the admin service reaches every owner through AdminOwners;
// fixtures keep their argument lists and the owners run their statements
// on the fixture client.
import { AdminOwners } from '../../src/admin/admin-owners';
import { AdminService } from '../../src/admin/admin.service';
import { CatalogAdminService } from '../../src/modules/catalog/infrastructure/catalog-admin.service';
import { IdentityAdminService } from '../../src/modules/identity/infrastructure/identity-admin.service';
import { MarketplaceAdminService } from '../../src/modules/marketplace/internal/marketplace-admin.service';
import { MessagingAdminService } from '../../src/modules/messaging/infrastructure/messaging-admin.service';
import { NotificationsAdminService } from '../../src/modules/notifications/infrastructure/notifications-admin.service';

export const adminOwners = new AdminOwners(
  new IdentityAdminService(),
  ownerPorts.users,
  ownerPorts.users,
  new CatalogAdminService(),
  ownerPorts.catalog,
  new MarketplaceAdminService(),
  ownerPorts.providers,
  ownerPorts.quotes,
  new MessagingAdminService(),
  new NotificationsAdminService(),
  ownerPorts.plans,
  realPermissions,
  ownerPorts.finance,
);

export function adminService(
  prisma: unknown,
  realtime: unknown,
  notifications: unknown,
): AdminService {
  return new AdminService(
    withOwnerTables(prisma as any),
    realtime as any,
    notifications as any,
    adminOwners,
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
type OwnerTable = 'user' | 'weddingPlan' | 'sharedMember' | 'city' | 'providerCategory' | 'weddingCost' | 'provider' | 'quoteRequest';
type OwnerStore = Record<OwnerTable, Rows> & { quoteCounts: Map<string, number> };

// Which inline relation keys carry which owner's rows.
const RELATION_TABLES: Record<string, OwnerTable> = {
  inviter: 'user', invitee: 'user', user: 'user', owner: 'user', sender: 'user', accountRequester: 'user',
  weddingPlan: 'weddingPlan',
  city: 'city',
  primaryCategory: 'providerCategory', category: 'providerCategory',
  provider: 'provider',
};

export function withOwnerTables<T extends FakeClient>(fake: T): T {
  return install(fake, {
    user: new Map(), weddingPlan: new Map(), sharedMember: new Map(),
    city: new Map(), providerCategory: new Map(), weddingCost: new Map(),
    provider: new Map(), quoteRequest: new Map(), quoteCounts: new Map(),
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
    if (table === 'quoteRequest' && typeof value.conversationId === 'string') remember('quoteRequest', value);
    for (const [key, related] of Object.entries(value)) {
      const owner = RELATION_TABLES[key];
      if (owner && isRow(related)) remember(owner, related);
      // Rows the old includes nested under a parent carry the parent's id
      // the way the real rows do: a plan's members, an offer's costs, a
      // conversation's quote requests and their count.
      if (key === 'weddingCosts' && Array.isArray(related) && typeof value.id === 'string') {
        for (const cost of related) if (isRow(cost)) remember('weddingCost', { ...cost, quoteOfferId: value.id });
      }
      if (key === 'sharedMembers' && Array.isArray(related) && typeof value.id === 'string') {
        for (const member of related) if (isRow(member)) remember('sharedMember', { id: `${value.id}:${member.userId}`, weddingPlanId: value.id, ...member });
      }
      if (key === 'quoteRequests' && Array.isArray(related) && typeof value.id === 'string') {
        for (const quote of related) if (isRow(quote)) remember('quoteRequest', { conversationId: value.id, ...quote });
      }
      if (key === '_count' && isRow(related) && typeof related.quoteRequests === 'number' && typeof value.id === 'string') {
        store.quoteCounts.set(value.id, related.quoteRequests);
      }
      if (isRow(related) || Array.isArray(related)) harvest(key === 'sharedMembers' ? 'sharedMember' : key === 'quoteRequests' ? 'quoteRequest' : key, related, depth + 1);
    }
  };
  const matches = (row: Record<string, any>, where: Record<string, any>) => Object.entries(where ?? {}).every(([key, expected]) => (
    isRow(expected) && Array.isArray(expected.in) ? expected.in.includes(row[key]) : row[key] === expected
  ));
  const registry = (table: OwnerTable) => ({
    findMany: async ({ where }: any = {}) => [...store[table].values()].filter((row) => matches(row, where)),
    findUnique: async ({ where }: any) => (
      where.id ? (store[table].get(where.id) ?? null) : ([...store[table].values()].find((row) => matches(row, where)) ?? null)
    ),
    findFirst: async ({ where }: any) => [...store[table].values()].find((row) => matches(row, where)) ?? null,
    ...(table === 'quoteRequest'
      ? {
          groupBy: async ({ where }: any) => {
            const ids: string[] = where?.conversationId?.in ?? [];
            return ids.map((conversationId) => ({
              conversationId,
              _count: {
                _all: store.quoteCounts.get(conversationId)
                  ?? [...store.quoteRequest.values()].filter((row) => row.conversationId === conversationId).length,
              },
            }));
          },
        }
      : {}),
  });
  for (const [table, delegate] of Object.entries(fake)) {
    if (table.startsWith('$') || !isRow(delegate)) continue;
    for (const method of Object.keys(delegate)) {
      const own = delegate[method];
      if (typeof own !== 'function') continue;
      delegate[method] = async (...args: unknown[]) => { const result = await own.apply(delegate, args); harvest(table, result); return result; };
    }
  }
  for (const table of Object.keys(store).filter((name) => name !== 'quoteCounts') as OwnerTable[]) {
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
  // A fixture that models no transaction runs a transaction's callback on
  // the fixture itself: services open read snapshots (the live authorization
  // re-check and the read it guards), and a fake has no isolation to model.
  let transaction: unknown = fake.$transaction ?? (async (operation: unknown) => (
    typeof operation === 'function'
      ? (operation as (client: unknown) => unknown)(fake)
      : Promise.all(operation as unknown[])
  ));
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
