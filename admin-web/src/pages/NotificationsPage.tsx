import { useEffect, useState } from 'react';
import {
  AdminNotification,
  archiveAdminNotification,
  deleteAdminNotification,
  getAdminNotifications,
  getAdminUnreadNotificationCount,
  markAdminNotificationRead,
} from '../api/admin';
import { ActionButton } from '../components/ActionButton';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { FilterSelect } from '../components/FilterSelect';
import { LoadingState } from '../components/LoadingState';
import { PageHeader } from '../components/PageHeader';
import { Pagination } from '../components/Pagination';
import { SearchInput } from '../components/SearchInput';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge, statusLabel } from '../components/StatusBadge';
import { TableToolbar } from '../components/TableToolbar';
import { Can } from '../auth/Can';
import { AdminPermission } from '../auth/adminPermissions';

const notificationTypeOptions = [
  { value: '', label: 'كل الأنواع' },
  { value: 'QUOTE_REQUEST_SUBMITTED', label: 'طلبات عروض' },
  { value: 'TASK_DUE_SOON', label: 'مهام قريبة' },
  { value: 'TASK_OVERDUE', label: 'مهام متأخرة' },
  { value: 'PAYMENT_SCHEDULE_DUE_SOON', label: 'مواعيد دفع قريبة' },
  { value: 'PAYMENT_SCHEDULE_OVERDUE', label: 'مواعيد دفع متأخرة' },
  { value: 'SHARING_INVITATION', label: 'دعوات مشاركة' },
  { value: 'QUOTE_OFFER_RECEIVED', label: 'عروض موردين' },
  { value: 'PLAN_UPDATED', label: 'تحديث خطة' },
  { value: 'SYNC_REQUIRED', label: 'مزامنة مطلوبة' },
  { value: 'GENERAL', label: 'عام' },
];

export function NotificationsPage() {
  const [items, setItems] = useState<AdminNotification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [type, setType] = useState('');
  const [priority, setPriority] = useState('');
  const [readFilter, setReadFilter] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [pagination, setPagination] = useState({
    page: 1,
    limit: 20,
    total: 0,
    totalPages: 1,
  });
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const unreadOnly = readFilter === 'unread' ? true : undefined;
      const [notifications, unread] = await Promise.all([
        getAdminNotifications({
          type,
          priority,
          unreadOnly,
          search,
          page,
          limit: 20,
        }),
        getAdminUnreadNotificationCount(),
      ]);
      if (page > notifications.totalPages) {
        setPage(notifications.totalPages);
        return;
      }
      setItems(notifications.items);
      setPagination({
        page: notifications.page,
        limit: notifications.limit,
        total: notifications.total,
        totalPages: notifications.totalPages,
      });
      setUnreadCount(unread.count);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل سجل الإشعارات.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [type, priority, readFilter, page]);

  function submitSearch() {
    if (page === 1) void load();
    else setPage(1);
  }

  async function markRead(notification: AdminNotification) {
    setError(null);
    try {
      await markAdminNotificationRead(notification.id);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تعليم الإشعار كمقروء.');
    }
  }

  async function archive(notification: AdminNotification) {
    setError(null);
    try {
      await archiveAdminNotification(notification.id);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر أرشفة الإشعار.');
    }
  }

  async function remove(notification: AdminNotification) {
    setError(null);
    try {
      await deleteAdminNotification(notification.id);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر حذف الإشعار.');
    }
  }

  if (isLoading) return <LoadingState title="جاري تحميل سجل الإشعارات" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  const unreadVisibleCount = items.filter((notification) => !notification.readAt).length;
  const highPriorityCount = items.filter((notification) =>
    ['HIGH', 'URGENT'].includes(notification.priority),
  ).length;
  const archivedCount = items.filter((notification) => notification.archivedAt).length;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="الإشعارات"
        icon="!"
        title="سجل إشعارات النظام"
        description="عرض إداري حقيقي من /admin/notifications لكل المستخدمين مع القراءة والأرشفة والحذف الإداري."
        meta={<span>{pagination.total} إشعار مطابق</span>}
      />

      <div className="stats-grid">
        <StatCard title="عناصر الصفحة" value={items.length} tone="gold" />
        <StatCard title="غير مقروءة في الصفحة" value={unreadVisibleCount} tone="info" />
        <StatCard title="إجمالي غير مقروء" value={unreadCount} tone="warning" />
        <StatCard title="عالية في الصفحة" value={highPriorityCount} tone="danger" />
        <StatCard title="مؤرشفة في الصفحة" value={archivedCount} tone="success" />
      </div>

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            label="بحث في الإشعارات"
            value={search}
            onChange={setSearch}
            onSubmit={submitSearch}
            placeholder="بحث بعنوان الإشعار أو المستخدم"
          />
          <FilterSelect
            label="النوع"
            value={type}
            onChange={(value) => {
              setType(value);
              setPage(1);
            }}
            options={notificationTypeOptions}
          />
          <FilterSelect
            label="الأولوية"
            value={priority}
            onChange={(value) => {
              setPriority(value);
              setPage(1);
            }}
            options={[
              { value: '', label: 'كل الأولويات' },
              { value: 'LOW', label: 'منخفضة' },
              { value: 'NORMAL', label: 'عادية' },
              { value: 'HIGH', label: 'عالية' },
              { value: 'URGENT', label: 'عاجلة' },
            ]}
          />
          <FilterSelect
            label="القراءة"
            value={readFilter}
            onChange={(value) => {
              setReadFilter(value);
              setPage(1);
            }}
            options={[
              { value: '', label: 'كل الإشعارات' },
              { value: 'unread', label: 'غير المقروءة فقط' },
            ]}
          />
        </TableToolbar>
      </SectionCard>

      <SectionCard title="قائمة الإشعارات" subtitle="المصدر إداري عام، وليس إشعارات الحساب الحالي فقط.">
        {items.length === 0 ? (
          <EmptyState title="لا توجد إشعارات مطابقة" message="غير الفلاتر أو ابحث بكلمة أخرى." tone="api" />
        ) : (
          <DataTable
            label="قائمة الإشعارات الإدارية"
            columns={['الإشعار', 'المستخدم', 'النوع', 'الأولوية', 'القراءة', 'الارتباط', 'التاريخ', 'إجراءات']}
            minWidth={1180}
          >
            {items.map((notification) => (
              <tr key={notification.id}>
                <td>
                  <strong>{notification.title}</strong>
                  <span className="table-subtle">{notification.body}</span>
                </td>
                <td>
                  <strong>{notification.user?.name ?? notification.userId}</strong>
                  <span className="table-subtle" dir="ltr">
                    {notification.user?.phoneMasked ?? ''}
                  </span>
                </td>
                <td>{typeLabel(notification.type)}</td>
                <td>
                  <StatusBadge status={notification.priority} />
                </td>
                <td>
                  <StatusBadge status={notification.readAt ? 'READ' : 'UNREAD'} />
                </td>
                <td>
                  {notification.entityType ?? 'غير مرتبط'}
                  <span className="table-subtle" dir="ltr">
                    {notification.routeTarget ?? notification.entityId ?? ''}
                  </span>
                </td>
                <td>{formatDate(notification.createdAt)}</td>
                <td className="actions-cell">
                  <Can permission={AdminPermission.NOTIFICATIONS_WRITE}>
                    {!notification.readAt ? (
                    <ActionButton tone="ghost" size="small" onClick={() => markRead(notification)}>
                      قراءة
                    </ActionButton>
                    ) : null}
                    {!notification.archivedAt ? (
                    <ActionButton tone="ghost" size="small" onClick={() => archive(notification)}>
                      أرشفة
                    </ActionButton>
                    ) : null}
                    <ActionButton tone="danger" size="small" onClick={() => remove(notification)}>
                      حذف
                    </ActionButton>
                  </Can>
                </td>
              </tr>
            ))}
          </DataTable>
        )}
        <Pagination
          page={pagination.page}
          limit={pagination.limit}
          total={pagination.total}
          totalPages={pagination.totalPages}
          onPageChange={setPage}
        />
      </SectionCard>
    </section>
  );
}

function typeLabel(type: string) {
  const match = notificationTypeOptions.find((option) => option.value === type);
  return match?.label ?? statusLabel(type);
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('ar-YE', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}
