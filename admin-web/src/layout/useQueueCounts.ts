import { useEffect, useState } from 'react';
import { AdminPermission, hasAdminPermission, type AdminUser } from '../features/auth/api';
import { getStats } from '../features/dashboard/api';
import {
  getAssistantReports,
  getConversationReports,
  getPortfolioPhotos,
  getReviews,
} from '../features/moderation/api';
import { getDataRequests } from '../features/users/api';
import { getProfileChanges } from '../features/providers/api';
import type { AdminQueueCount } from './adminNavigation';

export type QueueCounts = Partial<Record<AdminQueueCount, number>>;

/**
 * The sizes the sidebar shows: pending applications and claims of a listing
 * (the dashboard stats, B-12), open reports (the chats' and the assistant
 * answers'), and the inbox, which holds the queues this admin can act on
 * (RA-AD-27: with the photos waiting, the reported reviews, the failed
 * deletions and the provider profile changes waiting, which «تعديلات
 * الملفات» shows too). A count the server does not give stays hidden.
 */
export function useQueueCounts(
  user: Pick<AdminUser, 'adminPermissions'> | null | undefined,
  refreshKey: string,
): QueueCounts {
  const [counts, setCounts] = useState<QueueCounts>({});
  const canStats = hasAdminPermission(user, AdminPermission.DASHBOARD_READ);
  const canReports = hasAdminPermission(user, AdminPermission.CONVERSATION_REPORTS_READ);
  const actsOnApplications = hasAdminPermission(user, AdminPermission.PROVIDERS_WRITE);
  const actsOnReports = hasAdminPermission(user, AdminPermission.CONVERSATION_REPORTS_WRITE);
  const actsOnReviews = hasAdminPermission(user, AdminPermission.REVIEWS_WRITE);
  const actsOnAccounts = hasAdminPermission(user, AdminPermission.USERS_WRITE);

  useEffect(() => {
    let alive = true;
    const stats = canStats
      ? getStats().catch(() => undefined)
      : Promise.resolve(undefined);
    const total = (page: Promise<{ total: number }>) =>
      page.then((value) => value.total).catch(() => undefined);
    const nothing = Promise.resolve(0);
    // RA-ST-04 (D95): «البلاغات» holds the chats' and the assistant answers'.
    const chats = canReports
      ? total(getConversationReports({ status: 'OPEN', page: 1, limit: 1 }))
      : Promise.resolve(undefined);
    const answers = canReports
      ? total(getAssistantReports({ status: 'OPEN', page: 1, limit: 1 }))
      : Promise.resolve(undefined);
    const photos = actsOnReviews
      ? total(getPortfolioPhotos({ status: 'PENDING', page: 1, limit: 1 }))
      : nothing;
    const reviews = actsOnReviews
      ? total(getReviews({ reported: 'true', page: 1, limit: 1 }))
      : nothing;
    // RA-AD-27: a profile change is decided with PROVIDERS_WRITE.
    const profileChanges = actsOnApplications
      ? total(getProfileChanges({ status: 'PENDING', page: 1, limit: 1 }))
      : Promise.resolve(undefined);
    const failures = actsOnAccounts
      ? getDataRequests()
          .then(({ deletions }) => deletions.filter((row) => row.purgeFailedAt !== null).length)
          .catch(() => undefined)
      : nothing;
    void Promise.all([stats, chats, answers, photos, reviews, failures, profileChanges]).then(
      ([read, chatReports, answerReports, photoCount, reviewCount, failureCount, changeCount]) => {
        if (!alive) return;
        const applications = read?.pendingProviders;
        const claims = read?.pendingClaims;
        const reports =
          chatReports === undefined || answerReports === undefined
            ? undefined
            : chatReports + answerReports;
        // RA-AD-08: «الصندوق» counts what it lists.
        const inboxParts = [
          actsOnApplications ? applications : 0,
          actsOnApplications ? claims : 0,
          actsOnApplications ? changeCount : 0,
          actsOnReports ? chatReports : 0,
          actsOnReports ? answerReports : 0,
          photoCount,
          reviewCount,
          failureCount,
        ];
        const inbox = inboxParts.some((part) => part === undefined)
          ? undefined
          : inboxParts.reduce<number>((sum, part) => sum + (part ?? 0), 0);
        setCounts({ applications, claims, profileChanges: changeCount, reports, inbox });
      },
    );
    return () => {
      alive = false;
    };
  }, [canStats, canReports, actsOnApplications, actsOnReports, actsOnReviews, actsOnAccounts, refreshKey]);

  return counts;
}
