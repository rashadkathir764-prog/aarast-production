import {
  ContributionAction,
  ContributionEntityType,
  Prisma,
} from "@prisma/client";
import type { TaskReadScope } from "../modules/tasks/public/tasks.port";
import type { CollaborationScopePort as ContributorScopeService } from "../modules/collaboration/public/collaboration-scope.port";
import type { PlanAccessContext } from "../modules/collaboration/public/collaboration-permission.port";

export interface DashboardContributorDataScope {
  providersEnabled: boolean;
  tasksEnabled: boolean;
  quoteIds: string[];
  taskIds: string[];
  guestIds: string[];
  costIds: string[];
  memberIds: string[];
  inviteIds: string[];
}

interface ResolveDashboardContributorDataScopeInput {
  tx: Prisma.TransactionClient;
  context: PlanAccessContext;
  weddingPlanId: string;
  actorUserId: string;
  canViewMoney: boolean;
  contributorScope: ContributorScopeService;
}

const qualifyingOwnWorkActions = [
  ContributionAction.CREATED,
  ContributionAction.COMPLETED,
  ContributionAction.PAYMENT_RECORDED,
] as const;

export async function resolveDashboardContributorDataScope(
  input: ResolveDashboardContributorDataScopeInput,
): Promise<DashboardContributorDataScope> {
  const member = input.context.sharedMember;
  if (input.context.isOwner || !member) {
    throw new Error("Contributor membership is required for contributor dashboard scope");
  }

  const providersEnabled = member.canManageProviders;
  const tasksEnabled = member.canManageTasks;
  const [quoteIds, taskIds, guestIds, costIds, memberIds, inviteIds] =
    await Promise.all([
      providersEnabled
        ? input.contributorScope.qualifyingEntityIdsInTransaction(
            input.tx,
            input.weddingPlanId,
            input.actorUserId,
            [ContributionEntityType.QUOTE_REQUEST],
            [ContributionAction.CREATED, ContributionAction.LEGACY_CAPTURED],
          )
        : Promise.resolve([]),
      tasksEnabled
        ? input.contributorScope.qualifyingEntityIdsInTransaction(
            input.tx,
            input.weddingPlanId,
            input.actorUserId,
            [ContributionEntityType.TASK],
            qualifyingOwnWorkActions,
          )
        : Promise.resolve([]),
      member.canManageGuests
        ? input.contributorScope.qualifyingEntityIdsInTransaction(
            input.tx,
            input.weddingPlanId,
            input.actorUserId,
            [ContributionEntityType.GUEST],
            qualifyingOwnWorkActions,
          )
        : Promise.resolve([]),
      input.canViewMoney
        ? input.contributorScope.qualifyingEntityIdsInTransaction(
            input.tx,
            input.weddingPlanId,
            input.actorUserId,
            [ContributionEntityType.WEDDING_COST],
            qualifyingOwnWorkActions,
          )
        : Promise.resolve([]),
      member.canInviteMembers
        ? input.contributorScope.qualifyingEntityIdsInTransaction(
            input.tx,
            input.weddingPlanId,
            input.actorUserId,
            [ContributionEntityType.MEMBER_ITEM],
            [ContributionAction.CREATED, ContributionAction.INVITED],
          )
        : Promise.resolve([]),
      member.canInviteMembers
        ? input.contributorScope.qualifyingEntityIdsInTransaction(
            input.tx,
            input.weddingPlanId,
            input.actorUserId,
            [ContributionEntityType.PLAN_INVITE],
            [ContributionAction.CREATED, ContributionAction.INVITED],
          )
        : Promise.resolve([]),
    ]);

  return {
    providersEnabled,
    tasksEnabled,
    quoteIds,
    taskIds,
    guestIds,
    costIds,
    memberIds,
    inviteIds,
  };
}

/** Which tasks the dashboard reader sees; the task table applies it (tasks' port). */
export function dashboardTaskReadScope(
  scope: DashboardContributorDataScope | null,
  actorUserId: string,
): TaskReadScope {
  if (!scope) return { kind: "all", readerUserId: actorUserId };
  if (!scope.tasksEnabled) return { kind: "none" };
  return {
    kind: "contributor",
    assigneeUserId: actorUserId,
    taskIds: scope.taskIds,
  };
}

/** Which quote ids a contributor's provider figures cover: null for the owner, none when provider access is off. */
export function dashboardQuoteIds(
  scope: DashboardContributorDataScope | null,
): string[] | null {
  if (!scope) return null;
  return scope.providersEnabled ? scope.quoteIds : [];
}
