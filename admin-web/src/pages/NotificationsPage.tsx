import { useEffect, useState } from 'react';
import {
  AdminNotification,
  getCurrentAdminNotifications,
  getCurrentAdminUnreadNotificationCount,
} from '../api/admin';
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
  { value: 'INSTALLMENT_DUE_SOON', label: 'أقساط قريبة' },
  { value: 'INSTALLMENT_OVERDUE', label: 'أقساط متأخرة' },
  { value: 'DEBT_DUE_SOON', label: 'ديون قريبة' },
  { value: 'SHARING_INVITATION', label: 'دعوات مشاركة' },
  { value: 'QUOTE_OFFER_RECEIVED', label: 'عروض مزودين' },
  { value: 'PLAN_UPDATED', label: 'تحديث خطة' },
  { value: 'SYNC_REQUIRED', label: 'مزامنة مطلوبة' },
  { value: 'GENERAL', label: 'عام' },
];

export function NotificationsPage() {
  const [items, setItems] = useState<AdminNotification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [type, setType] = useState('');
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
        getCurrentAdminNotifications({ type, unreadOnly }),
        getCurrentAdminUnreadNotificationCount(),
      ]);
      setItems(notifications);
      setUnreadCount(unread.count);
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'تعذر تحميل إشعارات الحساب.',
      );
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [type, readFilter]);

  if (isLoading) return <LoadingState title="جاري تحميل إشعارات الحساب" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  const filteredItems = items.filter((notification) => {
    if (!search.trim()) return true;
    const query = search.trim().toLowerCase();
    return [
      notification.title,
      notification.body,
      notification.type,
      notification.priority,
      notification.entityType ?? '',
      notification.routeTarget ?? '',
    ]
      .join(' ')
      .toLowerCase()
      .includes(query);
  });

  const highPriorityCount = filteredItems.filter((notification) =>
    ['HIGH', 'URGENT'].includes(notification.priority),
  ).length;
  const unreadVisibleCount = filteredItems.filter(
    (notification) => !notification.readAt,
  ).length;
  const linkedCount = filteredItems.filter(
    (notification) => notification.routeTarget || notification.entityId,
  ).length;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="الإشعارات"
        icon="!"
        title="إشعارات حساب الإدارة"
        description="عرض حقيقي لإشعارات حساب الأدمن الحالي من endpoint الإشعارات الموجود."
        meta={
          <>
            <span>{filteredItems.length} إشعار ظاهر</span>
            <StatusBadge status="OPEN" />
          </>
        }
      />

      <div className="stats-grid">
        <StatCard title="الإشعارات" value={filteredItems.length} tone="gold" />
        <StatCard title="غير مقروءة" value={unreadVisibleCount} tone="info" />
        <StatCard title="إجمالي غير مقروء" value={unreadCount} tone="warning" />
        <StatCard title="أولوية عالية" value={highPriorityCount} tone="danger" />
        <StatCard title="مرتبطة بسجل" value={linkedCount} tone="success" />
      </div>

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            value={search}
            onChange={setSearch}
            onSubmit={load}
            placeholder="بحث بعنوان الإشعار أو نصه"
          />
          <FilterSelect
            label="النوع"
            value={type}
            onChange={setType}
            options={notificationTypeOptions}
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

      <SectionCard
        title="قائمة الإشعارات"
        subtitle="المصدر يعرض إشعارات المستخدم الحالي فقط، ولا يعرض إشعارات كل المستخدمين أو سجل إرسال عام."
      >
        {filteredItems.length === 0 ? (
          <EmptyState
            title="لا توجد إشعارات مطابقة"
            message="لم يرجع endpoint إشعارات للحساب الحالي ضمن الفلاتر المحددة. الصفحة لا تعرض بيانات بديلة."
            tone="api"
          />
        ) : (
          <DataTable
            columns={[
              'الإشعار',
              'النوع',
              'الأولوية',
              'حالة القراءة',
              'الارتباط',
              'التاريخ',
            ]}
            minWidth={1080}
          >
            {filteredItems.map((notification) => (
              <tr key={notification.id}>
                <td>
                  <strong>{notification.title}</strong>
                  <span className="table-subtle">{notification.body}</span>
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
