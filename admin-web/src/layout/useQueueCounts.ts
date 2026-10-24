import { useEffect, useState } from 'react';
import { AdminPermission, hasAdminPermission, type AdminUser } from '../features/auth/api';
import { getStats } from '../features/dashboard/api';
import { getConversationReports } from '../features/moderation/api';
import type { AdminQueueCount } from './adminNavigation';

export type QueueCounts = Partial<Record<AdminQueueCount, number>>;

/**
 * The sizes the sidebar shows: pending applications (the dashboard stats),
 * open conversation reports, and the inbox, which holds the queues this
 * admin can act on. A count the server does not give stays hidden.
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

  useEffect(() => {
    let alive = true;
    const pending = canStats
      ? getStats().then((stats) => stats.pendingProviders).catch(() => undefined)
      : Promise.resolve(undefined);
    const open = canReports
      ? getConversationReports({ status: 'OPEN', page: 1, limit: 1 })
          .then((page) => page.total)
          .catch(() => undefined)
      : Promise.resolve(undefined);
    void Promise.all([pending, open]).then(([applications, reports]) => {
      if (!alive) return;
      const inboxParts = [
        actsOnApplications ? applications : 0,
        actsOnReports ? reports : 0,
      ];
      const inbox = inboxParts.some((part) => part === undefined)
        ? undefined
        : inboxParts.reduce<number>((sum, part) => sum + (part ?? 0), 0);
      setCounts({ applications, reports, inbox });
    });
    return () => {
      alive = false;
    };
  }, [canStats, canReports, actsOnApplications, actsOnReports, refreshKey]);

  return counts;
}
