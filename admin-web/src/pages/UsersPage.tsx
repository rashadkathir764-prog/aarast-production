import { useEffect, useState } from 'react';
import { getUsers } from '../api/admin';
import { AdminUser } from '../api/auth';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { PageHeader } from '../components/PageHeader';
import { RoleBadge } from '../components/RoleBadge';
import { SearchInput } from '../components/SearchInput';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate } from './providerHelpers';

type UserRow = AdminUser & {
  provider?: {
    id: string;
    businessName: string;
    status: string;
  } | null;
};

export function UsersPage() {
  const [items, setItems] = useState<UserRow[]>([]);
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const result = await getUsers({ search, limit: 50 });
      setItems(result.items as UserRow[]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل المستخدمين.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  if (isLoading) return <LoadingState title="جاري تحميل المستخدمين" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  const adminCount = items.filter((user) => user.role === 'ADMIN').length;
  const providerCount = items.filter((user) => user.role === 'PROVIDER').length;
  const regularCount = items.filter((user) => user.role === 'USER').length;
  const activeCount = items.filter((user) => user.status === 'ACTIVE').length;
  const roleDistribution = [
    { label: 'إدارة', value: adminCount, tone: 'gold' },
    { label: 'موردون', value: providerCount, tone: 'info' },
    { label: 'مستخدمون', value: regularCount, tone: 'success' },
  ];

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="المستخدمون"
        icon="♙"
        title="حسابات المستخدمين دون بيانات حساسة"
        description="عرض الحسابات والأدوار والحالة العامة فقط. لا يتم عرض كلمات مرور أو OTP أو رموز جلسات."
        meta={<span>{items.length} حساب معروض</span>}
      />

      <div className="stats-grid">
        <StatCard title="الحسابات" value={items.length} tone="gold" />
        <StatCard title="نشطة" value={activeCount} tone="success" />
        <StatCard title="إدارة" value={adminCount} tone="warning" />
        <StatCard title="موردون" value={providerCount} tone="info" />
      </div>

      <SectionCard className="filters-card">
        <SearchInput
          value={search}
          onChange={setSearch}
          onSubmit={load}
          placeholder="بحث بالاسم أو الهاتف"
        />
      </SectionCard>

      <div className="content-with-aside">
        <SectionCard
          title="حسابات المنصة"
          subtitle="الجدول يعرض حقولا آمنة فقط من استجابة backend."
        >
          {items.length === 0 ? (
            <EmptyState
              title="لا يوجد مستخدمون"
              message="لا توجد حسابات مطابقة."
            />
          ) : (
            <DataTable
              columns={[
                'الاسم',
                'الهاتف',
                'البريد',
                'الدور',
                'الحالة',
                'المورد المرتبط',
                'تاريخ التسجيل',
                'إجراءات',
              ]}
              minWidth={1060}
            >
              {items.map((user) => (
                <tr key={user.id}>
                  <td>
                    <strong>{user.name}</strong>
                    <span className="table-subtle">معرف آمن للعرض الإداري</span>
                  </td>
                  <td dir="ltr">{user.phone ?? 'غير محدد'}</td>
                  <td className="truncate-cell">{user.email ?? 'غير محدد'}</td>
                  <td>
                    <RoleBadge role={user.role} />
                  </td>
                  <td>
                    <StatusBadge status={user.status} />
                  </td>
                  <td>
                    {user.provider ? (
                      <span className="provider-cell">
                        {user.provider.businessName}
                        <StatusBadge status={user.provider.status} />
                      </span>
                    ) : (
                      'لا يوجد'
                    )}
                  </td>
                  <td className="nowrap">{formatDate(user.createdAt)}</td>
                  <td className="actions-cell">
                    <span className="readonly-pill">عرض آمن فقط</span>
                  </td>
                </tr>
              ))}
            </DataTable>
          )}
        </SectionCard>

        <SectionCard
          title="توزيع الأدوار"
          subtitle="محسوب من الحسابات المعروضة حاليا فقط."
          className="sticky-panel"
        >
          <div className="distribution-list">
            {roleDistribution.map((item) => {
              const percent = Math.round(
                (item.value / Math.max(items.length, 1)) * 100,
              );
              return (
                <div className={`distribution-item tone-${item.tone}`} key={item.label}>
                  <div>
                    <span>{item.label}</span>
                    <strong>{item.value}</strong>
                  </div>
                  <span className="distribution-bar">
                    <span style={{ width: `${percent}%` }} />
                  </span>
                </div>
              );
            })}
          </div>
        </SectionCard>
      </div>
    </section>
  );
}
