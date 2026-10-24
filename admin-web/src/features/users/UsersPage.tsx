import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { activateUser, disableUser, getUsers, type AdminUserRecord } from './api';
import { ActionButton } from '../../design_system/ActionButton';
import { DataTable } from '../../design_system/DataTable';
import { EmptyState } from '../../design_system/EmptyState';
import { ErrorState } from '../../design_system/ErrorState';
import { LoadingState } from '../../design_system/LoadingState';
import { PageHeader } from '../../design_system/PageHeader';
import { Pagination } from '../../design_system/Pagination';
import { RoleBadge } from '../../design_system/RoleBadge';
import { SearchInput } from '../../design_system/SearchInput';
import { SectionCard } from '../../design_system/SectionCard';
import { StatCard } from '../../design_system/StatCard';
import { StatusBadge } from '../../design_system/StatusBadge';
import { formatDate } from '../../platform/i18n/formatDate';
import { AdminPermission, Can, useAuth } from '../auth/api';

export function UsersPage() {
  const { user: currentAdmin } = useAuth();
  const [items, setItems] = useState<AdminUserRecord[]>([]);
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
      const result = await getUsers({ search, page, limit: 20 });
      if (page > result.totalPages) {
        setPage(result.totalPages);
        return;
      }
      setItems(result.items as AdminUserRecord[]);
      setPagination({
        page: result.page,
        limit: result.limit,
        total: result.total,
        totalPages: result.totalPages,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل المستخدمين.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [page]);

  function submitSearch() {
    if (page === 1) void load();
    else setPage(1);
  }

  async function toggleUser(user: AdminUserRecord) {
    setError(null);
    try {
      if (user.status === 'ACTIVE') {
        await disableUser(user.id);
      } else {
        await activateUser(user.id);
      }
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحديث حالة الحساب.');
    }
  }

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
        meta={<span>{pagination.total} حساب مطابق</span>}
      />

      <div className="stats-grid">
        <StatCard title="كل النتائج" value={pagination.total} tone="gold" />
        <StatCard title="نشطة في الصفحة" value={activeCount} tone="success" />
        <StatCard title="إدارة في الصفحة" value={adminCount} tone="warning" />
        <StatCard title="موردون في الصفحة" value={providerCount} tone="info" />
      </div>

      <SectionCard className="filters-card">
        <SearchInput
          label="بحث في حسابات المنصة"
          value={search}
          onChange={setSearch}
          onSubmit={submitSearch}
          placeholder="بحث بالاسم أو الهاتف"
        />
      </SectionCard>

      <div className="content-with-aside">
        <SectionCard
          title="حسابات المنصة"
          subtitle="الجدول يعرض البيانات الآمنة فقط، بدون كلمات مرور أو رموز دخول."
        >
          {items.length === 0 ? (
            <EmptyState
              title="لا يوجد مستخدمون"
              message="لا توجد حسابات مطابقة."
            />
          ) : (
            <DataTable
              label="حسابات المنصة"
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
                    <Link className="table-strong-link" to={`/users/${user.id}`}>
                      {user.name}
                    </Link>
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
                    <Link className="readonly-pill" to={`/users/${user.id}`}>
                      عرض التفاصيل
                    </Link>
                    <Can permission={AdminPermission.USERS_WRITE}>
                      {user.role !== 'ADMIN' ||
                      currentAdmin?.adminRole === 'SUPER_ADMIN' ? (
                        <ActionButton
                          tone={user.status === 'ACTIVE' ? 'danger' : 'ghost'}
                          size="small"
                          disabled={
                            user.id === currentAdmin?.id &&
                            user.status === 'ACTIVE'
                          }
                          onClick={() => toggleUser(user)}
                        >
                          {user.status === 'ACTIVE' ? 'تعطيل' : 'تفعيل'}
                        </ActionButton>
                      ) : null}
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
