import { ForbiddenException, NotFoundException } from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  Prisma,
  QuoteRequest,
} from "@prisma/client";
import {
  type CollaborationPermissionPort as PermissionService,
  type PlanAccessContext,
} from "../modules/collaboration/public/collaboration-permission.port";
import type { CollaborationScopePort } from "../modules/collaboration/public/collaboration-scope.port";
import type { MarketplaceRelationsService } from "./marketplace-relations";
import {
  FULL_QUOTE_VISIBILITY,
  MARKETPLACE_QUOTE_INCLUDE,
  type MyQuoteAccessWhere,
  type QuoteVisibility,
  type QuoteWithRelations,
} from "./marketplace.contracts";

/** The owners a plan-scoped quote read asks: membership and its live re-check, the contribution scope, and the related rows. */
export interface QuoteScopePorts {
  permissions: PermissionService;
  scope: CollaborationScopePort;
  relations: MarketplaceRelationsService;
}

const QUOTE_OWNERSHIP_ACTIONS = [
  ContributionAction.CREATED,
  ContributionAction.LEGACY_CAPTURED,
] as const;

export function assertProviderSectionLive(
  context: PlanAccessContext,
  permissions: PermissionService,
): void {
  if (context.isOwner || permissions.canManageProviders(context)) return;
  throw new ForbiddenException({
    statusCode: 403,
    code: "PROVIDER_PERMISSION_REVOKED",
    message: "Provider access has been revoked",
  });
}

export function quoteVisibilityForPlan(
  context: PlanAccessContext,
  permissions: PermissionService,
  currentUserId: string,
  quote: Pick<QuoteRequest, "userId">,
): QuoteVisibility {
  if (quote.userId === currentUserId) return FULL_QUOTE_VISIBILITY;
  return {
    budget: permissions.canViewMoney(context),
    contact: permissions.canManageProviders(context),
  };
}

/** The quote requests the contributor created in the plan, by collaboration's contribution history. */
export function findContributorProviderQuoteIds(
  client: Prisma.TransactionClient,
  scope: CollaborationScopePort,
  weddingPlanId: string,
  actorUserId: string,
): Promise<string[]> {
  return scope.qualifyingEntityIdsInTransaction(
    client,
    weddingPlanId,
    actorUserId,
    [ContributionEntityType.QUOTE_REQUEST],
    QUOTE_OWNERSHIP_ACTIONS,
  );
}

export async function findAccessiblePlanQuoteRequest(
  client: Prisma.TransactionClient,
  ports: QuoteScopePorts,
  context: PlanAccessContext,
  currentUserId: string,
  quoteRequestId: string,
  weddingPlanId: string,
): Promise<QuoteWithRelations> {
  if (
    !context.isOwner &&
    !(await findContributorProviderQuoteIds(
      client,
      ports.scope,
      weddingPlanId,
      currentUserId,
    )).includes(quoteRequestId)
  ) {
    throw new NotFoundException("Quote request not found");
  }
  // The final read re-checks current ownership/membership and the provider
  // (and money) permission through the owners and applies the result to
  // the quote table itself.
  const liveFilter = await ports.permissions.liveAuthorizationFilter(
    client,
    context,
    currentUserId,
    [
      "canManageProviders",
      ...(ports.permissions.canViewMoney(context)
        ? (["canViewMoney"] as const)
        : []),
    ],
  );
  const quote = await client.quoteRequest.findFirst({
    where: {
      id: quoteRequestId,
      weddingPlanId,
      ...liveFilter,
    },
    include: MARKETPLACE_QUOTE_INCLUDE,
  });
  if (!quote) throw new NotFoundException("Quote request not found");
  return ports.relations.attachQuoteRelation(client, quote);
}

/**
 * The user's own quote requests: plan-less ones, those of the plans the user
 * owns, and those the user created as a member who still manages providers.
 * Ownership and membership are planning's and collaboration's rows, read
 * through their ports and applied to the quote table by plan id.
 */
export async function buildMyQuoteAccessWhere(
  client: Prisma.TransactionClient,
  ports: QuoteScopePorts,
  userId: string,
  id?: string,
): Promise<MyQuoteAccessWhere> {
  const qualifyingQuoteIds =
    await ports.scope.qualifyingEntityIdsForActorInTransaction(
      client,
      userId,
      [ContributionEntityType.QUOTE_REQUEST],
      QUOTE_OWNERSHIP_ACTIONS,
      id,
    );
  const ownedPlanIds = await ports.relations.plans.listOwnedPlanIds(
    client,
    userId,
  );
  const providerManagingPlanIds = (
    await ports.permissions.listMemberships(client, userId)
  )
    .filter((membership) => membership.canManageProviders)
    .map((membership) => membership.weddingPlanId);
  return {
    ...(id ? { id } : {}),
    userId,
    OR: [
      { weddingPlanId: null },
      { weddingPlanId: { in: ownedPlanIds } },
      {
        id: { in: qualifyingQuoteIds },
        weddingPlanId: { in: providerManagingPlanIds },
      },
    ],
  };
}
