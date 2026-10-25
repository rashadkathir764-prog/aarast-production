import { FormEvent, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  City,
  createService,
  getCategories,
  getCities,
  getServices,
  ProviderCategory,
  ProviderService,
  updateService,
} from './api';
import { getProviders, type ProviderApplication } from '../providers/api';
import { ActionButton } from '../../design_system/ActionButton';
import { DataTable } from '../../design_system/DataTable';
import { EmptyState } from '../../design_system/EmptyState';
import { ErrorState } from '../../design_system/ErrorState';
import { FilterSelect } from '../../design_system/FilterSelect';
import { FormCard } from '../../design_system/FormCard';
import { FormField } from '../../design_system/FormField';
import { LoadingState } from '../../design_system/LoadingState';
import { PageHeader } from '../../design_system/PageHeader';
import { Pagination } from '../../design_system/Pagination';
import { SearchInput } from '../../design_system/SearchInput';
import { SectionCard } from '../../design_system/SectionCard';
import { StatCard } from '../../design_system/StatCard';
import { StatusBadge } from '../../design_system/StatusBadge';
import { TableToolbar } from '../../design_system/TableToolbar';
import { Can } from '../auth/api';
import { AdminPermission } from '../auth/api';

const statuses = [
  { value: '', label: 'كل الحالات' },
  { value: 'ACTIVE', label: 'نشطة' },
  { value: 'DISABLED', label: 'متوقفة' },
];

export function ServicesPage() {
  const [items, setItems] = useState<ProviderService[]>([]);
  const [providers, setProviders] = useState<ProviderApplication[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [categories, setCategories] = useState<ProviderCategory[]>([]);
  const [search, setSearch] = useState('');
  const [providerSearch, setProviderSearch] = useState('');
  const [providerSearchQuery, setProviderSearchQuery] = useState('');
  const [status, setStatus] = useState('');
  const [cityId, setCityId] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [page, setPage] = useState(1);
  const [pagination, setPagination] = useState({
    page: 1,
    limit: 20,
    total: 0,
    totalPages: 1,
  });
  const [form, setForm] = useState({
    providerId: '',
    categoryId: '',
    title: '',
    basePrice: '',
  });
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const [services, providerPage, cityList, categoryList] = await Promise.all([
        getServices({ search, status, cityId, categoryId, page, limit: 20 }),
        getProviders({
          search: providerSearchQuery,
          page: 1,
          limit: 20,
        }),
        getCities(),
        getCategories(),
      ]);
      if (page > services.totalPages) {
        setPage(services.totalPages);
        return;
      }
      setItems(services.items);
      setPagination({
        page: services.page,
        limit: services.limit,
        total: services.total,
        totalPages: services.totalPages,
      });
      setProviders(providerPage.items);
      setCities(cityList);
      setCategories(categoryList);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل خدمات الموردين.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [status, cityId, categoryId, page, providerSearchQuery]);

  function submitSearch() {
    if (page === 1) void load();
    else setPage(1);
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    setIsSaving(true);
    setError(null);
    try {
      await createService({
        providerId: form.providerId,
        categoryId: form.categoryId,
        title: form.title,
        basePrice: form.basePrice || null,
        currency: 'YER',
        isActive: true,
      });
      setForm({ providerId: '', categoryId: '', title: '', basePrice: '' });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر حفظ الخدمة.');
    } finally {
      setIsSaving(false);
    }
  }

  async function toggleActive(service: ProviderService) {
    setError(null);
    try {
      await updateService(service.id, { isActive: !service.isActive });
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحديث حالة الخدمة.');
    }
  }

  if (isLoading) return <LoadingState title="جاري تحميل خدمات الموردين" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  const activeCount = items.filter((service) => service.isActive).length;
  const disabledCount = items.filter((service) => !service.isActive).length;
  const pricedCount = items.filter((service) => service.basePrice).length;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="إدارة الخدمات"
        icon="⌁"
        title="خدمات الموردين"
        description="خدمات الموردين الفعلية: أنشئ خدمة، فعّلها أو أوقفها. الظهور المميز للمزود من «الباقات والظهور المميز»."
        meta={<span>{pagination.total} خدمة مطابقة</span>}
      />

      <div className="stats-grid">
        <StatCard title="كل النتائج" value={pagination.total} tone="gold" />
        <StatCard title="نشطة في الصفحة" value={activeCount} tone="success" />
        <StatCard title="متوقفة في الصفحة" value={disabledCount} tone="danger" />
        <StatCard title="بسعر في الصفحة" value={pricedCount} tone="info" />
      </div>

      <Can permission={AdminPermission.SERVICES_WRITE}>
        <FormCard title="إضافة خدمة لمورد" subtitle="تُحفظ مباشرة في /admin/services.">
          <form className="form-grid" onSubmit={submit}>
          <label className="form-field">
            <span>المورد</span>
            <select
              value={form.providerId}
              onChange={(event) =>
                setForm((current) => ({ ...current, providerId: event.target.value }))
              }
              required
            >
              <option value="">اختر مورد</option>
              {providers.map((provider) => (
                <option value={provider.id} key={provider.id}>
                  {provider.businessName}
                </option>
              ))}
            </select>
          </label>
          <label className="form-field">
            <span>الفئة</span>
            <select
              value={form.categoryId}
              onChange={(event) =>
                setForm((current) => ({ ...current, categoryId: event.target.value }))
              }
              required
            >
              <option value="">اختر فئة</option>
              {categories.map((category) => (
                <option value={category.id} key={category.id}>
                  {category.nameAr}
                </option>
              ))}
            </select>
          </label>
          <label className="form-field">
            <span>بحث المورد</span>
            <div style={{ display: 'flex', gap: '8px' }}>
              <input
                value={providerSearch}
                onChange={(event) => setProviderSearch(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter') {
                    event.preventDefault();
                    setProviderSearchQuery(providerSearch);
                  }
                }}
                placeholder="اكتب اسم المورد أو هاتفه"
              />
              <button
                className="button button--ghost"
                type="button"
                onClick={() => setProviderSearchQuery(providerSearch)}
              >
                بحث
              </button>
            </div>
          </label>
          <FormField
            label="اسم الخدمة"
            value={form.title}
            onChange={(event) =>
              setForm((current) => ({ ...current, title: event.target.value }))
            }
            required
          />
          <FormField
            label="السعر الأساسي"
            value={form.basePrice}
            onChange={(event) =>
              setForm((current) => ({ ...current, basePrice: event.target.value }))
            }
            inputMode="decimal"
            placeholder="اختياري"
          />
          <ActionButton type="submit" disabled={isSaving}>
            {isSaving ? 'جاري الحفظ...' : 'إضافة الخدمة'}
          </ActionButton>
          </form>
        </FormCard>
      </Can>

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            label="بحث في الخدمات"
            value={search}
            onChange={setSearch}
            onSubmit={submitSearch}
            placeholder="بحث بالخدمة أو المورد"
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

      <SectionCard title="قائمة الخدمات" subtitle="هذه ليست قراءة عامة؛ كل صف من /admin/services.">
        {items.length === 0 ? (
          <EmptyState title="لا توجد خدمات مطابقة" message="غير الفلاتر أو أضف خدمة جديدة لمورد." tone="api" />
        ) : (
          <DataTable
            label="قائمة خدمات الموردين"
            columns={['الخدمة', 'المورد', 'الفئة', 'المدينة', 'السعر', 'الحالة', 'إجراءات']}
            minWidth={1080}
          >
            {items.map((service) => (
              <tr key={service.id}>
                <td>
                  <strong>{service.title}</strong>
                  <span className="table-subtle">{service.description ?? 'لا يوجد وصف'}</span>
                </td>
                <td>
                  {service.provider ? (
                    <Link className="table-strong-link" to={`/providers/${service.provider.id}`}>
                      {service.provider.businessName}
                    </Link>
                  ) : (
                    'غير محدد'
                  )}
                  <span className="table-subtle" dir="ltr">
                    {service.provider?.phone ?? ''}
                  </span>
                </td>
                <td>{service.category?.nameAr ?? 'غير محددة'}</td>
                <td>{service.city?.nameAr ?? service.provider?.city?.nameAr ?? 'غير محددة'}</td>
                <td>
                  {service.basePrice ? `${service.basePrice} ${service.currency}` : 'حسب الطلب'}
                </td>
                <td>
                  <StatusBadge status={service.isActive ? 'ACTIVE' : 'DISABLED'} />
                </td>
                <td className="actions-cell">
                  <Can permission={AdminPermission.SERVICES_WRITE}>
                    <ActionButton tone="ghost" size="small" onClick={() => toggleActive(service)}>
                      {service.isActive ? 'إيقاف' : 'تفعيل'}
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
