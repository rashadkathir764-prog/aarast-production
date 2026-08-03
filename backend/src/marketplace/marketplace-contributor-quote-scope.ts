import { ForbiddenException, NotFoundException } from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  Prisma,
  QuoteRequest,
} from "@prisma/client";
import {
  livePlanAuthorizationWhere,
  PermissionService,
  type PlanAccessContext,
} from "../sharing/permission.service";
import {
  FULL_QUOTE_VISIBILITY,
  MARKETPLACE_QUOTE_INCLUDE,
  type QuoteVisibility,
  type QuoteWithRelations,
} from "./marketplace.contracts";

type ContributionReader = Pick<Prisma.TransactionClient, "contributionEvent">;
type PlanQuoteReader = Pick<
  Prisma.TransactionClient,
  "contributionEvent" | "quoteRequest"
>;

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

export async function findContributorProviderQuoteIds(
  client: ContributionReader,
  weddingPlanId: string,
  actorUserId: string,
): Promise<string[]> {
  const events = await client.contributionEvent.findMany({
    where: {
      historyScope: { weddingPlanId },
      contributorTenure: { actorUserId },
      entityType: ContributionEntityType.QUOTE_REQUEST,
      action: { in: [...QUOTE_OWNERSHIP_ACTIONS] },
      entityId: { not: null },
    },
    select: { entityId: true },
    distinct: ["entityId"],
  });
  return events.flatMap((event) => (event.entityId ? [event.entityId] : []));
}

export async function findAccessiblePlanQuoteRequest(
  client: PlanQuoteReader,
  context: PlanAccessContext,
  permissions: PermissionService,
  currentUserId: string,
  quoteRequestId: string,
  weddingPlanId: string,
): Promise<QuoteWithRelations> {
  if (
    !context.isOwner &&
    !(await findContributorProviderQuoteIds(
      client,
      weddingPlanId,
      currentUserId,
    )).includes(quoteRequestId)
  ) {
    throw new NotFoundException("Quote request not found");
  }
  const quote = await client.quoteRequest.findFirst({
    where: {
      id: quoteRequestId,
      weddingPlanId,
      weddingPlan: {
        is: livePlanAuthorizationWhere(
          context,
          currentUserId,
          [
            "canManageProviders",
            ...(permissions.canViewMoney(context)
              ? (["canViewMoney"] as const)
              : []),
          ],
        ),
      },
    },
    include: MARKETPLACE_QUOTE_INCLUDE,
  });
  if (!quote) throw new NotFoundException("Quote request not found");
  return quote;
}

export async function buildMyQuoteAccessWhere(
  client: ContributionReader,
  userId: string,
  id?: string,
): Promise<Prisma.QuoteRequestWhereInput> {
  const qualifyingEvents = await client.contributionEvent.findMany({
    where: {
      contributorTenure: { actorUserId: userId },
      entityType: ContributionEntityType.QUOTE_REQUEST,
      action: { in: [...QUOTE_OWNERSHIP_ACTIONS] },
      entityId: id ? id : { not: null },
    },
    select: { entityId: true },
    distinct: ["entityId"],
  });
  const qualifyingQuoteIds = qualifyingEvents.flatMap((event) =>
    event.entityId ? [event.entityId] : [],
  );
  return {
    ...(id ? { id } : {}),
    userId,
    OR: [
      { weddingPlanId: null },
      { weddingPlan: { is: { ownerUserId: userId } } },
      {
        id: { in: qualifyingQuoteIds },
        weddingPlan: {
          is: {
            sharedMembers: {
              some: { userId, canManageProviders: true },
            },
          },
        },
      },
    ],
  };
}
