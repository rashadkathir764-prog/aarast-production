import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  getProviders,
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
import { ProviderActions } from './providerHelpers';
import { AddListedProviderCard } from './AddListedProviderCard';
import { AdminPermission, Can } from '../auth/api';

const statuses = [
  { value: '', label: 'النشطون والموقوفون' },
  { value: 'ACTIVE', label: 'نشط' },
  { value: 'SUSPENDED', label: 'موقوف' },
  { value: 'PENDING', label: 'جديد' },
  { value: 'NEEDS_CHANGES', label: 'يحتاج تعديل' },
  { value: 'REJECTED', label: 'مرفوض' },
];

type ProvidersPageProps = {
  getCities: () => Promise<CityProjection[]>;
  getCategories: () => Promise<ProviderCategoryProjection[]>;
};

export function ProvidersPage({
  getCities,
  getCategories,
}: ProvidersPageProps) {
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
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const [providers, cityList, categoryList] = await Promise.all([
        getProviders({ status, cityId, categoryId, search, page, limit: 20 }),
        getCities(),
        getCategories(),
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
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل الموردين.');
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

  if (isLoading) return <LoadingState title="جاري تحميل الموردين" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  const totalServices = items.reduce(
    (total, provider) => total + provider.servicesCount,
    0,
  );
  const totalBookings = items.reduce(
    (total, provider) => total + provider.quoteRequestsCount,
    0,
  );
  const activeCount = items.filter((provider) => provider.status === 'ACTIVE').length;
  const suspendedCount = items.filter(
    (provider) => provider.status === 'SUSPENDED',
  ).length;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="إدارة الموردين"
        icon="◉"
        title="ملفات الموردين داخل المنصة"
        description="هذه الصفحة مختلفة عن طلبات الانضمام، وتعرض الموردين المسجلين وحالة ظهورهم."
        meta={<span>{pagination.total} مورد مطابق</span>}
      />

      <div className="stats-grid">
        <StatCard title="كل النتائج" value={pagination.total} tone="gold" />
        <StatCard title="نشط في الصفحة" value={activeCount} tone="success" />
        <StatCard title="موقوف في الصفحة" value={suspendedCount} tone="danger" />
        <StatCard title="خدمات الصفحة" value={totalServices} tone="info" />
        <StatCard title="طلبات الصفحة" value={totalBookings} tone="warning" />
      </div>

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            label="بحث في الموردين"
            value={search}
            onChange={setSearch}
            onSubmit={submitSearch}
            placeholder="بحث باسم المورد أو الهاتف"
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

      <div className="content-with-aside">
        <SectionCard
          title="قائمة الموردين"
          subtitle="حالة المورد، المدينة، الخدمات، الطلبات، والتقييمات."
        >
          {items.length === 0 ? (
            <EmptyState
              title="لا يوجد موردون"
              message="لا توجد ملفات موردين مطابقة للفلاتر الحالية."
            />
          ) : (
            <DataTable
              label="قائمة الموردين"
              columns={[
                'المورد',
                'الحالة',
                'المدينة',
                'الهاتف',
                'الخدمات',
                'طلبات العروض',
                'التقييم',
                'الإجراءات',
              ]}
              minWidth={1040}
            >
              {items.map((provider) => (
                <tr key={provider.id}>
                  <td>
                    <Link className="table-strong-link" to={`/providers/${provider.id}`}>
                      {provider.businessName}
                    </Link>
                    <span className="table-subtle">
                      {provider.primaryCategory?.nameAr ?? 'فئة غير محددة'} ·{' '}
                      {formatDate(provider.updatedAt)}
                    </span>
                  </td>
                  <td>
                    <StatusBadge status={provider.status} />
                  </td>
                  <td>{provider.city?.nameAr ?? 'غير محدد'}</td>
                  <td dir="ltr">{provider.phone}</td>
                  <td>{provider.servicesCount}</td>
                  <td>{provider.quoteRequestsCount}</td>
                  <td>
                    {provider.ratingAverage} / 5
                    <span className="table-subtle">{provider.ratingCount} تقييم</span>
                  </td>
                  <td className="actions-cell">
                    <ProviderActions
                      provider={provider}
                      detailsPath={`/providers/${provider.id}`}
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

        <div className="page-stack">
          <SectionCard
            title="ترتيب سريع"
            subtitle="حسب عدد طلبات العروض في النتائج الحالية."
            className="sticky-panel"
          >
            <div className="compact-list">
              {[...items]
                .sort(
                  (first, second) =>
                    second.quoteRequestsCount - first.quoteRequestsCount,
                )
                .slice(0, 5)
                .map((provider, index) => (
                  <Link
                    className="compact-row"
                    to={`/providers/${provider.id}`}
                    key={provider.id}
                  >
                    <b>{index + 1}</b>
                    <div>
                      <strong>{provider.businessName}</strong>
                      <span>{provider.quoteRequestsCount} طلب عرض</span>
                    </div>
                    <StatusBadge status={provider.status} />
                  </Link>
                ))}
              {items.length === 0 ? (
                <span className="muted-text">لا توجد بيانات كافية للترتيب.</span>
              ) : null}
            </div>
          </SectionCard>

          <Can permission={AdminPermission.PROVIDERS_WRITE}>
            <AddListedProviderCard
              cities={cities}
              categories={categories}
              onCreated={load}
            />
          </Can>
        </div>
      </div>
    </section>
  );
}
