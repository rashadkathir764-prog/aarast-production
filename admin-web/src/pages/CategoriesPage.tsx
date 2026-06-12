import { FormEvent, useEffect, useState } from 'react';
import {
  createCategory,
  deleteCategory,
  getCategories,
  ProviderCategory,
  updateCategory,
} from '../api/admin';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { FormField } from '../components/FormField';
import { LoadingState } from '../components/LoadingState';

export function CategoriesPage() {
  const [items, setItems] = useState<ProviderCategory[]>([]);
  const [editing, setEditing] = useState<ProviderCategory | null>(null);
  const [nameAr, setNameAr] = useState('');
  const [nameEn, setNameEn] = useState('');
  const [slug, setSlug] = useState('');
  const [icon, setIcon] = useState('');
  const [sortOrder, setSortOrder] = useState('0');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      setItems(await getCategories());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل الفئات.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  function startEdit(category: ProviderCategory) {
    setEditing(category);
    setNameAr(category.nameAr);
    setNameEn(category.nameEn ?? '');
    setSlug(category.slug);
    setIcon(category.icon ?? '');
    setSortOrder(String(category.sortOrder));
  }

  function resetForm() {
    setEditing(null);
    setNameAr('');
    setNameEn('');
    setSlug('');
    setIcon('');
    setSortOrder('0');
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    try {
      const payload = {
        nameAr,
        nameEn: nameEn || null,
        slug: slug || null,
        icon: icon || null,
        sortOrder: Number(sortOrder) || 0,
      };
      if (editing) {
        await updateCategory(editing.id, payload);
      } else {
        await createCategory(payload);
      }
      resetForm();
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر حفظ الفئة.');
    }
  }

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  return (
    <section className="page-stack">
      <div className="page-heading">
        <div>
          <p>الفئات</p>
          <h2>إدارة فئات خدمات الموردين</h2>
        </div>
      </div>

      <form className="panel form-grid" onSubmit={submit}>
        <FormField label="الاسم العربي" value={nameAr} onChange={(event) => setNameAr(event.target.value)} required />
        <FormField label="الاسم الإنجليزي" value={nameEn} onChange={(event) => setNameEn(event.target.value)} />
        <FormField label="المعرّف slug" value={slug} onChange={(event) => setSlug(event.target.value)} placeholder="photography" />
        <FormField label="الأيقونة" value={icon} onChange={(event) => setIcon(event.target.value)} placeholder="camera" />
        <FormField label="الترتيب" type="number" value={sortOrder} onChange={(event) => setSortOrder(event.target.value)} />
        <div className="form-actions">
          <button className="button">{editing ? 'حفظ التعديل' : 'إضافة فئة'}</button>
          {editing ? (
            <button className="button ghost" type="button" onClick={resetForm}>
              إلغاء
            </button>
          ) : null}
        </div>
      </form>

      {items.length === 0 ? (
        <EmptyState title="لا توجد فئات" message="أضف أول فئة للموردين." />
      ) : (
        <DataTable columns={['الفئة', 'slug', 'الحالة', 'الموردون', 'الخدمات', 'إجراءات']}>
          {items.map((category) => (
            <tr key={category.id}>
              <td>{category.nameAr}</td>
              <td>{category.slug}</td>
              <td>{category.isActive ? 'نشطة' : 'معطلة'}</td>
              <td>{category.providersCount ?? 0}</td>
              <td>{category.servicesCount ?? 0}</td>
              <td>
                <div className="actions">
                  <button className="button small ghost" onClick={() => startEdit(category)}>
                    تعديل
                  </button>
                  <button className="button small danger" onClick={() => deleteCategory(category.id).then(load)}>
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
