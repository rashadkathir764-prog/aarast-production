// Real owner port implementations for the managed smokes. Every one runs its
// statements on the client the calling service passes (the smoke's Prisma
// client or its transaction), exactly as the Nest wiring does.
import { CatalogReadService } from '../../../src/modules/catalog/internal/catalog-read.service';
import { CollaborationErasureService } from '../../../src/modules/collaboration/internal/collaboration-erasure.service';
import { ContributionHistoryService } from '../../../src/modules/collaboration/internal/contribution-history.service';
import type { PermissionService } from '../../../src/modules/collaboration/internal/permission.service';
import { SharingService } from '../../../src/modules/collaboration/internal/sharing.service';
import { FinancePortService } from '../../../src/modules/finance/internal/finance-port.service';
import { GuestsPortService } from '../../../src/modules/guests/internal/guests-port.service';
import { IdentityUserPortService } from '../../../src/modules/identity/internal/identity-user-port.service';
import { MarketplaceErasureService } from '../../../src/modules/marketplace/internal/marketplace-erasure.service';
import { ProviderReadService } from '../../../src/modules/marketplace/internal/provider-read.service';
import { QuoteReadService } from '../../../src/modules/marketplace/internal/quote-read.service';
import { MessagingErasureService } from '../../../src/modules/messaging/internal/messaging-erasure.service';
import { MessagingParticipationService } from '../../../src/modules/messaging/internal/messaging-participation.service';
import { NotificationsErasureService } from '../../../src/modules/notifications/internal/notifications-erasure.service';
import { PlanErasureService } from '../../../src/modules/planning/internal/plan-erasure.service';
import { PlanReadService } from '../../../src/modules/planning/internal/plan-read.service';
import { TasksPortService } from '../../../src/modules/tasks/internal/tasks-port.service';

export const ownerPorts = {
  plans: new PlanReadService(),
  catalog: new CatalogReadService(),
  planErasure: new PlanErasureService(),
  users: new IdentityUserPortService(),
  finance: new FinancePortService(),
  tasks: new TasksPortService(),
  guests: new GuestsPortService(),
  providers: new ProviderReadService(),
  quotes: new QuoteReadService(),
  marketplaceErasure: new MarketplaceErasureService(),
  messagingErasure: new MessagingErasureService(),
  notificationsErasure: new NotificationsErasureService(),
  collaborationErasure: new CollaborationErasureService(),
};

/** The five owner ports `WeddingPlansService` takes after the collaboration ports. */
export const planningOwnerPorts = [
  ownerPorts.users,
  ownerPorts.users,
  ownerPorts.finance,
  ownerPorts.tasks,
  ownerPorts.guests,
] as const;

export const messagingParticipation = new MessagingParticipationService(
  ownerPorts.providers,
  ownerPorts.plans,
);

/** The history service over the smoke's client; the live re-check runs through the given permission service. */
export function contributionHistoryService(
  prisma: unknown,
  permissions: PermissionService,
): ContributionHistoryService {
  return new ContributionHistoryService(prisma as any, ownerPorts.plans, permissions);
}

/** `SharingService` with the four owner ports it takes after the history service. */
export function sharingService(
  prisma: unknown,
  permissions: PermissionService,
  notifications: unknown,
  invitationDelivery: unknown,
  history: ContributionHistoryService,
  realtime?: unknown,
): SharingService {
  return new SharingService(
    prisma as any,
    permissions,
    notifications as any,
    invitationDelivery as any,
    history,
    ownerPorts.plans,
    ownerPorts.users,
    ownerPorts.users,
    messagingParticipation,
    realtime as any,
  );
}

/** The eight owner ports `UsersService` takes after the media storage port. */
export const identityErasurePorts = [
  ownerPorts.planErasure,
  ownerPorts.marketplaceErasure,
  ownerPorts.messagingErasure,
  ownerPorts.notificationsErasure,
  ownerPorts.collaborationErasure,
  ownerPorts.finance,
  ownerPorts.tasks,
  ownerPorts.guests,
] as const;
