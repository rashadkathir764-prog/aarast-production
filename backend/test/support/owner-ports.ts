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
const realHistory = new ContributionHistoryService({} as any);

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
