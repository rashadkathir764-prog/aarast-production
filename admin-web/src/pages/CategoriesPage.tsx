import { FormEvent, useEffect, useState } from 'react';
import {
  createCategory,
  deleteCategory,
  getCategories,
  ProviderCategory,
  updateCategory,
} from '../api/admin';
import { ActionButton } from '../components/ActionButton';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { FormCard } from '../components/FormCard';
import { FormField } from '../components/FormField';
import { LoadingState } from '../components/LoadingState';
import { PageHeader } from '../components/PageHeader';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';

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

  if (isLoading) return <LoadingState title="جاري تحميل الفئات" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  const activeCount = items.filter((category) => category.isActive).length;
  const totalProviders = items.reduce(
    (total, category) => total + (category.providersCount ?? 0),
    0,
  );
  const totalServices = items.reduce(
    (total, category) => total + (category.servicesCount ?? 0),
    0,
  );

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="الفئات"
        icon="◇"
        title="إدارة فئات خدمات الأعراس"
        description="تنظيم السوق بفئات واضحة تساعد العملاء على الوصول للمورد المناسب."
        meta={<span>{items.length} فئة</span>}
      />

      <div className="stats-grid">
        <StatCard title="إجمالي الفئات" value={items.length} tone="gold" />
        <StatCard title="نشطة" value={activeCount} tone="success" />
        <StatCard title="الموردون" value={totalProviders} tone="info" />
        <StatCard title="الخدمات" value={totalServices} tone="warning" />
      </div>

      <div className="management-layout">
        <SectionCard
          title="فئات السوق"
          subtitle="اسم الفئة، الأيقونة، الحالة، الترتيب، وعدد الموردين والخدمات."
        >
          {items.length === 0 ? (
            <EmptyState
              title="لا توجد فئات"
              message="أضف أول فئة للموردين."
            />
          ) : (
            <DataTable
              columns={[
                'اسم الفئة',
                'الأيقونة',
                'الحالة',
                'الترتيب',
                'الموردون',
                'الخدمات',
                'إجراءات',
              ]}
              dense
              minWidth={900}
            >
              {items.map((category) => (
                <tr key={category.id}>
                  <td>
                    <strong>{category.nameAr}</strong>
                    <span className="table-subtle">{category.nameEn ?? category.slug}</span>
                  </td>
                  <td>{category.icon ?? 'غير محدد'}</td>
                  <td>
                    <StatusBadge
                      status={category.isActive ? 'ACTIVE' : 'DISABLED'}
                    />
                  </td>
                  <td>{category.sortOrder}</td>
                  <td>{category.providersCount ?? 0}</td>
                  <td>{category.servicesCount ?? 0}</td>
                  <td className="actions-cell">
                    <div className="actions">
                      <ActionButton
                        tone="ghost"
                        size="small"
                        type="button"
                        onClick={() => startEdit(category)}
                      >
                        تعديل
                      </ActionButton>
                      <ConfirmDialog
                        title="تعطيل الفئة"
                        message="سيتم تعطيل هذه الفئة من إدارة السوق دون حذفها نهائيا."
                        confirmLabel="تعطيل"
                        tone="danger"
                        trigger={
                          <ActionButton tone="danger" size="small" type="button">
                            تعطيل
                          </ActionButton>
                        }
                        onConfirm={() => deleteCategory(category.id).then(load)}
                      />
                    </div>
                  </td>
                </tr>
              ))}
            </DataTable>
          )}
        </SectionCard>

        <FormCard
          title={editing ? 'تعديل فئة' : 'إضافة فئة'}
          subtitle="استخدم أسماء عربية واضحة ومختصرة."
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
              label="المعرف slug"
              value={slug}
              onChange={(event) => setSlug(event.target.value)}
              placeholder="photography"
            />
            <FormField
              label="الأيقونة"
              value={icon}
              onChange={(event) => setIcon(event.target.value)}
              placeholder="camera"
            />
            <FormField
              label="الترتيب"
              type="number"
              value={sortOrder}
              onChange={(event) => setSortOrder(event.target.value)}
            />
            <div className="form-actions">
              <ActionButton type="submit">
                {editing ? 'حفظ التعديل' : 'إضافة فئة'}
              </ActionButton>
              {editing ? (
                <ActionButton tone="ghost" type="button" onClick={resetForm}>
                  إلغاء
                </ActionButton>
              ) : null}
            </div>
          </form>
        </FormCard>
      </div>
    </section>
  );
}
