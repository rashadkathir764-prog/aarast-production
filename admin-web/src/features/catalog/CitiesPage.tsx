import { FormEvent, useEffect, useState } from 'react';
import {
  City,
  createCity,
  deleteCity,
  getCities,
  updateCity,
} from './api';
import { ActionButton } from '../../design_system/ActionButton';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import { DataTable } from '../../design_system/DataTable';
import { EmptyState } from '../../design_system/EmptyState';
import { ErrorState } from '../../design_system/ErrorState';
import { FormCard } from '../../design_system/FormCard';
import { FormField } from '../../design_system/FormField';
import { LoadingState } from '../../design_system/LoadingState';
import { PageHeader } from '../../design_system/PageHeader';
import { SectionCard } from '../../design_system/SectionCard';
import { StatCard } from '../../design_system/StatCard';
import { StatusBadge } from '../../design_system/StatusBadge';
import { Can } from '../auth/api';
import { AdminPermission } from '../auth/api';

export function CitiesPage() {
  const [items, setItems] = useState<City[]>([]);
  const [editing, setEditing] = useState<City | null>(null);
  const [nameAr, setNameAr] = useState('');
  const [nameEn, setNameEn] = useState('');
  const [countryCode, setCountryCode] = useState('YE');
  const [sortOrder, setSortOrder] = useState('0');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      setItems(await getCities());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل المدن.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  function startEdit(city: City) {
    setEditing(city);
    setNameAr(city.nameAr);
    setNameEn(city.nameEn ?? '');
    setCountryCode(city.countryCode);
    setSortOrder(String(city.sortOrder));
  }

  function resetForm() {
    setEditing(null);
    setNameAr('');
    setNameEn('');
    setCountryCode('YE');
    setSortOrder('0');
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    try {
      const payload = {
        nameAr,
        nameEn: nameEn || null,
        countryCode: countryCode || 'YE',
        sortOrder: Number(sortOrder) || 0,
      };
      if (editing) {
        await updateCity(editing.id, payload);
      } else {
        await createCity(payload);
      }
      resetForm();
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر حفظ المدينة.');
    }
  }

  if (isLoading) return <LoadingState title="جاري تحميل المدن" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  const activeCount = items.filter((city) => city.isActive).length;
  const totalProviders = items.reduce(
    (total, city) => total + (city.providersCount ?? 0),
    0,
  );
  const totalServices = items.reduce(
    (total, city) => total + (city.servicesCount ?? 0),
    0,
  );

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="المدن"
        icon="⌖"
        title="إدارة المدن اليمنية"
        description="إدارة المدن المتاحة للموردين والخدمات داخل أعرست."
        meta={<span>{items.length} مدينة</span>}
      />

      <div className="stats-grid">
        <StatCard title="إجمالي المدن" value={items.length} tone="gold" />
        <StatCard title="نشطة" value={activeCount} tone="success" />
        <StatCard title="الموردون" value={totalProviders} tone="info" />
        <StatCard title="الخدمات" value={totalServices} tone="warning" />
      </div>

      <div className="management-layout">
        <SectionCard
          title="مدن السوق"
          subtitle="الاسم العربي، الاسم الإنجليزي، رمز الدولة، الترتيب، والحالة."
        >
          {items.length === 0 ? (
            <EmptyState title="لا توجد مدن" message="أضف أول مدينة." />
          ) : (
            <DataTable
              label="مدن السوق"
              columns={[
                'الاسم العربي',
                'الاسم الإنجليزي',
                'رمز الدولة',
                'الترتيب',
                'الحالة',
                'الموردون',
                'الخدمات',
                'إجراءات',
              ]}
              dense
              minWidth={920}
            >
              {items.map((city) => (
                <tr key={city.id}>
                  <td>
                    <strong>{city.nameAr}</strong>
                  </td>
                  <td>{city.nameEn ?? 'غير محدد'}</td>
                  <td>{city.countryCode}</td>
                  <td>{city.sortOrder}</td>
                  <td>
                    <StatusBadge status={city.isActive ? 'ACTIVE' : 'DISABLED'} />
                  </td>
                  <td>{city.providersCount ?? 0}</td>
                  <td>{city.servicesCount ?? 0}</td>
                  <td className="actions-cell">
                    <Can permission={AdminPermission.CATALOG_WRITE}>
                      <div className="actions">
                      <ActionButton
                        tone="ghost"
                        size="small"
                        type="button"
                        onClick={() => startEdit(city)}
                      >
                        تعديل
                      </ActionButton>
                      <ConfirmDialog
                        title="تعطيل المدينة"
                        message="سيتم تعطيل المدينة من قوائم إدارة السوق دون حذفها نهائيا."
                        confirmLabel="تعطيل"
                        tone="danger"
                        trigger={
                          <ActionButton tone="danger" size="small" type="button">
                            تعطيل
                          </ActionButton>
                        }
                        onConfirm={() => deleteCity(city.id).then(load)}
                      />
                      </div>
                    </Can>
                  </td>
                </tr>
              ))}
            </DataTable>
          )}
        </SectionCard>

        <Can permission={AdminPermission.CATALOG_WRITE}>
          <FormCard
            title={editing ? 'تعديل مدينة' : 'إضافة مدينة'}
            subtitle="الأسماء العربية تظهر للمستخدمين في الواجهة."
          >
            <form className="side-form" onSubmit={submit}>
            <FormField
              label="الاسم العربي"
              value={nameAr}
              onChange={(event) => setNameAr(event.target.value)}
              required
            />
            <FormField
              label="الاسم الإنجليزي"
              value={nameEn}
              onChange={(event) => setNameEn(event.target.value)}
            />
            <FormField
              label="رمز الدولة"
              value={countryCode}
              onChange={(event) => setCountryCode(event.target.value)}
            />
            <FormField
              label="الترتيب"
              type="number"
              value={sortOrder}
              onChange={(event) => setSortOrder(event.target.value)}
            />
            <div className="form-actions">
              <ActionButton type="submit">
                {editing ? 'حفظ التعديل' : 'إضافة مدينة'}
              </ActionButton>
              {editing ? (
                <ActionButton tone="ghost" type="button" onClick={resetForm}>
                  إلغاء
                </ActionButton>
              ) : null}
            </div>
            </form>
          </FormCard>
        </Can>
      </div>
    </section>
  );
}
