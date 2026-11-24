import { NotFoundException } from '@nestjs/common';
import type { PrismaService } from '../platform/database/prisma.service';
import type { AdminConversationReportView, AdminOwners } from './admin-owners';
import { toUserResponse } from './admin.presenter';

/** The latest chat reports the account page lists, filed by him or on him. */
const ACCOUNT_REPORTS_SHOWN = 20;

type AccountReport = {
  id: string;
  reason: string;
  status: AdminConversationReportView['status'];
  createdAt: Date;
  direction: 'FILED' | 'AGAINST';
  /** The other party: a business, or the person's name. */
  counterpart: string;
};

/**
 * A report about this account, from its side: one he filed, one a business
 * filed on him as its customer, or one filed on his own business. A report
 * by another member of his plan on a business is not about him.
 */
function accountReport(
  report: AdminConversationReportView,
  userId: string,
  providerId: string | null,
): AccountReport | null {
  const base = {
    id: report.id,
    reason: report.reason,
    status: report.status,
    createdAt: report.createdAt,
  };
  const reported = report.reported;
  if (report.reporter.id === userId) {
    const counterpart =
      reported.kind === 'PROVIDER'
        ? reported.provider.businessName
        : reported.user?.name ?? 'حساب محذوف';
    return { ...base, direction: 'FILED', counterpart };
  }
  if (reported.kind === 'CUSTOMER' && reported.user?.id === userId) {
    return { ...base, direction: 'AGAINST', counterpart: report.conversation.provider.businessName };
  }
  if (reported.kind === 'PROVIDER' && providerId !== null && reported.provider.id === providerId) {
    return { ...base, direction: 'AGAINST', counterpart: report.reporter.name };
  }
  return null;
}

/**
 * a13 (RA-AD-25): an account as the back office reads it: the account and
 * his business, the plans he owns or shares (title, status and day only:
 * no money, no guests), the chat reports filed by him or on him, and his
 * live sessions per realm with the last sign-in.
 */
export class AdminUserDetails {
  constructor(
    private readonly deps: { prisma: PrismaService; owners: AdminOwners },
  ) {}

  async get(id: string, now = new Date()) {
    const { owners } = this.deps;
    const found = await this.deps.prisma.$transaction(async (tx) => {
      const row = await owners.accounts.getAccount(tx, id);
      if (!row) return null;
      const [user] = await owners.attachAccounts(tx, [row]);
      const providerId = user!.providerProfile?.id ?? null;
      const [owned, memberPlanIds, reportRows, sessions] = await Promise.all([
        owners.plans.listOwnedPlans(tx, id),
        owners.collaboration.listMemberPlanIds(tx, id),
        owners.messaging.listAccountConversationReports(
          tx,
          { userId: id, providerId },
          ACCOUNT_REPORTS_SHOWN,
        ),
        owners.accounts.getAccountSessions(tx, id, now),
      ]);
      const ownedIds = new Set(owned.map((plan) => plan.id));
      const shared = await owners.plans.getPlans(
        tx,
        memberPlanIds.filter((planId) => !ownedIds.has(planId)),
      );
      const reports = await owners.attachConversationReports(tx, reportRows);
      return { user: user!, providerId, owned, shared, reports, sessions };
    });
    if (!found) throw new NotFoundException('User not found');

    const plan = (role: 'OWNER' | 'MEMBER') =>
      (row: { id: string; title: string; status: string; weddingDate: Date | null }) => ({
        id: row.id,
        title: row.title,
        status: row.status,
        weddingDate: row.weddingDate,
        role,
      });
    return {
      ...toUserResponse(found.user),
      plans: [...found.owned.map(plan('OWNER')), ...found.shared.map(plan('MEMBER'))],
      reports: found.reports.flatMap(
        (report) => accountReport(report, id, found.providerId) ?? [],
      ),
      sessions: found.sessions,
    };
  }
}
