import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  AdminStats,
  City,
  getCategories,
  getCities,
  getProviderApplications,
  getStats,
  ProviderApplication,
  ProviderCategory,
} from '../api/admin';
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
import { StatusBadge } from '../components/StatusBadge';
import { TableToolbar } from '../components/TableToolbar';
import { formatDate, ProviderActions, shortId } from './providerHelpers';

const statuses = [
  { value: '', label: 'الطلبات غير المعتمدة' },
  { value: 'PENDING', label: 'جديد' },
  { value: 'NEEDS_CHANGES', label: 'يحتاج تعديل' },
  { value: 'ACTIVE', label: 'مقبول' },
  { value: 'REJECTED', label: 'مرفوض' },
  { value: 'SUSPENDED', label: 'موقوف' },
];

export function ProviderApplicationsPage() {
  const [items, setItems] = useState<ProviderApplication[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [categories, setCategories] = useState<ProviderCategory[]>([]);
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
  const [stats, setStats] = useState<AdminStats | null>(null);
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
