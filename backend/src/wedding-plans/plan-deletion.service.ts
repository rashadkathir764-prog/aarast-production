import {
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
} from "@nestjs/common";
import { Prisma, WeddingPersona } from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  USER_READ_PORT,
  type UserReadPort,
} from "../modules/identity/public/user-read.port";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort,
  isPlanDeletionPending,
} from "../modules/collaboration/public/collaboration-permission.port";
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../modules/notifications/public/notifications.port";
import {
  clearPlanDeletionRequest,
  markPlanDeletionRequested,
} from "../modules/planning/infrastructure/wedding-plan.repository";
import { PrismaService } from "../platform/database/prisma.service";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { applicationDisplayName } from "../shared-kernel/privacy/application-user-identity";
import {
  planDeletionCancelledNotice,
  planDeletionRequestedNotice,
} from "./plan-deletion-notices";
import { WeddingPlanResponse, WeddingPlansService } from "./wedding-plans.service";

/** Q-45 (D124): the days a plan waits, restorable, before it is erased. */
export const PLAN_DELETION_GRACE_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Q-45 (D124), RA-BE-179: the owner deletes a plan, live or archived. The
 * plan closes to its members (they are told) and to new invitations, stays
 * read-only to him, and the hourly purge erases it after 30 days; until
 * then he takes it back and it is as it was.
 */
@Injectable()
export class PlanDeletionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly plans: WeddingPlansService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: CollaborationPermissionPort,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
    @Inject(USER_READ_PORT) private readonly users: UserReadPort,
  ) {}

  /** Asking again while the plan waits answers the same request. */
  async request(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<WeddingPlanResponse> {
    await runSerializableTransaction(this.prisma, async (tx) => {
      const plan = await this.lockOwnedPlan(tx, weddingPlanId, currentUser);
      if (isPlanDeletionPending(plan)) return;
      const requestedAt = new Date();
      const scheduledFor = new Date(
        requestedAt.getTime() + PLAN_DELETION_GRACE_DAYS * DAY_MS,
      );
      await markPlanDeletionRequested(tx, plan.id, requestedAt, scheduledFor);
      // Closed: no invitation is accepted into it any more.
      await this.permissions.revokeLivePlanInvitesInTransaction(
        tx,
        plan.id,
        requestedAt,
      );
      const owner = await this.ownerVoice(tx, plan);
      for (const member of await this.permissions.listPlanMembers(tx, [plan.id])) {
        await this.notifications.createNotificationInTransaction(
          tx,
          planDeletionRequestedNotice({
            memberUserId: member.userId,
            weddingPlanId: plan.id,
            owner,
            scheduledFor,
            requestedAt,
          }),
        );
      }
    });
    return this.plans.findOne(currentUser, weddingPlanId);
  }

  /** Within the 30 days: the plan and its members are back, as they were. */
  async cancel(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<WeddingPlanResponse> {
    await runSerializableTransaction(this.prisma, async (tx) => {
      const plan = await this.lockOwnedPlan(tx, weddingPlanId, currentUser);
      if (!plan.deletionRequestedAt) {
        throw new ConflictException({
          statusCode: 409,
          code: "PLAN_DELETION_NOT_PENDING",
          message: "الخطة ما هي في طريقها للحذف.",
        });
      }
      await clearPlanDeletionRequest(tx, plan.id);
      const owner = await this.ownerVoice(tx, plan);
      for (const member of await this.permissions.listPlanMembers(tx, [plan.id])) {
        await this.notifications.createNotificationInTransaction(
          tx,
          planDeletionCancelledNotice({
            memberUserId: member.userId,
            weddingPlanId: plan.id,
            owner,
            requestedAt: plan.deletionRequestedAt,
          }),
        );
      }
    });
    return this.plans.findOne(currentUser, weddingPlanId);
  }

  private async lockOwnedPlan(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ) {
    // An archived plan is read, not managed: the owner's read lock is the
    // lifecycle lock, taken in the account → plan order.
    const context = await this.permissions.assertPlanReadableForUserUpdateInTransaction(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (!context.isOwner) {
      throw new ForbiddenException({
        statusCode: 403,
        code: "PLAN_DELETE_OWNER_ONLY",
        message: "حذف الخطة لصاحبها بس.",
      });
    }
    return context.plan;
  }

  private async ownerVoice(
    tx: Prisma.TransactionClient,
    plan: { ownerUserId: string; persona: WeddingPersona | null },
  ) {
    const [owner] = await this.users.getAppIdentities(tx, [plan.ownerUserId]);
    return {
      name: owner ? applicationDisplayName(owner) : null,
      persona: plan.persona,
    };
  }
}
