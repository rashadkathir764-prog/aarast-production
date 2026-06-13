import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  City,
  getCategories,
  getCities,
  getProviders,
  ProviderApplication,
  ProviderCategory,
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
import { StatusBadge } from '../components/StatusBadge';
import { TableToolbar } from '../components/TableToolbar';
import { formatDate, ProviderActions } from './providerHelpers';

const statuses = [
  { value: '', label: 'كل الحالات' },
  { value: 'ACTIVE', label: 'نشط' },
  { value: 'SUSPENDED', label: 'موقوف' },
  { value: 'PENDING', label: 'جديد' },
  { value: 'NEEDS_CHANGES', label: 'يحتاج تعديل' },
  { value: 'REJECTED', label: 'مرفوض' },
];

export function ProvidersPage() {
  const [items, setItems] = useState<ProviderApplication[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [categories, setCategories] = useState<ProviderCategory[]>([]);
  const [status, setStatus] = useState('');
  const [cityId, setCityId] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const [providers, cityList, categoryList] = await Promise.all([
        getProviders({ status, cityId, categoryId, search, limit: 50 }),
        getCities(),
        getCategories(),
      ]);
      setItems(providers.items);
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
  }, [status, cityId, categoryId]);

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
        meta={<span>{items.length} مورد معروض</span>}
      />

      <div className="stats-grid">
        <StatCard title="الموردون" value={items.length} tone="gold" />
        <StatCard title="نشط" value={activeCount} tone="success" />
        <StatCard title="موقوف" value={suspendedCount} tone="danger" />
        <StatCard title="الخدمات" value={totalServices} tone="info" />
        <StatCard title="طلبات العروض" value={totalBookings} tone="warning" />
      </div>

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            value={search}
            onChange={setSearch}
            onSubmit={load}
            placeholder="بحث باسم المورد أو الهاتف"
          />
          <FilterSelect
            label="الحالة"
            value={status}
            onChange={setStatus}
            options={statuses}
          />
          <FilterSelect
            label="المدينة"
            value={cityId}
            onChange={setCityId}
            options={[
              { value: '', label: 'كل المدن' },
              ...cities.map((city) => ({ value: city.id, label: city.nameAr })),
            ]}
          />
          <FilterSelect
            label="الفئة"
            value={categoryId}
            onChange={setCategoryId}
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
        </SectionCard>

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
      </div>
    </section>
  );
}
