import { useEffect, useState } from 'react';
import {
  City,
  getCategories,
  getCities,
  getProviderApplications,
  ProviderApplication,
  ProviderCategory,
} from '../api/admin';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate, ProviderActions } from './providerHelpers';

const statuses = [
  { value: '', label: 'كل الحالات' },
  { value: 'PENDING', label: 'قيد المراجعة' },
  { value: 'ACTIVE', label: 'نشط' },
  { value: 'NEEDS_CHANGES', label: 'يحتاج تعديل' },
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
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const [providers, cityList, categoryList] = await Promise.all([
        getProviderApplications({
          status,
          cityId,
          categoryId,
          search,
          limit: 50,
        }),
        getCities(),
        getCategories(),
      ]);
      setItems(providers.items);
      setCities(cityList);
      setCategories(categoryList);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل الطلبات.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [status, cityId, categoryId]);

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  return (
    <section className="page-stack">
      <div className="page-heading">
        <div>
          <p>موافقات الموردين</p>
          <h2>مراجعة طلبات الانضمام وإدارة حالة الظهور</h2>
        </div>
      </div>

      <div className="filters">
        <input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter') load();
          }}
          placeholder="بحث بالاسم أو الهاتف"
        />
        <select value={status} onChange={(event) => setStatus(event.target.value)}>
          {statuses.map((item) => (
            <option key={item.value} value={item.value}>
              {item.label}
            </option>
          ))}
        </select>
        <select value={cityId} onChange={(event) => setCityId(event.target.value)}>
          <option value="">كل المدن</option>
          {cities.map((city) => (
            <option key={city.id} value={city.id}>
              {city.nameAr}
            </option>
          ))}
        </select>
        <select
          value={categoryId}
          onChange={(event) => setCategoryId(event.target.value)}
        >
          <option value="">كل الفئات</option>
          {categories.map((category) => (
            <option key={category.id} value={category.id}>
              {category.nameAr}
            </option>
          ))}
        </select>
        <button className="button ghost" onClick={load}>
          بحث
        </button>
      </div>

      {items.length === 0 ? (
        <EmptyState
          title="لا توجد طلبات حالياً"
          message="جرّب تغيير الفلاتر أو البحث باسم آخر."
        />
      ) : (
        <DataTable
          columns={[
            'اسم النشاط',
            'صاحب الحساب',
            'الهاتف',
            'المدينة',
            'الفئة',
            'الحالة',
            'تاريخ الطلب',
            'إجراءات',
          ]}
        >
          {items.map((provider) => (
            <tr key={provider.id}>
              <td>{provider.businessName}</td>
              <td>{provider.user?.name ?? provider.ownerName ?? 'غير محدد'}</td>
              <td dir="ltr">{provider.phone}</td>
              <td>{provider.city?.nameAr ?? 'غير محدد'}</td>
              <td>{provider.primaryCategory?.nameAr ?? 'غير محدد'}</td>
              <td>
                <StatusBadge status={provider.status} />
              </td>
              <td>{formatDate(provider.createdAt)}</td>
              <td>
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
    </section>
  );
}
