import {
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { createHash, randomBytes } from "node:crypto";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../../../../platform/database/prisma.service";
import { runRetryableTransaction } from "../../../../platform/database/serializable-transaction";
import type { AuthenticatedUser } from "../../public/identity-session.types";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort,
} from "../../../collaboration/public/collaboration-permission.port";
import { FINANCE_PORT, type FinancePort } from "../../../finance/public/finance.port";
import { GUESTS_PORT, type GuestsPort } from "../../../guests/public/guests.port";
import {
  PROVIDER_READ_PORT,
  type ProviderReadPort,
} from "../../../marketplace/public/provider-read.port";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../../../planning/public/plan-read.port";
import { TASKS_PORT, type TasksPort } from "../../../tasks/public/tasks.port";
import {
  claimDataExport,
  countDataExportsSince,
  createDataExport,
  deleteDataExportsBefore,
  findDataRequestAccounts,
  findExportProfile,
} from "../../infrastructure/data-request.repository";

/** D63 (w40): a download link works once, for this many minutes. */
export const DATA_EXPORT_LINK_MINUTES = 15;
/** At most this many downloads a day for one account. */
export const DATA_EXPORTS_PER_DAY = 5;
const DAY_MS = 24 * 60 * 60 * 1000;
/** The rows of the downloads stay a week, for n06. */
const DATA_EXPORT_KEEP_DAYS = 7;

export interface DataExportLink {
  id: string;
  /** The API path of the download; the app opens it on its API host. */
  downloadPath: string;
  expiresAt: Date;
}

function tokenDigest(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

/**
 * D63 (w40 «نزّل بياناتي», w05 «نزّل نسخة من خطتك قبل الحذف»): the account's
 * own data as one JSON file, made when it is downloaded. The account asks
 * for a link (`POST /users/me/exports`); the link carries a random token
 * (only its digest is kept), works once and expires in fifteen minutes, so
 * it can be opened in the phone's browser with no session. The file holds
 * the account, the plans it owns (their money as the money screen adds it
 * up, the tasks, the guests by name and reply, the members by name and
 * role), the plans it is a member of (title and role), and its provider
 * listing. It never holds another account's phone, a guest's phone, another
 * member's private cost or task, or a conversation.
 */
@Injectable()
export class DataExportService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(PLAN_READ_PORT) private readonly plans: PlanReadPort,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: CollaborationPermissionPort,
    @Inject(FINANCE_PORT) private readonly finance: FinancePort,
    @Inject(TASKS_PORT) private readonly tasks: TasksPort,
    @Inject(GUESTS_PORT) private readonly guests: GuestsPort,
    @Inject(PROVIDER_READ_PORT) private readonly providers: ProviderReadPort,
  ) {}

  async create(currentUser: AuthenticatedUser): Promise<DataExportLink> {
    const now = new Date();
    const token = randomBytes(32).toString("base64url");
    const expiresAt = new Date(now.getTime() + DATA_EXPORT_LINK_MINUTES * 60_000);
    const created = await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const today = await countDataExportsSince(
          tx,
          currentUser.id,
          new Date(now.getTime() - DAY_MS),
        );
        if (today >= DATA_EXPORTS_PER_DAY) {
          throw new HttpException(
            {
              statusCode: HttpStatus.TOO_MANY_REQUESTS,
              code: "EXPORT_RATE_LIMITED",
              message: "Too many downloads today; try again tomorrow",
            },
            HttpStatus.TOO_MANY_REQUESTS,
          );
        }
        return createDataExport(tx, {
          userId: currentUser.id,
          tokenHash: tokenDigest(token),
          createdAt: now,
          expiresAt,
        });
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );
    return {
      id: created.id,
      downloadPath: `/api/v1/data-exports/${token}`,
      expiresAt,
    };
  }

  /** The one download of a link: `404 EXPORT_LINK_INVALID` once used, expired or unknown. */
  async download(token: string): Promise<{ fileName: string; body: unknown }> {
    const now = new Date();
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const claimed = await claimDataExport(tx, tokenDigest(token), now);
        if (!claimed) {
          throw new NotFoundException({
            statusCode: 404,
            code: "EXPORT_LINK_INVALID",
            message: "This link was used or has expired; ask for a new one",
          });
        }
        return {
          fileName: `aarast-${now.toISOString().slice(0, 10)}.json`,
          body: await this.accountData(tx, claimed.userId, now),
        };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  /** The downloads older than a week leave the table (the purge job runs it). */
  async removeOldExports(now: Date): Promise<number> {
    const removed = await deleteDataExportsBefore(
      this.prisma,
      new Date(now.getTime() - DATA_EXPORT_KEEP_DAYS * DAY_MS),
    );
    return removed.count;
  }

  private async accountData(
    tx: Prisma.TransactionClient,
    userId: string,
    now: Date,
  ) {
    const profile = await findExportProfile(tx, userId);
    if (!profile) {
      throw new NotFoundException({
        statusCode: 404,
        code: "EXPORT_LINK_INVALID",
        message: "This link was used or has expired; ask for a new one",
      });
    }
    const ownedPlans = await this.plans.listOwnedPlans(tx, userId);
    const members = await this.permissions.listPlanMembers(
      tx,
      ownedPlans.map((plan) => plan.id),
    );
    const memberNames = await findDataRequestAccounts(
      tx,
      members.map((member) => member.userId),
    );
    const plans = [];
    for (const plan of ownedPlans) {
      plans.push({
        id: plan.id,
        title: plan.title,
        status: plan.status,
        persona: plan.persona,
        city: plan.city,
        weddingDate: plan.weddingDate,
        currency: plan.currency,
        estimatedBudget: plan.estimatedBudget?.toString() ?? null,
        createdAt: plan.createdAt,
        members: members
          .filter((member) => member.weddingPlanId === plan.id)
          .map((member) => ({
            name: memberNames.get(member.userId)?.name ?? null,
            role: member.role,
          })),
        money: await this.finance.readMoneyPicture(tx, {
          weddingPlanId: plan.id,
          persona: plan.persona,
          totalBudget: plan.estimatedBudget,
          scope: null,
          readerUserId: userId,
          fundingVisible: true,
          now,
        }),
        tasks: await this.tasks.listReadableTasks(tx, plan.id, userId),
        guests: (await this.guests.listReadableGuests(tx, plan.id)).map((guest) => ({
          name: guest.name,
          attendanceStatus: guest.attendanceStatus,
        })),
      });
    }
    const ownedIds = new Set(ownedPlans.map((plan) => plan.id));
    const memberships = (await this.permissions.listMemberships(tx, userId)).filter(
      (membership) => !ownedIds.has(membership.weddingPlanId),
    );
    const memberOf = await this.plans.getPlans(
      tx,
      memberships.map((membership) => membership.weddingPlanId),
    );
    const provider = await this.providers.getProviderByUserId(tx, userId);
    return {
      format: "aarast-account-data",
      version: 1,
      exportedAt: now,
      account: {
        name: profile.name,
        phone: profile.phone,
        email: profile.email,
        persona: profile.persona,
        locale: profile.locale,
        reviewFirstNameOnly: profile.reviewFirstNameOnly,
        createdAt: profile.createdAt,
        deletionScheduledFor: profile.deletionScheduledFor,
      },
      plans,
      memberOfPlans: memberships.map((membership) => ({
        title:
          memberOf.find((plan) => plan.id === membership.weddingPlanId)?.title ?? null,
        role: membership.role,
        since: membership.createdAt,
      })),
      provider: provider
        ? {
            businessName: provider.businessName,
            status: provider.status,
            createdAt: provider.createdAt,
          }
        : null,
    };
  }
}
