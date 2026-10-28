import {
  BadRequestException,
  ConflictException,
  HttpException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../../../../platform/database/prisma.service";
import { runRetryableTransaction } from "../../../../platform/database/serializable-transaction";
import type { AuthenticatedUser } from "../../public/identity-session.types";
import type {
  AccountDeletionAdminPort,
  AdminDataExportRow,
  AdminPendingDeletionRow,
} from "../../public/account-deletion-admin.port";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort,
} from "../../../collaboration/public/collaboration-permission.port";
import {
  MARKETPLACE_ERASURE_PORT,
  type MarketplaceErasurePort,
} from "../../../marketplace/public/marketplace-erasure.port";
import {
  PROVIDER_READ_PORT,
  type ProviderReadPort,
} from "../../../marketplace/public/provider-read.port";
import {
  MESSAGING_REALTIME_PORT,
  type MessagingRealtimePort,
} from "../../../messaging/public/messaging-realtime.port";
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../../../notifications/public/notifications.port";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../../../planning/public/plan-read.port";
import {
  clearAccountDeletionRequest,
  findDueAccountDeletionIds,
  lockUserForAccountDeletion,
  markAccountDeletionRequested,
  recordAccountPurgeFailure,
} from "../../infrastructure/account-erasure.repository";
import {
  findDataRequestAccounts,
  listPendingAccountDeletions,
  listRecentDataExports,
} from "../../infrastructure/data-request.repository";
import {
  planClosedForDeletionNotice,
  planReopenedNotice,
} from "./account-deletion-notices";
import { UsersService } from "./users.service";

/** D63: the days an account waits before it is erased (w05, w06, C4). */
export const ACCOUNT_DELETION_GRACE_DAYS = 30;
/** w05: the word the account types to confirm. */
export const ACCOUNT_DELETION_CONFIRM_WORD = "حذف";
const DAY_MS = 24 * 60 * 60 * 1000;
/** The purge takes this many due accounts a run; the rest wait an hour. */
const PURGE_BATCH = 25;
/** n06 lists the downloads of the last week. */
const EXPORT_LIST_DAYS = 7;

export type AccountDeletionState =
  | { status: "PENDING"; requestedAt: Date; scheduledFor: Date }
  | { status: "NONE"; requestedAt: null; scheduledFor: null };

export interface AccountDeletionImpact {
  graceDays: number;
  /** The plans the account owns: they go with it, and their members are told. */
  ownedPlans: Array<{
    id: string;
    title: string;
    /** The members' first names, as w05 says «صالح والوالد». */
    memberNames: string[];
    /** Confirmed bookings from today on, cancelled at the erasure. */
    upcomingBookings: number;
  }>;
  /** Other people's plans the account is a member of; it leaves them. */
  memberOfPlans: number;
  /** The account's provider listing, and the weddings it still has to do. */
  provider: { businessName: string; upcomingBookings: number } | null;
  /** B-33: why the request is refused now, or null. */
  blockedBy: "PROVIDER_HAS_UPCOMING_BOOKINGS" | null;
}

export interface AccountPurgeSummary {
  erased: number;
  failures: Array<{ userId: string; code: string; error: unknown }>;
}

function firstName(name: string | null | undefined): string | null {
  return name?.trim().split(/\s+/u)[0] || null;
}

function errorCode(error: unknown): string {
  if (error instanceof HttpException) {
    const body = error.getResponse();
    if (typeof body === "object" && body && "code" in body) {
      const code = (body as { code?: unknown }).code;
      if (typeof code === "string" && code) return code;
    }
    return `HTTP_${error.getStatus()}`;
  }
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    return `PRISMA_${error.code}`;
  }
  return "UNEXPECTED_ERROR";
}

/**
 * D63: an account asks to be deleted, waits 30 days and may take the request
 * back; the hourly purge then erases it through the one erasure saga
 * (`UsersService.eraseDueAccount`). While it waits the account reads only
 * w06 (`JwtAuthGuard`), its plans are closed to their members, and nobody
 * is reminded of anything.
 */
@Injectable()
export class AccountDeletionService implements AccountDeletionAdminPort {
  private readonly logger = new Logger(AccountDeletionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    @Inject(PLAN_READ_PORT) private readonly plans: PlanReadPort,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: CollaborationPermissionPort,
    @Inject(MARKETPLACE_ERASURE_PORT)
    private readonly marketplaceErasure: MarketplaceErasurePort,
    @Inject(PROVIDER_READ_PORT) private readonly providers: ProviderReadPort,
    @Inject(NOTIFICATIONS_PORT) private readonly notifications: NotificationsPort,
    @Optional()
    @Inject(MESSAGING_REALTIME_PORT)
    private readonly realtime?: MessagingRealtimePort,
  ) {}

  /** w05: what the deletion takes with it, and whether B-33 refuses it now. */
  async impact(currentUser: AuthenticatedUser): Promise<AccountDeletionImpact> {
    const now = new Date();
    return runRetryableTransaction(this.prisma, async (tx) => {
      const ownedPlans = await this.plans.listOwnedPlans(tx, currentUser.id);
      const members = await this.permissions.listPlanMembers(
        tx,
        ownedPlans.map((plan) => plan.id),
      );
      const memberAccounts = await findDataRequestAccounts(
        tx,
        members.map((member) => member.userId),
      );
      const memberships = await this.permissions.listMemberships(tx, currentUser.id);
      const ownedIds = new Set(ownedPlans.map((plan) => plan.id));
      const provider = await this.providers.getProviderByUserId(tx, currentUser.id);
      const providerBookings = provider
        ? (
            await this.marketplaceErasure.lockUpcomingConfirmedBookingIdsInTransaction(
              tx,
              [provider.id],
              now,
            )
          ).length
        : 0;
      const plansOut: AccountDeletionImpact["ownedPlans"] = [];
      for (const plan of ownedPlans) {
        plansOut.push({
          id: plan.id,
          title: plan.title,
          memberNames: members
            .filter((member) => member.weddingPlanId === plan.id)
            .map((member) => firstName(memberAccounts.get(member.userId)?.name))
            .filter((name): name is string => name !== null),
          upcomingBookings: await this.marketplaceErasure.countUpcomingPlanBookings(
            tx,
            [plan.id],
            now,
          ),
        });
      }
      return {
        graceDays: ACCOUNT_DELETION_GRACE_DAYS,
        ownedPlans: plansOut,
        memberOfPlans: memberships.filter(
          (membership) => !ownedIds.has(membership.weddingPlanId),
        ).length,
        provider: provider
          ? { businessName: provider.businessName, upcomingBookings: providerBookings }
          : null,
        blockedBy: providerBookings > 0 ? "PROVIDER_HAS_UPCOMING_BOOKINGS" : null,
      };
    });
  }

  /** w06: read from the account row the session was just checked against. */
  status(currentUser: AuthenticatedUser): AccountDeletionState {
    return stateOf({
      deletionRequestedAt: currentUser.deletionRequestedAt ?? null,
      deletionScheduledFor: currentUser.deletionScheduledFor ?? null,
    });
  }

  /**
   * w05 «احذف حسابي»: the account will be erased in 30 days. Asking again
   * while it waits answers the same request (a lost answer is safe to retry).
   * B-33: a provider with weddings still to do is refused, as at the purge.
   */
  async request(
    currentUser: AuthenticatedUser,
    confirmWord: string,
  ): Promise<AccountDeletionState> {
    if (confirmWord.trim() !== ACCOUNT_DELETION_CONFIRM_WORD) {
      throw new BadRequestException({
        statusCode: 400,
        code: "CONFIRM_WORD_MISMATCH",
        message: `Type «${ACCOUNT_DELETION_CONFIRM_WORD}» to confirm`,
      });
    }
    const userId = currentUser.id;
    const state = await runRetryableTransaction(
      this.prisma,
      async (tx): Promise<AccountDeletionState> => {
        const [account] = await lockUserForAccountDeletion(tx, userId);
        if (!account) throw new NotFoundException("User not found");
        const current = stateOf(account);
        if (current.status === "PENDING") return current;

        const providerIds = await this.marketplaceErasure.listOwnedProviderIds(
          tx,
          userId,
        );
        const now = new Date();
        const upcoming =
          await this.marketplaceErasure.lockUpcomingConfirmedBookingIdsInTransaction(
            tx,
            providerIds,
            now,
          );
        if (upcoming.length > 0) {
          throw new ConflictException({
            statusCode: 409,
            code: "PROVIDER_HAS_UPCOMING_BOOKINGS",
            message: "Hand over or cancel the upcoming bookings first",
            count: upcoming.length,
            bookingIds: upcoming,
          });
        }
        const scheduledFor = new Date(
          now.getTime() + ACCOUNT_DELETION_GRACE_DAYS * DAY_MS,
        );
        await markAccountDeletionRequested(tx, userId, now, scheduledFor);
        const planIds = await this.plans.listOwnedPlanIds(tx, userId);
        for (const member of await this.permissions.listPlanMembers(tx, planIds)) {
          await this.notifications.createNotificationInTransaction(
            tx,
            planClosedForDeletionNotice({
              memberUserId: member.userId,
              weddingPlanId: member.weddingPlanId,
              owner: { name: account.name, persona: account.persona },
              scheduledFor,
              requestedAt: now,
            }),
          );
        }
        return { status: "PENDING", requestedAt: now, scheduledFor };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted },
    );
    // A waiting account holds no live channel (its plans are closed).
    this.realtime?.disconnectUser(userId);
    return state;
  }

  /** w06 «تراجعت، رجّع حسابي»: the account and its plans are back, as they were. */
  async cancel(currentUser: AuthenticatedUser): Promise<AccountDeletionState> {
    await runRetryableTransaction(
      this.prisma,
      (tx) => this.restoreAccountDeletionInTransaction(tx, currentUser.id),
      { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted },
    );
    return { status: "NONE", requestedAt: null, scheduledFor: null };
  }

  async restoreAccountDeletionInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    const [account] = await lockUserForAccountDeletion(tx, userId);
    if (!account) throw new NotFoundException("User not found");
    if (!account.deletionRequestedAt || !account.deletionScheduledFor) {
      throw new ConflictException({
        statusCode: 409,
        code: "DELETION_NOT_PENDING",
        message: "This account is not waiting to be deleted",
      });
    }
    await clearAccountDeletionRequest(tx, userId);
    const planIds = await this.plans.listOwnedPlanIds(tx, userId);
    for (const member of await this.permissions.listPlanMembers(tx, planIds)) {
      await this.notifications.createNotificationInTransaction(
        tx,
        planReopenedNotice({
          memberUserId: member.userId,
          weddingPlanId: member.weddingPlanId,
          owner: { name: account.name, persona: account.persona },
          requestedAt: account.deletionRequestedAt,
        }),
      );
    }
  }

  async listDataRequests(
    client: Prisma.TransactionClient,
    now: Date,
  ): Promise<{ deletions: AdminPendingDeletionRow[]; exports: AdminDataExportRow[] }> {
    const [pending, exports] = await Promise.all([
      listPendingAccountDeletions(client),
      listRecentDataExports(
        client,
        new Date(now.getTime() - EXPORT_LIST_DAYS * DAY_MS),
      ),
    ]);
    const providerOwners = new Set(
      (
        await Promise.all(
          pending.map(async (row) =>
            (await this.marketplaceErasure.listOwnedProviderIds(client, row.id))
              .length > 0
              ? row.id
              : null,
          ),
        )
      ).filter((id): id is string => id !== null),
    );
    return {
      deletions: pending.map((row) => ({
        userId: row.id,
        name: row.name,
        phone: row.phone,
        providerAccount: providerOwners.has(row.id),
        requestedAt: row.deletionRequestedAt!,
        scheduledFor: row.deletionScheduledFor!,
        purgeFailedAt: row.deletionPurgeFailedAt,
        purgeFailure: row.deletionPurgeFailure,
      })),
      exports: exports.map((row) => ({
        id: row.id,
        userId: row.userId,
        name: row.user.name,
        phone: row.user.phone,
        createdAt: row.createdAt,
        expiresAt: row.expiresAt,
        downloadedAt: row.downloadedAt,
      })),
    };
  }

  /**
   * The hourly purge: every account whose day has come is erased through the
   * one saga. A failure (B-33 at the purge, a database error) is recorded on
   * the account for n06, returned and logged by the job; the account stays
   * pending and the next run tries again.
   */
  async purgeDueAccounts(now: Date): Promise<AccountPurgeSummary> {
    const due = await findDueAccountDeletionIds(this.prisma, now, PURGE_BATCH);
    const summary: AccountPurgeSummary = { erased: 0, failures: [] };
    for (const { id } of due) {
      try {
        const outcome = await this.users.eraseDueAccount(id, now);
        if (outcome === "ERASED") summary.erased += 1;
      } catch (error) {
        const code = errorCode(error);
        summary.failures.push({ userId: id, code, error });
        try {
          await recordAccountPurgeFailure(this.prisma, id, now, code);
        } catch (recordError) {
          // The purge failure itself is already in the summary; losing its
          // trace on the account is a second failure, reported on its own.
          summary.failures.push({
            userId: id,
            code: "PURGE_FAILURE_NOT_RECORDED",
            error: recordError,
          });
        }
      }
    }
    if (due.length === PURGE_BATCH) {
      this.logger.warn(
        `The account purge took its batch of ${PURGE_BATCH}; the rest wait for the next run`,
      );
    }
    return summary;
  }
}

function stateOf(account: {
  deletionRequestedAt: Date | null;
  deletionScheduledFor: Date | null;
}): AccountDeletionState {
  return account.deletionRequestedAt && account.deletionScheduledFor
    ? {
        status: "PENDING",
        requestedAt: account.deletionRequestedAt,
        scheduledFor: account.deletionScheduledFor,
      }
    : { status: "NONE", requestedAt: null, scheduledFor: null };
}
