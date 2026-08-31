import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  getProviderApplications,
  type CityProjection,
  type ProviderApplication,
  type ProviderCategoryProjection,
} from './api';
import { DataTable } from '../../design_system/DataTable';
import { EmptyState } from '../../design_system/EmptyState';
import { ErrorState } from '../../design_system/ErrorState';
import { FilterSelect } from '../../design_system/FilterSelect';
import { LoadingState } from '../../design_system/LoadingState';
import { PageHeader } from '../../design_system/PageHeader';
import { Pagination } from '../../design_system/Pagination';
import { SearchInput } from '../../design_system/SearchInput';
import { SectionCard } from '../../design_system/SectionCard';
import { StatCard } from '../../design_system/StatCard';
import { StatusBadge } from '../../design_system/StatusBadge';
import { TableToolbar } from '../../design_system/TableToolbar';
import { formatDate } from '../../platform/i18n/formatDate';
import { ProviderActions, shortId } from './providerHelpers';

const statuses = [
  { value: '', label: 'الطلبات غير المعتمدة' },
  { value: 'PENDING', label: 'جديد' },
  { value: 'NEEDS_CHANGES', label: 'يحتاج تعديل' },
  { value: 'ACTIVE', label: 'مقبول' },
  { value: 'REJECTED', label: 'مرفوض' },
  { value: 'SUSPENDED', label: 'موقوف' },
];

type ProviderApplicationStats = {
  pendingProviders: number;
  needsChangesProviders: number;
  rejectedProviders: number;
};

type ProviderApplicationsPageProps = {
  getStats: () => Promise<ProviderApplicationStats>;
  getCities: () => Promise<CityProjection[]>;
  getCategories: () => Promise<ProviderCategoryProjection[]>;
};

export function ProviderApplicationsPage({
  getStats,
  getCities,
  getCategories,
}: ProviderApplicationsPageProps) {
  const [items, setItems] = useState<ProviderApplication[]>([]);
  const [cities, setCities] = useState<CityProjection[]>([]);
  const [categories, setCategories] = useState<ProviderCategoryProjection[]>([]);
  const [status, setStatus] = useState('');
  const [cityId, setCityId] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [pagination, setPagination] = useState({
    page: 1,
    limit: 20,
    total: 0,
    totalPages: 1,
  });
  const [stats, setStats] = useState<ProviderApplicationStats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const [providers, cityList, categoryList, statsResult] = await Promise.all([
        getProviderApplications({
          status,
          cityId,
          categoryId,
          search,
          page,
          limit: 20,
        }),
        getCities(),
        getCategories(),
        getStats(),
      ]);
      if (page > providers.totalPages) {
        setPage(providers.totalPages);
        return;
      }
      setItems(providers.items);
      setPagination({
        page: providers.page,
        limit: providers.limit,
        total: providers.total,
        totalPages: providers.totalPages,
      });
      setCities(cityList);
      setCategories(categoryList);
      setStats(statsResult);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل الطلبات.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [status, cityId, categoryId, page]);

  function submitSearch() {
    if (page === 1) void load();
    else setPage(1);
  }

  if (isLoading) return <LoadingState title="جاري تحميل طلبات الموردين" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="موافقات الموردين"
        icon="□"
        title="طلبات الموردين"
        description="مراجعة طلبات الانضمام قبل اعتماد ظهور الموردين في السوق العام."
        meta={
          <>
            <span>{pagination.total} نتيجة مطابقة</span>
            <span>لا يظهر المورد علنا قبل الاعتماد</span>
          </>
        }
      />

      {stats ? (
        <div className="stats-grid">
          <StatCard title="جديد" value={stats.pendingProviders} tone="warning" />
          <StatCard
            title="يحتاج تعديل"
            value={stats.needsChangesProviders}
            tone="gold"
          />
          <StatCard title="مرفوض" value={stats.rejectedProviders} tone="danger" />
        </div>
      ) : null}

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            label="بحث في طلبات الموردين"
            value={search}
            onChange={setSearch}
            onSubmit={submitSearch}
            placeholder="بحث باسم النشاط أو الهاتف"
          />
          <FilterSelect
            label="الحالة"
            value={status}
            onChange={(value) => {
              setStatus(value);
              setPage(1);
            }}
            options={statuses}
          />
          <FilterSelect
            label="المدينة"
            value={cityId}
            onChange={(value) => {
              setCityId(value);
              setPage(1);
            }}
            options={[
              { value: '', label: 'كل المدن' },
              ...cities.map((city) => ({ value: city.id, label: city.nameAr })),
            ]}
          />
          <FilterSelect
            label="الفئة"
            value={categoryId}
            onChange={(value) => {
              setCategoryId(value);
              setPage(1);
            }}
            options={[
              { value: '', label: 'كل الفئات' },
              ...categories.map((category) => ({
                value: category.id,
                label: category.nameAr,
              })),
            ]}
          />
        </TableToolbar>
      </SectionCard>

      <SectionCard
        title="سجل الطلبات"
        subtitle="كل إجراء مؤثر يستخدم تأكيدا واضحا قبل التنفيذ."
      >
        {items.length === 0 ? (
          <EmptyState
            title="لا توجد طلبات حاليا"
            message="جرب تغيير الفلاتر أو البحث باسم آخر."
          />
        ) : (
          <DataTable
            label="سجل طلبات الموردين"
            columns={[
              'رقم الطلب',
              'المورد',
              'المدينة',
              'نوع الطلب',
              'الحالة',
              'تاريخ الطلب',
              'الإجراءات',
            ]}
            minWidth={980}
          >
            {items.map((provider) => (
              <tr key={provider.id}>
                <td className="nowrap">{shortId(provider.id)}</td>
                <td>
                  <Link
                    className="table-strong-link"
                    to={`/providers/applications/${provider.id}`}
                  >
                    {provider.businessName}
                  </Link>
                  <span className="table-subtle">
                    {provider.user?.name ?? provider.ownerName ?? 'مالك غير محدد'}
                  </span>
                </td>
                <td>{provider.city?.nameAr ?? 'غير محدد'}</td>
                <td>{provider.primaryCategory?.nameAr ?? 'خدمة أعراس'}</td>
                <td>
                  <StatusBadge status={provider.status} />
                </td>
                <td className="nowrap">{formatDate(provider.createdAt)}</td>
                <td className="actions-cell">
                  <ProviderActions
                    provider={provider}
                    detailsPath={`/providers/applications/${provider.id}`}
                    onChanged={load}
                  />
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
