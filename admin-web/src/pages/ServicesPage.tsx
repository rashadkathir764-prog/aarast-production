import { FormEvent, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  City,
  createService,
  getCategories,
  getCities,
  getProviders,
  getServices,
  ProviderApplication,
  ProviderCategory,
  ProviderService,
  updateService,
} from '../api/admin';
import { ActionButton } from '../components/ActionButton';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { FilterSelect } from '../components/FilterSelect';
import { FormCard } from '../components/FormCard';
import { FormField } from '../components/FormField';
import { LoadingState } from '../components/LoadingState';
import { PageHeader } from '../components/PageHeader';
import { SearchInput } from '../components/SearchInput';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';
import { TableToolbar } from '../components/TableToolbar';

const statuses = [
  { value: '', label: 'كل الحالات' },
  { value: 'ACTIVE', label: 'نشطة' },
  { value: 'DISABLED', label: 'متوقفة' },
  { value: 'FEATURED', label: 'مميزة' },
];

export function ServicesPage() {
  const [items, setItems] = useState<ProviderService[]>([]);
  const [providers, setProviders] = useState<ProviderApplication[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [categories, setCategories] = useState<ProviderCategory[]>([]);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [cityId, setCityId] = useState('');
  const [categoryId, setCategoryId] = useState('');
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
        getServices({ search, status, cityId, categoryId, limit: 80 }),
        getProviders({ limit: 100 }),
        getCities(),
        getCategories(),
      ]);
      setItems(services.items);
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
  }, [status, cityId, categoryId]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setIsSaving(true);
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
    } finally {
      setIsSaving(false);
    }
  }

  async function toggleActive(service: ProviderService) {
    await updateService(service.id, { isActive: !service.isActive });
    await load();
  }

  async function toggleFeatured(service: ProviderService) {
    await updateService(service.id, { isFeatured: !service.isFeatured });
    await load();
  }

  if (isLoading) return <LoadingState title="جاري تحميل خدمات الموردين" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  const activeCount = items.filter((service) => service.isActive).length;
  const disabledCount = items.filter((service) => !service.isActive).length;
  const featuredCount = items.filter((service) => service.isFeatured).length;
  const pricedCount = items.filter((service) => service.basePrice).length;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="إدارة الخدمات"
        icon="⌁"
        title="خدمات الموردين"
        description="إدارة حقيقية من Admin API: إنشاء خدمة، تفعيلها، إيقافها، وتمييزها بدون بيانات وهمية."
        meta={<span>{items.length} خدمة معروضة</span>}
      />

      <div className="stats-grid">
        <StatCard title="الخدمات" value={items.length} tone="gold" />
        <StatCard title="نشطة" value={activeCount} tone="success" />
        <StatCard title="متوقفة" value={disabledCount} tone="danger" />
        <StatCard title="مميزة" value={featuredCount} tone="warning" />
        <StatCard title="لها سعر" value={pricedCount} tone="info" />
      </div>

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

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            value={search}
            onChange={setSearch}
            onSubmit={load}
            placeholder="بحث بالخدمة أو المورد"
          />
          <FilterSelect label="الحالة" value={status} onChange={setStatus} options={statuses} />
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

      <SectionCard title="قائمة الخدمات" subtitle="هذه ليست قراءة عامة؛ كل صف من /admin/services.">
        {items.length === 0 ? (
          <EmptyState title="لا توجد خدمات مطابقة" message="غير الفلاتر أو أضف خدمة جديدة لمورد." tone="api" />
        ) : (
          <DataTable
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
                  {service.isFeatured ? <StatusBadge status="FEATURED" /> : null}
                </td>
                <td className="actions-cell">
                  <ActionButton tone="ghost" size="small" onClick={() => toggleActive(service)}>
                    {service.isActive ? 'إيقاف' : 'تفعيل'}
                  </ActionButton>
                  <ActionButton tone="ghost" size="small" onClick={() => toggleFeatured(service)}>
                    {service.isFeatured ? 'إلغاء التمييز' : 'تمييز'}
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
