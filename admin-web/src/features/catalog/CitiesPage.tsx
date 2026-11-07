// «المدن»: no design of its own (D56). It sits behind the one «الكتالوج»
// link with the catalog's other pages and is drawn with the desk kit the
// designed a08 uses: the table, the name that opens the edit window, a
// disabled city with «فعّلها», and disabling from the edit window.
import { type FormEvent, useCallback, useEffect, useState } from 'react';
import { Plus } from 'lucide-react';
import { type City, createCity, deleteCity, getCities, updateCity } from './api';
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
  grouped,
} from '../../design_system/Desk';
import { DeskModal } from '../../design_system/DeskModal';

type Draft = { nameAr: string; nameEn: string; countryCode: string; sortOrder: string };

const EMPTY: Draft = { nameAr: '', nameEn: '', countryCode: 'YE', sortOrder: '0' };

function draftOf(city: City): Draft {
  return {
    nameAr: city.nameAr,
    nameEn: city.nameEn ?? '',
    countryCode: city.countryCode,
    sortOrder: String(city.sortOrder),
  };
}

export function CitiesPage() {
  const { user } = useAuth();
  const canWrite = hasAdminPermission(user, AdminPermission.CATALOG_WRITE);
  const [items, setItems] = useState<City[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<City | 'new' | null>(null);
  const [draft, setDraft] = useState<Draft>(EMPTY);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setError(null);
    try {
      setItems(await getCities());
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل المدن.');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  function open(target: City | 'new') {
    setEditing(target);
    setDraft(target === 'new' ? EMPTY : draftOf(target));
    setFormError(null);
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!draft.nameAr.trim()) return;
    setSaving(true);
    setFormError(null);
    try {
      const payload = {
        nameAr: draft.nameAr.trim(),
        nameEn: draft.nameEn.trim() || null,
        countryCode: draft.countryCode.trim() || 'YE',
        sortOrder: Number(draft.sortOrder) || 0,
      };
      if (editing === 'new') await createCity(payload);
      else if (editing) await updateCity(editing.id, payload);
      setEditing(null);
      await load();
    } catch (value) {
      setFormError(value instanceof Error ? value.message : 'ما قدرنا نحفظ المدينة.');
    } finally {
      setSaving(false);
    }
  }

  const active = items?.filter((city) => city.isActive).length ?? 0;

  return (
    <section>
      <DeskHeader
        title="المدن"
        sub={items ? `${items.length} مدينة · ${active} نشطة` : undefined}
        actions={
          <Can permission={AdminPermission.CATALOG_WRITE}>
            <DeskButton icon={Plus} onClick={() => open('new')}>
              مدينة جديدة
            </DeskButton>
          </Can>
        }
      />
      <CatalogTabs />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {items === null && !error ? <DeskNote>لحظة، نحمّل المدن…</DeskNote> : null}
      {items && items.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه مدن بعد.</DeskNote>
        </Panel>
      ) : null}
      {items && items.length > 0 ? (
        <DeskTable
          caption="المدن"
          columns={[
            { label: 'المدينة', flex: 3 },
            { label: 'المزودين', flex: 2 },
            { label: 'الخدمات', flex: 2 },
            { label: 'الترتيب', flex: 1 },
            { label: 'الحالة', flex: 2 },
          ]}
          rows={items}
          rowKey={(city) => city.id}
          renderRow={(city) => [
            canWrite ? (
              <button
                key="n"
                type="button"
                className="desk-link-button"
                onClick={() => open(city)}
                aria-label={`عدّل ${city.nameAr}`}
              >
                {city.nameAr}
              </button>
            ) : (
              <TwoLine key="n" main={city.nameAr} sub={city.nameEn ?? undefined} />
            ),
            grouped(city.providersCount ?? 0),
            grouped(city.servicesCount ?? 0),
            city.sortOrder,
            city.isActive ? (
              <Tag key="s" tone="green">نشطة</Tag>
            ) : (
              <span key="s" className="desk-actions">
                <Tag tone="muted">معطّلة</Tag>
                <Can permission={AdminPermission.CATALOG_WRITE}>
                  <ConfirmDialog
                    variant="desk"
                    title={`تفعيل ${city.nameAr}`}
                    effects={['ترجع في قوائم المدن، ويقدر العرسان والمزودين يختارونها.']}
                    confirmLabel="فعّلها"
                    trigger={<SoftAction>فعّلها</SoftAction>}
                    onConfirm={async () => {
                      await updateCity(city.id, { nameAr: city.nameAr, isActive: true });
                      await load();
                    }}
                  />
                </Can>
              </span>
            ),
          ]}
        />
      ) : null}

      <DeskModal
        title={editing === 'new' ? 'مدينة جديدة' : editing ? `تعديل ${editing.nameAr}` : ''}
        open={editing !== null}
        onClose={() => setEditing(null)}
      >
        <form className="desk-form" onSubmit={submit}>
          <label className="desk-field">
            الاسم العربي
            <input
              value={draft.nameAr}
              maxLength={160}
              onChange={(event) => setDraft({ ...draft, nameAr: event.target.value })}
              required
            />
          </label>
          <label className="desk-field">
            الاسم الإنجليزي
            <input
              value={draft.nameEn}
              maxLength={160}
              onChange={(event) => setDraft({ ...draft, nameEn: event.target.value })}
              dir="ltr"
            />
          </label>
          <div className="desk-row">
            <label className="desk-field">
              رمز الدولة
              <input
                value={draft.countryCode}
                maxLength={8}
                onChange={(event) => setDraft({ ...draft, countryCode: event.target.value })}
                dir="ltr"
              />
            </label>
            <label className="desk-field">
              الترتيب
              <input
                type="number"
                // RA-AD-16: the server's rule, a whole number within ±1,000,000.
                step={1}
                min={-1_000_000}
                max={1_000_000}
                value={draft.sortOrder}
                onChange={(event) => setDraft({ ...draft, sortOrder: event.target.value })}
              />
            </label>
          </div>
          {formError ? <DeskNote tone="coral">{formError}</DeskNote> : null}
          <div className="desk-dialog__actions">
            <DeskButton type="submit" disabled={saving || !draft.nameAr.trim()}>
              احفظ
            </DeskButton>
            {editing && editing !== 'new' && editing.isActive ? (
              <ConfirmDialog
                variant="desk"
                title={`تعطيل ${editing.nameAr}`}
                effects={[
                  'تختفي من قوائم المدن عند العرسان والمزودين.',
                  'ما تنحذف، وتقدر ترجّعها بـ«فعّلها».',
                ]}
                confirmLabel="عطّلها"
                confirmTone="coral"
                trigger={<DeskButton tone="white-coral">عطّل المدينة</DeskButton>}
                onConfirm={async () => {
                  await deleteCity(editing.id);
                  setEditing(null);
                  await load();
                }}
              />
            ) : null}
          </div>
        </form>
      </DeskModal>
    </section>
  );
}
