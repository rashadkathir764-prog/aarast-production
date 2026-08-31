import { FormEvent, useEffect, useState } from 'react';
import {
  AdministrativeLocality,
  AdministrativeLocalityType,
  createDistrict,
  createGovernorate,
  createLocality,
  disableDistrict,
  disableGovernorate,
  disableLocality,
  District,
  getDistricts,
  getGovernorates,
  getLocalities,
  Governorate,
  updateDistrict,
  updateGovernorate,
  updateLocality,
} from './api';
import { AdminPermission } from '../auth/api';
import { Can } from '../auth/api';
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

type EditorMode = 'governorate' | 'district' | 'locality';

type EditorState = {
  mode: EditorMode;
  id: string | null;
  code: string;
  nameAr: string;
  nameEn: string;
  sortOrder: string;
  isActive: boolean;
  type: AdministrativeLocalityType;
  parentId: string;
};

function emptyEditor(mode: EditorMode): EditorState {
  return {
    mode,
    id: null,
    code: '',
    nameAr: '',
    nameEn: '',
    sortOrder: '0',
    isActive: true,
    type: 'NEIGHBORHOOD',
    parentId: '',
  };
}

const typeLabels: Record<AdministrativeLocalityType, string> = {
  AREA: 'منطقة',
  ISOLATION: 'عزلة',
  NEIGHBORHOOD: 'حي',
  ZONE: 'نطاق',
};

export function AdministrativeAreasPage() {
  const [governorates, setGovernorates] = useState<Governorate[]>([]);
  const [districts, setDistricts] = useState<District[]>([]);
  const [localities, setLocalities] = useState<AdministrativeLocality[]>([]);
  const [governorateId, setGovernorateId] = useState('');
  const [districtId, setDistrictId] = useState('');
  const [editor, setEditor] = useState<EditorState>(emptyEditor('locality'));
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function loadAll(preferredGovernorate?: string, preferredDistrict?: string) {
    setIsLoading(true);
    setError(null);
    try {
      const nextGovernorates = await getGovernorates();
      const nextGovernorateId =
        preferredGovernorate || governorateId || nextGovernorates[0]?.id || '';
      const nextDistricts = nextGovernorateId
        ? await getDistricts(nextGovernorateId)
        : [];
      const nextDistrictId =
        preferredDistrict || districtId || nextDistricts[0]?.id || '';
      const nextLocalities = nextDistrictId
        ? await getLocalities(nextDistrictId)
        : [];
      setGovernorates(nextGovernorates);
      setGovernorateId(nextGovernorateId);
      setDistricts(nextDistricts);
      setDistrictId(nextDistrictId);
      setLocalities(nextLocalities);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل الهيكل الجغرافي.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    loadAll();
    // Initial hierarchy load only.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function selectGovernorate(id: string) {
    setGovernorateId(id);
    setDistrictId('');
    setLocalities([]);
    setError(null);
    try {
      const nextDistricts = await getDistricts(id);
      const nextDistrictId = nextDistricts[0]?.id ?? '';
      setDistricts(nextDistricts);
      setDistrictId(nextDistrictId);
      setLocalities(nextDistrictId ? await getLocalities(nextDistrictId) : []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل المديريات.');
    }
  }

  async function selectDistrict(id: string) {
    setDistrictId(id);
    setError(null);
    try {
      setLocalities(id ? await getLocalities(id) : []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل المناطق والأحياء.');
    }
  }

  function editGovernorate(item: Governorate) {
    setEditor({
      ...emptyEditor('governorate'),
      id: item.id,
      code: item.code,
      nameAr: item.nameAr,
      nameEn: item.nameEn,
      sortOrder: String(item.sortOrder),
      isActive: item.isActive,
    });
  }

  function editDistrict(item: District) {
    setEditor({
      ...emptyEditor('district'),
      id: item.id,
      code: item.code,
      nameAr: item.nameAr,
      nameEn: item.nameEn,
      sortOrder: String(item.sortOrder),
      isActive: item.isActive,
    });
  }

  function editLocality(item: AdministrativeLocality) {
    setEditor({
      mode: 'locality',
      id: item.id,
      code: item.code,
      nameAr: item.nameAr,
      nameEn: item.nameEn ?? '',
      sortOrder: String(item.sortOrder),
      isActive: item.isActive,
      type: item.type,
      parentId: item.parentId ?? '',
    });
  }

  async function save(event: FormEvent) {
    event.preventDefault();
    setIsSaving(true);
    setError(null);
    setNotice(null);
    const payload = {
      ...(!editor.id && editor.code.trim() ? { code: editor.code.trim() } : {}),
      nameAr: editor.nameAr.trim(),
      nameEn: editor.nameEn.trim() || null,
      sortOrder: Number(editor.sortOrder) || 0,
      isActive: editor.isActive,
    };
    try {
      if (editor.mode === 'governorate') {
        if (editor.id) await updateGovernorate(editor.id, payload);
        else await createGovernorate(payload);
      } else if (editor.mode === 'district') {
        if (!governorateId) throw new Error('اختر محافظة أولًا.');
        if (editor.id) await updateDistrict(editor.id, payload);
        else await createDistrict(governorateId, payload);
      } else {
        if (!districtId) throw new Error('اختر مديرية أولًا.');
        const localityPayload = {
          ...payload,
          type: editor.type,
          parentId: editor.parentId || null,
        };
        if (editor.id) await updateLocality(editor.id, localityPayload);
        else await createLocality(districtId, localityPayload);
      }
      setNotice(editor.id ? 'حُفظ التعديل وسيصل مع المزامنة التالية.' : 'أُضيف الموقع بنجاح وسيصل مع المزامنة التالية.');
      setEditor(emptyEditor(editor.mode));
      await loadAll(governorateId, districtId);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر حفظ الموقع.');
    } finally {
      setIsSaving(false);
    }
  }

  const selectedGovernorate = governorates.find((item) => item.id === governorateId);
  const selectedDistrict = districts.find((item) => item.id === districtId);
  const activeLocalities = localities.filter((item) => item.isActive).length;

  if (isLoading) return <LoadingState title="جاري تحميل المحافظات والمديريات" />;
  if (error && governorates.length === 0) return <ErrorState message={error} onRetry={() => loadAll()} />;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="اليمن · بيانات مترابطة"
        icon="⌖"
        title="المحافظات والمديريات والمناطق"
        description="هيكل واحد مرتب يظهر في الهاتف فور المزامنة: محافظة، ثم مديرية، ثم منطقة أو عزلة أو حي."
        meta={<span>{governorates.filter((item) => item.isActive).length} محافظة نشطة</span>}
      />

      <div className="stats-grid">
        <StatCard title="المحافظات" value={governorates.length} tone="info" />
        <StatCard title="مديريات المحافظة" value={districts.length} tone="gold" />
        <StatCard title="مناطق المديرية" value={localities.length} tone="warning" />
        <StatCard title="النشطة هنا" value={activeLocalities} tone="success" />
      </div>

      {notice ? <div className="catalog-notice" role="status">{notice}</div> : null}
      {error ? <div className="catalog-notice catalog-notice--error" role="alert">{error}</div> : null}

      <SectionCard
        title="مسار الموقع"
        subtitle="الترتيب إلزامي حتى لا تظهر الأحياء منفصلة أو تابعة لمديرية خاطئة."
      >
        <div className="geography-path">
          <label className="form-field">
            <span>1 · المحافظة</span>
            <select value={governorateId} onChange={(event) => selectGovernorate(event.target.value)}>
              {governorates.map((item) => (
                <option key={item.id} value={item.id}>{item.nameAr}{item.isActive ? '' : ' · معطلة'}</option>
              ))}
            </select>
          </label>
          <label className="form-field">
            <span>2 · المديرية</span>
            <select value={districtId} onChange={(event) => selectDistrict(event.target.value)} disabled={!governorateId}>
              {districts.length === 0 ? <option value="">لا توجد مديريات</option> : null}
              {districts.map((item) => (
                <option key={item.id} value={item.id}>{item.nameAr}{item.isActive ? '' : ' · معطلة'}</option>
              ))}
            </select>
          </label>
          <div className="geography-path__actions">
            <Can permission={AdminPermission.CATALOG_WRITE}>
              <ActionButton tone="ghost" size="small" type="button" onClick={() => setEditor(emptyEditor('governorate'))}>+ محافظة</ActionButton>
              <ActionButton tone="ghost" size="small" type="button" disabled={!governorateId} onClick={() => setEditor(emptyEditor('district'))}>+ مديرية</ActionButton>
              <ActionButton size="small" type="button" disabled={!districtId} onClick={() => setEditor(emptyEditor('locality'))}>+ منطقة أو حي</ActionButton>
            </Can>
          </div>
        </div>
        <div className="geography-current-actions">
          {selectedGovernorate ? (
            <>
              <span>المحافظة: <strong>{selectedGovernorate.nameAr}</strong></span>
              <Can permission={AdminPermission.CATALOG_WRITE}>
                <ActionButton tone="ghost" size="small" type="button" onClick={() => editGovernorate(selectedGovernorate)}>تعديل المحافظة</ActionButton>
              </Can>
            </>
          ) : null}
          {selectedDistrict ? (
            <>
              <span>المديرية: <strong>{selectedDistrict.nameAr}</strong></span>
              <Can permission={AdminPermission.CATALOG_WRITE}>
                <ActionButton tone="ghost" size="small" type="button" onClick={() => editDistrict(selectedDistrict)}>تعديل المديرية</ActionButton>
              </Can>
            </>
          ) : null}
        </div>
      </SectionCard>

      <div className="management-layout geography-management-layout">
        <SectionCard
          title={selectedDistrict ? `مناطق وأحياء ${selectedDistrict.nameAr}` : 'المناطق والأحياء'}
          subtitle="يمكن إبقاء الإدخال اليدوي في الهاتف عندما لا توجد نتيجة مناسبة."
        >
          {localities.length === 0 ? (
            <EmptyState
              title="لا توجد مناطق بعد"
              message={districtId ? 'أضف أول منطقة أو حي لهذه المديرية.' : 'اختر مديرية لعرض مناطقها.'}
            />
          ) : (
            <DataTable label="المناطق والأحياء" columns={['الاسم', 'النوع', 'يتبع', 'الحالة', 'الترتيب', 'إجراءات']} dense minWidth={780}>
              {localities.map((item) => (
                <tr key={item.id}>
                  <td><strong>{item.nameAr}</strong><span className="table-subtle">{item.code}</span></td>
                  <td>{typeLabels[item.type]}</td>
                  <td>{localities.find((parent) => parent.id === item.parentId)?.nameAr ?? 'المديرية مباشرة'}</td>
                  <td><StatusBadge status={item.isActive ? 'ACTIVE' : 'DISABLED'} /></td>
                  <td>{item.sortOrder}</td>
                  <td className="actions-cell">
                    <Can permission={AdminPermission.CATALOG_WRITE}>
                      <div className="actions">
                        <ActionButton tone="ghost" size="small" type="button" onClick={() => editLocality(item)}>تعديل</ActionButton>
                        {item.isActive ? (
                          <ConfirmDialog
                            title="إيقاف الموقع"
                            message="سيختفي من الاقتراحات الجديدة دون حذف البيانات القديمة المرتبطة به."
                            confirmLabel="إيقاف"
                            tone="danger"
                            trigger={<ActionButton tone="danger" size="small" type="button">إيقاف</ActionButton>}
                            onConfirm={() => disableLocality(item.id).then(() => loadAll(governorateId, districtId))}
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
          <FormCard title={editorTitle(editor)} subtitle={editorSubtitle(editor.mode, selectedGovernorate, selectedDistrict)}>
            <form className="side-form" onSubmit={save}>
              {!editor.id ? (
                <FormField
                  label="الرمز الثابت (اختياري)"
                  value={editor.code}
                  onChange={(event) => setEditor({ ...editor, code: event.target.value })}
                  placeholder="يُنشأ تلقائيًا إن تُرك فارغًا"
                />
              ) : (
                <div className="immutable-code"><span>الرمز الثابت</span><strong>{editor.code}</strong></div>
              )}
              <FormField label="الاسم العربي" value={editor.nameAr} onChange={(event) => setEditor({ ...editor, nameAr: event.target.value })} required />
              <FormField label="الاسم الإنجليزي (اختياري)" value={editor.nameEn} onChange={(event) => setEditor({ ...editor, nameEn: event.target.value })} />
              {editor.mode === 'locality' ? (
                <>
                  <label className="form-field">
                    <span>النوع</span>
                    <select value={editor.type} onChange={(event) => setEditor({ ...editor, type: event.target.value as AdministrativeLocalityType })}>
                      {Object.entries(typeLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                    </select>
                  </label>
                  <label className="form-field">
                    <span>يتبع (اختياري)</span>
                    <select value={editor.parentId} onChange={(event) => setEditor({ ...editor, parentId: event.target.value })}>
                      <option value="">المديرية مباشرة</option>
                      {localities.filter((item) => item.id !== editor.id).map((item) => <option key={item.id} value={item.id}>{item.nameAr}</option>)}
                    </select>
                  </label>
                </>
              ) : null}
              <FormField label="الترتيب" type="number" value={editor.sortOrder} onChange={(event) => setEditor({ ...editor, sortOrder: event.target.value })} />
              <div className="catalog-audience-picker geography-active-picker">
                <span>حالة الظهور</span>
                <label>
                  <input type="checkbox" checked={editor.isActive} onChange={(event) => setEditor({ ...editor, isActive: event.target.checked })} />
                  <span>نشط ويظهر في الاقتراحات</span>
                </label>
              </div>
              <div className="form-actions">
                <ActionButton type="submit" disabled={isSaving || !editor.nameAr.trim()}>{isSaving ? 'جاري الحفظ…' : editor.id ? 'حفظ التعديل' : 'إضافة'}</ActionButton>
                {editor.id ? <ActionButton tone="ghost" type="button" onClick={() => setEditor(emptyEditor(editor.mode))}>إلغاء</ActionButton> : null}
                {editor.id && editor.isActive ? <DisableCurrent editor={editor} onDone={() => loadAll(governorateId, districtId)} /> : null}
              </div>
            </form>
          </FormCard>
        </Can>
      </div>
    </section>
  );
}

function editorTitle(editor: EditorState) {
  const entity = editor.mode === 'governorate' ? 'محافظة' : editor.mode === 'district' ? 'مديرية' : 'منطقة أو حي';
  return editor.id ? `تعديل ${entity}` : `إضافة ${entity}`;
}

function editorSubtitle(mode: EditorMode, governorate?: Governorate, district?: District) {
  if (mode === 'district') return governorate ? `ستتبع محافظة ${governorate.nameAr}.` : 'اختر محافظة أولًا.';
  if (mode === 'locality') return district ? `ستتبع مديرية ${district.nameAr}.` : 'اختر مديرية أولًا.';
  return 'المحافظة هي المستوى الأعلى في التسلسل.';
}

function DisableCurrent({ editor, onDone }: { editor: EditorState; onDone: () => Promise<void> }) {
  async function disable() {
    if (!editor.id) return;
    if (editor.mode === 'governorate') await disableGovernorate(editor.id);
    else if (editor.mode === 'district') await disableDistrict(editor.id);
    else await disableLocality(editor.id);
    await onDone();
  }
  return (
    <ConfirmDialog
      title="إيقاف العنصر"
      message="سيختفي من القوائم الجديدة دون حذف السجلات القديمة."
      confirmLabel="إيقاف"
      tone="danger"
      trigger={<ActionButton tone="danger" type="button">إيقاف</ActionButton>}
      onConfirm={disable}
    />
  );
}
