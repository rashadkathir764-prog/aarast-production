import { FormEvent, useEffect, useState } from 'react';
import {
  City,
  createCity,
  deleteCity,
  getCities,
  updateCity,
} from '../api/admin';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { FormField } from '../components/FormField';
import { LoadingState } from '../components/LoadingState';

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

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  return (
    <section className="page-stack">
      <div className="page-heading">
        <div>
          <p>المدن</p>
          <h2>إدارة المدن اليمنية المتاحة للموردين</h2>
        </div>
      </div>

      <form className="panel form-grid" onSubmit={submit}>
        <FormField label="الاسم العربي" value={nameAr} onChange={(event) => setNameAr(event.target.value)} required />
        <FormField label="الاسم الإنجليزي" value={nameEn} onChange={(event) => setNameEn(event.target.value)} />
        <FormField label="رمز الدولة" value={countryCode} onChange={(event) => setCountryCode(event.target.value)} />
        <FormField label="الترتيب" type="number" value={sortOrder} onChange={(event) => setSortOrder(event.target.value)} />
        <div className="form-actions">
          <button className="button">{editing ? 'حفظ التعديل' : 'إضافة مدينة'}</button>
          {editing ? (
            <button className="button ghost" type="button" onClick={resetForm}>
              إلغاء
            </button>
          ) : null}
        </div>
      </form>

      {items.length === 0 ? (
        <EmptyState title="لا توجد مدن" message="أضف أول مدينة." />
      ) : (
        <DataTable columns={['المدينة', 'الدولة', 'الحالة', 'الموردون', 'الخدمات', 'إجراءات']}>
          {items.map((city) => (
            <tr key={city.id}>
              <td>{city.nameAr}</td>
              <td>{city.countryCode}</td>
              <td>{city.isActive ? 'نشطة' : 'معطلة'}</td>
              <td>{city.providersCount ?? 0}</td>
              <td>{city.servicesCount ?? 0}</td>
              <td>
                <div className="actions">
                  <button className="button small ghost" onClick={() => startEdit(city)}>
                    تعديل
                  </button>
                  <button className="button small danger" onClick={() => deleteCity(city.id).then(load)}>
                    تعطيل
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </DataTable>
      )}
    </section>
  );
}
