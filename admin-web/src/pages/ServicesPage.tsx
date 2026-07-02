import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  City,
  getCategories,
  getCities,
  getServiceReferences,
  ProviderCategory,
  ProviderService,
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

export function ServicesPage() {
  const [items, setItems] = useState<ProviderService[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [categories, setCategories] = useState<ProviderCategory[]>([]);
  const [search, setSearch] = useState('');
  const [cityId, setCityId] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const [services, cityList, categoryList] = await Promise.all([
        getServiceReferences({ search, cityId, categoryId, limit: 50 }),
        getCities(),
        getCategories(),
      ]);
      setItems(services.items);
      setCities(cityList);
      setCategories(categoryList);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل خدمات المزودين.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [cityId, categoryId]);

  if (isLoading) return <LoadingState title="جاري تحميل خدمات المزودين" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  const featuredCount = items.filter((service) => service.isFeatured).length;
  const pricedCount = items.filter((service) => service.basePrice).length;
  const providersCount = new Set(
    items.map((service) => service.provider?.id).filter(Boolean),
  ).size;
  const withImagesCount = items.filter(
    (service) => (service.images?.length ?? 0) > 0,
  ).length;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="الكتالوج"
        icon="⌁"
        title="خدمات المزودين النشطة"
        description="عرض مرجعي للخدمات الظاهرة للمستخدمين من API الخدمات العام. لا توجد إجراءات إنشاء أو مراجعة إدارية مفعلة لهذه الوحدة حتى الآن."
        meta={
          <>
            <span>{items.length} خدمة معروضة</span>
            <StatusBadge status="OPEN" />
          </>
        }
      />

      <div className="stats-grid">
        <StatCard title="الخدمات" value={items.length} tone="gold" />
        <StatCard title="مزودون" value={providersCount} tone="info" />
        <StatCard title="لها سعر" value={pricedCount} tone="success" />
        <StatCard title="مميزة" value={featuredCount} tone="warning" />
        <StatCard title="لها صور" value={withImagesCount} tone="gold" />
      </div>

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            value={search}
            onChange={setSearch}
            onSubmit={load}
            placeholder="بحث بالخدمة أو المزود"
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

      <SectionCard
        title="قائمة الخدمات"
        subtitle="هذه بيانات قراءة فقط من الخدمات النشطة لمزودين نشطين؛ لا يتم عرض خدمات معلقة أو موقوفة من هذا endpoint."
      >
        {items.length === 0 ? (
          <EmptyState
            title="لا توجد خدمات مطابقة"
            message="جرّب تغيير الفلاتر أو البحث. الصفحة لا تنشئ بيانات بديلة عند غياب النتائج."
            tone="api"
          />
        ) : (
          <DataTable
            columns={[
              'الخدمة',
              'المزود',
              'الفئة',
              'المدينة',
              'السعر',
              'الصور',
              'الحالة',
            ]}
            minWidth={1040}
          >
            {items.map((service) => (
              <tr key={service.id}>
                <td>
                  <strong>{service.title}</strong>
                  <span className="table-subtle">
                    {service.description ?? 'لا يوجد وصف مختصر'}
                  </span>
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
                <td>
                  {service.city?.nameAr ??
                    service.provider?.city?.nameAr ??
                    'غير محددة'}
                </td>
                <td>
                  {service.basePrice
                    ? `${service.basePrice} ${service.currency}`
                    : 'حسب الطلب'}
                  {service.priceUnit ? (
                    <span className="table-subtle">{service.priceUnit}</span>
                  ) : null}
                </td>
                <td>{service.images?.length ?? 0}</td>
                <td>
                  <StatusBadge status={service.isActive ? 'ACTIVE' : 'DISABLED'} />
                </td>
              </tr>
            ))}
          </DataTable>
        )}
      </SectionCard>
    </section>
  );
}
