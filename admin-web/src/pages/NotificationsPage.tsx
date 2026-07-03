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
import { SearchInput } from '../components/SearchInput';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge, statusLabel } from '../components/StatusBadge';
import { TableToolbar } from '../components/TableToolbar';

const notificationTypeOptions = [
  { value: '', label: 'كل الأنواع' },
  { value: 'QUOTE_REQUEST_SUBMITTED', label: 'طلبات عروض' },
  { value: 'TASK_DUE_SOON', label: 'مهام قريبة' },
  { value: 'TASK_OVERDUE', label: 'مهام متأخرة' },
  { value: 'INSTALLMENT_DUE_SOON', label: 'دفعات قريبة' },
  { value: 'INSTALLMENT_OVERDUE', label: 'دفعات متأخرة' },
  { value: 'DEBT_DUE_SOON', label: 'مبالغ باقية' },
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
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const unreadOnly = readFilter === 'unread' ? true : undefined;
      const [notifications, unread] = await Promise.all([
        getAdminNotifications({ type, priority, unreadOnly, search, limit: 100 }),
        getAdminUnreadNotificationCount(),
      ]);
      setItems(notifications.items);
      setUnreadCount(unread.count);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل سجل الإشعارات.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [type, priority, readFilter]);

  async function markRead(notification: AdminNotification) {
    await markAdminNotificationRead(notification.id);
    await load();
  }

  async function archive(notification: AdminNotification) {
    await archiveAdminNotification(notification.id);
    await load();
  }

  async function remove(notification: AdminNotification) {
    await deleteAdminNotification(notification.id);
    await load();
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
        meta={<span>{items.length} إشعار معروض</span>}
      />

      <div className="stats-grid">
        <StatCard title="المعروضة" value={items.length} tone="gold" />
        <StatCard title="غير مقروءة" value={unreadVisibleCount} tone="info" />
        <StatCard title="إجمالي غير مقروء" value={unreadCount} tone="warning" />
        <StatCard title="أولوية عالية" value={highPriorityCount} tone="danger" />
        <StatCard title="مؤرشفة" value={archivedCount} tone="success" />
      </div>

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            value={search}
            onChange={setSearch}
            onSubmit={load}
            placeholder="بحث بعنوان الإشعار أو المستخدم"
          />
          <FilterSelect label="النوع" value={type} onChange={setType} options={notificationTypeOptions} />
          <FilterSelect
            label="الأولوية"
            value={priority}
            onChange={setPriority}
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
            onChange={setReadFilter}
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
                    {notification.user?.phone ?? ''}
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
                </td>
              </tr>
            ))}
          </DataTable>
        )}
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
