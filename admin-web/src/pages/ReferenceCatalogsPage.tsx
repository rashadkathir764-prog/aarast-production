import { FormEvent, useEffect, useMemo, useState } from 'react';
import {
  createReferenceCatalogItem,
  disableReferenceCatalogItem,
  getReferenceCatalog,
  getReferenceCatalogs,
  publishReferenceCatalogItem,
  ReferenceCatalog,
  ReferenceCatalogItem,
  ReferenceCatalogSummary,
  updateReferenceCatalogItem,
} from '../api/admin';
import { AdminPermission } from '../auth/adminPermissions';
import { Can } from '../auth/Can';
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

const iconOptions = [
  'users',
  'gem',
  'file-check',
  'building-2',
  'utensils',
  'camera',
  'speaker',
  'car',
  'moon-star',
  'bed-double',
  'shirt',
  'scissors',
  'watch',
  'shopping-bag',
  'spray-can',
  'home',
  'key-round',
  'plane',
  'mail',
  'gift',
  'navigation',
  'shield-check',
  'sparkles',
  'wand-2',
  'flower-2',
  'layout-grid',
  'cake-slice',
  'music-2',
  'flower',
  'package-open',
  'hotel',
];

type FormState = {
  key: string;
  nameAr: string;
  nameEn: string;
  groupKey: string;
  groupNameAr: string;
  groupSubtitleAr: string;
  icon: string;
  sortOrder: string;
  showForGroom: boolean;
  showForBride: boolean;
  showForCustomer: boolean;
  showForProvider: boolean;
  isRecommended: boolean;
  isActive: boolean;
};

const emptyForm: FormState = {
  key: '',
  nameAr: '',
  nameEn: '',
  groupKey: '',
  groupNameAr: '',
  groupSubtitleAr: '',
  icon: '',
  sortOrder: '0',
  showForGroom: true,
  showForBride: true,
  showForCustomer: true,
  showForProvider: false,
  isRecommended: false,
  isActive: true,
};

export function ReferenceCatalogsPage() {
  const [summaries, setSummaries] = useState<ReferenceCatalogSummary[]>([]);
  const [catalog, setCatalog] = useState<ReferenceCatalog | null>(null);
  const [selectedKey, setSelectedKey] = useState('');
  const [editing, setEditing] = useState<ReferenceCatalogItem | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [selectedRevision, setSelectedRevision] = useState<Record<string, number>>({});
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function loadCatalogs(preferredKey?: string) {
    setIsLoading(true);
    setError(null);
    try {
      const nextSummaries = await getReferenceCatalogs();
      const nextKey = preferredKey || selectedKey || nextSummaries[0]?.key || '';
      setSummaries(nextSummaries);
      setSelectedKey(nextKey);
      setCatalog(nextKey ? await getReferenceCatalog(nextKey) : null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل الكتالوجات.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    loadCatalogs();
    // Initial load only. Catalog changes are handled explicitly below.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const groupsCount = useMemo(
    () =>
      new Set(
        catalog?.items
          .map((item) => item.current.groupKey)
          .filter((key): key is string => Boolean(key)) ?? [],
      ).size,
    [catalog],
  );

  async function selectCatalog(key: string) {
    setSelectedKey(key);
    setEditing(null);
    setForm(emptyForm);
    setError(null);
    try {
      setCatalog(await getReferenceCatalog(key));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل الكتالوج.');
    }
  }

  function startEdit(item: ReferenceCatalogItem) {
    const value = item.current;
    setEditing(item);
    setForm({
      key: item.key,
      nameAr: value.nameAr,
      nameEn: value.nameEn ?? '',
      groupKey: value.groupKey ?? '',
      groupNameAr: value.groupNameAr ?? '',
      groupSubtitleAr: value.groupSubtitleAr ?? '',
      icon: value.icon ?? '',
      sortOrder: String(value.sortOrder),
      showForGroom: value.showForGroom,
      showForBride: value.showForBride,
      showForCustomer: value.showForCustomer,
      showForProvider: value.showForProvider,
      isRecommended: value.isRecommended,
      isActive: value.isActive,
    });
  }

  function resetForm() {
    setEditing(null);
    setForm(emptyForm);
  }

  async function save(event: FormEvent) {
    event.preventDefault();
    if (!catalog) return;
    setIsSaving(true);
    setError(null);
    setNotice(null);
    const payload = {
      ...(!editing && form.key.trim() ? { key: form.key.trim() } : {}),
      nameAr: form.nameAr.trim(),
      nameEn: form.nameEn.trim() || null,
      groupKey: form.groupKey.trim() || null,
      groupNameAr: form.groupNameAr.trim() || null,
      groupSubtitleAr: form.groupSubtitleAr.trim() || null,
      icon: form.icon || null,
      sortOrder: Number(form.sortOrder) || 0,
      showForGroom: form.showForGroom,
      showForBride: form.showForBride,
      showForCustomer: form.showForCustomer,
      showForProvider: form.showForProvider,
      isRecommended: form.isRecommended,
      isActive: form.isActive,
    };
    try {
      if (editing) {
        await updateReferenceCatalogItem(catalog.key, editing.id, payload);
        setNotice('حُفظت التعديلات كمسودة. راجعها ثم انشرها عندما تكون جاهزة.');
      } else {
        await createReferenceCatalogItem(catalog.key, payload);
        setNotice('أُضيف العنصر كمسودة ولن يظهر للمستخدمين قبل النشر.');
      }
      resetForm();
      await loadCatalogs(catalog.key);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر حفظ العنصر.');
    } finally {
      setIsSaving(false);
    }
  }

  async function publish(item: ReferenceCatalogItem, revision?: number) {
    if (!catalog) return;
    setError(null);
    setNotice(null);
    try {
      await publishReferenceCatalogItem(catalog.key, item.id, revision);
      setNotice(
        revision && revision !== item.currentRevision
          ? 'أُعيد نشر النسخة المحددة بأمان.'
          : 'نُشرت المسودة وستصل للأجهزة عند المزامنة التالية.',
      );
      await loadCatalogs(catalog.key);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر نشر النسخة.');
    }
  }

  if (isLoading) return <LoadingState title="جاري تحميل مركز الكتالوجات" />;
  if (error && !catalog) return <ErrorState message={error} onRetry={() => loadCatalogs()} />;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="مركز المحتوى الديناميكي"
        icon="⌁"
        title="الكتالوجات التي تتحدث دون إصدار جديد"
        description="عدّل القوائم المرنة كمسودة، راجعها، ثم انشرها. النسخة المنشورة فقط تصل إلى المستخدمين والمزوّدين."
        meta={<span>إصدار الكتالوج {catalog?.version ?? 0}</span>}
      />

      <div className="stats-grid">
        <StatCard title="الكتالوجات" value={summaries.length} tone="info" />
        <StatCard title="العناصر" value={catalog?.items.length ?? 0} tone="gold" />
        <StatCard title="المجموعات" value={groupsCount} tone="success" />
        <StatCard
          title="بانتظار النشر"
          value={catalog?.items.filter((item) => item.hasUnpublishedChanges).length ?? 0}
          tone="warning"
        />
      </div>

      {notice ? <div className="catalog-notice" role="status">{notice}</div> : null}
      {error ? <div className="catalog-notice catalog-notice--error" role="alert">{error}</div> : null}

      <SectionCard
        title="الكتالوج النشط"
        subtitle="اختر المجال الذي تريد إدارته. هذه الصفحة لا تتحكم في حالات الدفع أو الصلاحيات الحساسة."
      >
        <label className="form-field catalog-selector">
          <span>الكتالوج</span>
          <select value={selectedKey} onChange={(event) => selectCatalog(event.target.value)}>
            {summaries.map((summary) => (
              <option key={summary.key} value={summary.key}>
                {summary.nameAr} · {summary.publishedCount} منشور
              </option>
            ))}
          </select>
        </label>
      </SectionCard>

      <div className="management-layout catalog-management-layout">
        <SectionCard
          title={catalog?.nameAr ?? 'الكتالوج'}
          subtitle={catalog?.description ?? 'العناصر المنشورة والمسودات الحالية.'}
        >
          {!catalog || catalog.items.length === 0 ? (
            <EmptyState title="لا توجد عناصر" message="أضف أول عنصر كمسودة ثم انشره." />
          ) : (
            <DataTable
              label="عناصر الكتالوج"
              columns={['العنصر', 'المجموعة', 'الجمهور', 'الحالة', 'الترتيب', 'إجراءات']}
              dense
              minWidth={980}
            >
              {catalog.items.map((item) => (
                <tr key={item.id}>
                  <td>
                    <strong>{item.current.nameAr}</strong>
                    <span className="table-subtle">{item.key}</span>
                  </td>
                  <td>
                    {item.current.groupNameAr ?? 'بلا مجموعة'}
                    <span className="table-subtle">{item.current.icon ?? 'بدون أيقونة'}</span>
                  </td>
                  <td>{audienceLabel(item)}</td>
                  <td>
                    <StatusBadge status={item.current.isActive ? 'ACTIVE' : 'DISABLED'} />
                    {item.hasUnpublishedChanges ? (
                      <span className="table-subtle catalog-draft-label">مسودة غير منشورة</span>
                    ) : null}
                  </td>
                  <td>{item.current.sortOrder}</td>
                  <td className="actions-cell">
                    <Can permission={AdminPermission.CATALOG_WRITE}>
                      <div className="catalog-row-actions">
                        <ActionButton tone="ghost" size="small" type="button" onClick={() => startEdit(item)}>
                          تعديل
                        </ActionButton>
                        {item.hasUnpublishedChanges ? (
                          <ActionButton size="small" type="button" onClick={() => publish(item)}>
                            نشر المسودة
                          </ActionButton>
                        ) : null}
                        <div className="catalog-revision-control">
                          <select
                            aria-label={`نسخة ${item.current.nameAr}`}
                            value={selectedRevision[item.id] ?? item.publishedRevision}
                            onChange={(event) =>
                              setSelectedRevision((current) => ({
                                ...current,
                                [item.id]: Number(event.target.value),
                              }))
                            }
                          >
                            {item.revisions.map((revision) => (
                              <option key={revision.revision} value={revision.revision}>
                                نسخة {revision.revision}{revision.revision === item.publishedRevision ? ' · منشورة' : ''}
                              </option>
                            ))}
                          </select>
                          <ActionButton
                            tone="ghost"
                            size="small"
                            type="button"
                            onClick={() => publish(item, selectedRevision[item.id] ?? item.publishedRevision)}
                          >
                            اعتماد
                          </ActionButton>
                        </div>
                        {item.current.isActive ? (
                          <ConfirmDialog
                            title="إيقاف العنصر"
                            message="سيُنشر إصدار غير نشط، ويمكن الرجوع إلى أي نسخة سابقة لاحقًا."
                            confirmLabel="إيقاف"
                            tone="danger"
                            trigger={<ActionButton tone="danger" size="small" type="button">إيقاف</ActionButton>}
                            onConfirm={() =>
                              disableReferenceCatalogItem(catalog.key, item.id).then(() => loadCatalogs(catalog.key))
                            }
                          />
                        ) : null}
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
            title={editing ? 'تحرير مسودة جديدة' : 'إضافة عنصر كمسودة'}
            subtitle="لن يصل أي تغيير إلى التطبيق قبل ضغط نشر المسودة."
          >
            <form className="side-form" onSubmit={save}>
              {!editing ? (
                <FormField
                  label="المعرّف الثابت (اختياري)"
                  value={form.key}
                  onChange={(event) => setForm({ ...form, key: event.target.value })}
                  placeholder="custom-category"
                />
              ) : null}
              <FormField
                label="الاسم العربي"
                value={form.nameAr}
                onChange={(event) => setForm({ ...form, nameAr: event.target.value })}
                required
              />
              <FormField
                label="اسم المجموعة"
                value={form.groupNameAr}
                onChange={(event) => setForm({ ...form, groupNameAr: event.target.value })}
                placeholder="تجهيز العريس"
              />
              <FormField
                label="معرّف المجموعة"
                value={form.groupKey}
                onChange={(event) => setForm({ ...form, groupKey: event.target.value })}
                placeholder="groom-prep"
              />
              <FormField
                label="وصف المجموعة"
                value={form.groupSubtitleAr}
                onChange={(event) => setForm({ ...form, groupSubtitleAr: event.target.value })}
              />
              <label className="form-field">
                <span>الأيقونة</span>
                <select value={form.icon} onChange={(event) => setForm({ ...form, icon: event.target.value })}>
                  <option value="">بدون أيقونة</option>
                  {iconOptions.map((icon) => <option key={icon} value={icon}>{icon}</option>)}
                </select>
              </label>
              <FormField
                label="الترتيب"
                type="number"
                value={form.sortOrder}
                onChange={(event) => setForm({ ...form, sortOrder: event.target.value })}
              />
              <div className="catalog-audience-picker">
                <span>يظهر لمن؟</span>
                <Check label="العريس" checked={form.showForGroom} onChange={(value) => setForm({ ...form, showForGroom: value })} />
                <Check label="العروسة" checked={form.showForBride} onChange={(value) => setForm({ ...form, showForBride: value })} />
                <Check label="المستخدم" checked={form.showForCustomer} onChange={(value) => setForm({ ...form, showForCustomer: value })} />
                <Check label="المزوّد" checked={form.showForProvider} onChange={(value) => setForm({ ...form, showForProvider: value })} />
                <Check label="مقترح افتراضيًا" checked={form.isRecommended} onChange={(value) => setForm({ ...form, isRecommended: value })} />
                <Check label="نشط" checked={form.isActive} onChange={(value) => setForm({ ...form, isActive: value })} />
              </div>
              <div className="form-actions">
                <ActionButton type="submit" disabled={isSaving || !form.nameAr.trim()}>
                  {isSaving ? 'جاري الحفظ…' : editing ? 'حفظ كمسودة' : 'إضافة مسودة'}
                </ActionButton>
                {editing ? <ActionButton tone="ghost" type="button" onClick={resetForm}>إلغاء</ActionButton> : null}
              </div>
            </form>
          </FormCard>
        </Can>
      </div>
    </section>
  );
}

function Check({ label, checked, onChange }: { label: string; checked: boolean; onChange: (value: boolean) => void }) {
  return (
    <label>
      <input type="checkbox" checked={checked} onChange={(event) => onChange(event.target.checked)} />
      <span>{label}</span>
    </label>
  );
}

function audienceLabel(item: ReferenceCatalogItem) {
  const labels = [
    item.current.showForGroom ? 'العريس' : null,
    item.current.showForBride ? 'العروسة' : null,
    item.current.showForProvider ? 'المزوّد' : null,
  ].filter(Boolean);
  return labels.join('، ') || 'مخفي';
}
