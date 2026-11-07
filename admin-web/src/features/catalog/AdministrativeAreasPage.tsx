// «المحافظات والمديريات»: no design of its own (D56). It sits behind the
// one «الكتالوج» link with the catalog's other pages and is drawn with the
// desk kit the designed a08 uses. The order is fixed: a governorate, its
// districts, then a district's areas (منطقة، عزلة، حي، نطاق); each opens its
// edit window, and a stopped one comes back from the same window.
import { type FormEvent, useCallback, useEffect, useState } from 'react';
import { Plus } from 'lucide-react';
import {
  type AdministrativeLocality,
  type AdministrativeLocalityType,
  createDistrict,
  createGovernorate,
  createLocality,
  disableDistrict,
  disableGovernorate,
  disableLocality,
  type District,
  getDistricts,
  getGovernorates,
  getLocalities,
  type Governorate,
  updateDistrict,
  updateGovernorate,
  updateLocality,
} from './api';
import { CatalogTabs } from './CatalogTabs';
import { AdminPermission, Can, hasAdminPermission, useAuth } from '../auth/api';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskRetry,
  DeskTable,
  Panel,
  SoftAction,
  Tag,
  TwoLine,
} from '../../design_system/Desk';
import { DeskModal } from '../../design_system/DeskModal';

type Level = 'governorate' | 'district' | 'locality';

type Editor = {
  level: Level;
  id: string | null;
  code: string;
  nameAr: string;
  nameEn: string;
  sortOrder: string;
  isActive: boolean;
  type: AdministrativeLocalityType;
  parentId: string;
};

const TYPE_LABELS: Record<AdministrativeLocalityType, string> = {
  AREA: 'منطقة',
  ISOLATION: 'عزلة',
  NEIGHBORHOOD: 'حي',
  ZONE: 'نطاق',
};

const LEVEL_NAMES: Record<Level, string> = {
  governorate: 'محافظة',
  district: 'مديرية',
  locality: 'منطقة',
};

function blank(level: Level): Editor {
  return {
    level,
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

function editorOf(level: Level, item: Governorate | District | AdministrativeLocality): Editor {
  return {
    ...blank(level),
    id: item.id,
    code: item.code,
    nameAr: item.nameAr,
    nameEn: item.nameEn ?? '',
    sortOrder: String(item.sortOrder),
    isActive: item.isActive,
    ...('type' in item ? { type: item.type, parentId: item.parentId ?? '' } : {}),
  };
}

const stopped = (isActive: boolean) => (isActive ? '' : ' · موقوفة');

export function AdministrativeAreasPage() {
  const { user } = useAuth();
  const canWrite = hasAdminPermission(user, AdminPermission.CATALOG_WRITE);
  const [governorates, setGovernorates] = useState<Governorate[] | null>(null);
  const [districts, setDistricts] = useState<District[]>([]);
  const [localities, setLocalities] = useState<AdministrativeLocality[]>([]);
  const [governorateId, setGovernorateId] = useState('');
  const [districtId, setDistrictId] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [editor, setEditor] = useState<Editor | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  /** Reads the path down from the governorate, keeping the one picked. */
  const load = useCallback(async (pickGovernorate = '', pickDistrict = '') => {
    setError(null);
    try {
      const nextGovernorates = await getGovernorates();
      const nextGovernorateId = nextGovernorates.some((item) => item.id === pickGovernorate)
        ? pickGovernorate
        : (nextGovernorates[0]?.id ?? '');
      const nextDistricts = nextGovernorateId ? await getDistricts(nextGovernorateId) : [];
      const nextDistrictId = nextDistricts.some((item) => item.id === pickDistrict)
        ? pickDistrict
        : (nextDistricts[0]?.id ?? '');
      const nextLocalities = nextDistrictId ? await getLocalities(nextDistrictId) : [];
      setGovernorates(nextGovernorates);
      setGovernorateId(nextGovernorateId);
      setDistricts(nextDistricts);
      setDistrictId(nextDistrictId);
      setLocalities(nextLocalities);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل المحافظات والمديريات.');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const reload = () => load(governorateId, districtId);

  function open(next: Editor) {
    setEditor(next);
    setFormError(null);
    setSaved(false);
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!editor || !editor.nameAr.trim()) return;
    setSaving(true);
    setFormError(null);
    const payload = {
      ...(!editor.id && editor.code.trim() ? { code: editor.code.trim() } : {}),
      nameAr: editor.nameAr.trim(),
      nameEn: editor.nameEn.trim() || null,
      sortOrder: Number(editor.sortOrder) || 0,
      isActive: editor.isActive,
    };
    try {
      if (editor.level === 'governorate') {
        if (editor.id) await updateGovernorate(editor.id, payload);
        else await createGovernorate(payload);
      } else if (editor.level === 'district') {
        if (editor.id) await updateDistrict(editor.id, payload);
        else await createDistrict(governorateId, payload);
      } else {
        const withPlace = { ...payload, type: editor.type, parentId: editor.parentId || null };
        if (editor.id) await updateLocality(editor.id, withPlace);
        else await createLocality(districtId, withPlace);
      }
      setEditor(null);
      setSaved(true);
      await reload();
    } catch (value) {
      setFormError(value instanceof Error ? value.message : 'ما قدرنا نحفظ.');
    } finally {
      setSaving(false);
    }
  }

  async function stop(target: Editor) {
    if (!target.id) return;
    if (target.level === 'governorate') await disableGovernorate(target.id);
    else if (target.level === 'district') await disableDistrict(target.id);
    else await disableLocality(target.id);
    setEditor(null);
    await reload();
  }

  async function pickGovernorate(id: string) {
    setSaved(false);
    await load(id, '');
  }

  async function pickDistrict(id: string) {
    setSaved(false);
    await load(governorateId, id);
  }

  const governorate = governorates?.find((item) => item.id === governorateId);
  const district = districts.find((item) => item.id === districtId);
  const activeGovernorates = governorates?.filter((item) => item.isActive).length ?? 0;

  return (
    <section>
      <DeskHeader
        title="المحافظات والمديريات"
        sub={governorates ? `${activeGovernorates} محافظة نشطة · محافظة، ثم مديرية، ثم منطقة أو حي` : undefined}
        actions={
          <Can permission={AdminPermission.CATALOG_WRITE}>
            <DeskButton tone="soft" icon={Plus} onClick={() => open(blank('governorate'))}>
              محافظة جديدة
            </DeskButton>
            <DeskButton
              tone="soft"
              icon={Plus}
              disabled={!governorateId}
              onClick={() => open(blank('district'))}
            >
              مديرية جديدة
            </DeskButton>
            <DeskButton icon={Plus} disabled={!districtId} onClick={() => open(blank('locality'))}>
              منطقة جديدة
            </DeskButton>
          </Can>
        }
      />
      <CatalogTabs />
      {error ? <DeskRetry message={error} onRetry={() => void reload()} /> : null}
      {governorates === null && !error ? <DeskNote>لحظة، نحمّل المحافظات…</DeskNote> : null}
      {saved ? <DeskNote>انحفظ، ويوصل الجوالات مع المزامنة الجاية.</DeskNote> : null}
      {governorates && governorates.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه محافظات بعد.</DeskNote>
        </Panel>
      ) : null}
      {governorates && governorates.length > 0 ? (
        <>
          <Panel>
            <div className="desk-row">
              <label className="desk-field">
                المحافظة
                <select value={governorateId} onChange={(event) => void pickGovernorate(event.target.value)}>
                  {governorates.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.nameAr}
                      {stopped(item.isActive)}
                    </option>
                  ))}
                </select>
              </label>
              <label className="desk-field">
                المديرية
                <select
                  value={districtId}
                  onChange={(event) => void pickDistrict(event.target.value)}
                  disabled={districts.length === 0}
                >
                  {districts.length === 0 ? <option value="">ما فيه مديريات</option> : null}
                  {districts.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.nameAr}
                      {stopped(item.isActive)}
                    </option>
                  ))}
                </select>
              </label>
            </div>
            {canWrite && (governorate || district) ? (
              <div className="desk-actions" style={{ marginTop: 10 }}>
                {governorate ? (
                  <SoftAction onClick={() => open(editorOf('governorate', governorate))}>
                    عدّل محافظة {governorate.nameAr}
                  </SoftAction>
                ) : null}
                {district ? (
                  <SoftAction onClick={() => open(editorOf('district', district))}>
                    عدّل مديرية {district.nameAr}
                  </SoftAction>
                ) : null}
              </div>
            ) : null}
          </Panel>
          <div className="desk-gap" />
          {localities.length === 0 ? (
            <Panel>
              <DeskNote>
                {district ? `ما فيه مناطق في ${district.nameAr} بعد.` : 'اختر مديرية تشوف مناطقها.'}
              </DeskNote>
            </Panel>
          ) : (
            <DeskTable
              caption={district ? `مناطق ${district.nameAr}` : 'المناطق'}
              columns={[
                { label: 'المنطقة', flex: 3 },
                { label: 'النوع', flex: 1 },
                { label: 'تتبع', flex: 2 },
                { label: 'الترتيب', flex: 1 },
                { label: 'الحالة', flex: 1 },
              ]}
              rows={localities}
              rowKey={(item) => item.id}
              renderRow={(item) => [
                canWrite ? (
                  <button
                    key="n"
                    type="button"
                    className="desk-link-button"
                    onClick={() => open(editorOf('locality', item))}
                    aria-label={`عدّل ${item.nameAr}`}
                  >
                    {item.nameAr}
                  </button>
                ) : (
                  <TwoLine key="n" main={item.nameAr} sub={item.code} />
                ),
                TYPE_LABELS[item.type],
                localities.find((parent) => parent.id === item.parentId)?.nameAr ?? 'المديرية نفسها',
                item.sortOrder,
                item.isActive ? (
                  <Tag key="s" tone="green">نشطة</Tag>
                ) : (
                  <Tag key="s" tone="muted">موقوفة</Tag>
                ),
              ]}
            />
          )}
        </>
      ) : null}

      <DeskModal
        title={
          editor
            ? editor.id
              ? `تعديل ${editor.nameAr || LEVEL_NAMES[editor.level]}`
              : `${LEVEL_NAMES[editor.level]} جديدة`
            : ''
        }
        open={editor !== null}
        onClose={() => setEditor(null)}
      >
        {editor ? (
          <form className="desk-form" onSubmit={submit}>
            {editor.level === 'district' && !editor.id && governorate ? (
              <DeskNote>تتبع محافظة {governorate.nameAr}.</DeskNote>
            ) : null}
            {editor.level === 'locality' && !editor.id && district ? (
              <DeskNote>تتبع مديرية {district.nameAr}.</DeskNote>
            ) : null}
            {editor.id ? (
              <DeskNote>الرمز الثابت: {editor.code}</DeskNote>
            ) : (
              <label className="desk-field">
                الرمز الثابت (اختياري، ينعمل لحاله لو تركته)
                <input
                  value={editor.code}
                  maxLength={40}
                  onChange={(event) => setEditor({ ...editor, code: event.target.value })}
                  dir="ltr"
                />
              </label>
            )}
            <label className="desk-field">
              الاسم العربي
              <input
                value={editor.nameAr}
                maxLength={160}
                onChange={(event) => setEditor({ ...editor, nameAr: event.target.value })}
                required
              />
            </label>
            <label className="desk-field">
              الاسم الإنجليزي (اختياري)
              <input
                value={editor.nameEn}
                maxLength={160}
                onChange={(event) => setEditor({ ...editor, nameEn: event.target.value })}
                dir="ltr"
              />
            </label>
            {editor.level === 'locality' ? (
              <div className="desk-row">
                <label className="desk-field">
                  النوع
                  <select
                    value={editor.type}
                    onChange={(event) =>
                      setEditor({ ...editor, type: event.target.value as AdministrativeLocalityType })
                    }
                  >
                    {Object.entries(TYPE_LABELS).map(([value, label]) => (
                      <option key={value} value={value}>
                        {label}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="desk-field">
                  تتبع
                  <select
                    value={editor.parentId}
                    onChange={(event) => setEditor({ ...editor, parentId: event.target.value })}
                  >
                    <option value="">المديرية نفسها</option>
                    {localities
                      .filter((item) => item.id !== editor.id)
                      .map((item) => (
                        <option key={item.id} value={item.id}>
                          {item.nameAr}
                        </option>
                      ))}
                  </select>
                </label>
              </div>
            ) : null}
            <label className="desk-field">
              الترتيب
              <input
                type="number"
                // RA-AD-16: the server's rule, a whole number within ±1,000,000.
                step={1}
                min={-1_000_000}
                max={1_000_000}
                value={editor.sortOrder}
                onChange={(event) => setEditor({ ...editor, sortOrder: event.target.value })}
              />
            </label>
            <label className="desk-check">
              <input
                type="checkbox"
                checked={editor.isActive}
                onChange={(event) => setEditor({ ...editor, isActive: event.target.checked })}
              />
              نشطة وتطلع في الاقتراحات
            </label>
            {formError ? <DeskNote tone="coral">{formError}</DeskNote> : null}
            <div className="desk-dialog__actions">
              <DeskButton type="submit" disabled={saving || !editor.nameAr.trim()}>
                احفظ
              </DeskButton>
              {editor.id && editor.isActive ? (
                <ConfirmDialog                  title={`إيقاف ${editor.nameAr}`}
                  effects={[
                    'تختفي من الاقتراحات الجديدة في الجوال.',
                    'ما تنحذف، والبيانات القديمة المرتبطة فيها تبقى.',
                  ]}
                  confirmLabel="أوقفها"
                  confirmTone="coral"
                  trigger={<DeskButton tone="white-coral">أوقف</DeskButton>}
                  onConfirm={() => stop(editor)}
                />
              ) : null}
            </div>
          </form>
        ) : null}
      </DeskModal>
    </section>
  );
}
