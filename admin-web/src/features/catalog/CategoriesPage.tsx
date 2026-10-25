// a08 «الأقسام» (mobile/test/prototype/admin/admin_screens.dart
// `a08Categories`): one section for the groom and the bride. «الطريقة
// المقترحة» and «المدة» left with D41; one name per section exists, so the
// groom and bride columns show it or «ما يظهر» by the section's audience
// (a name per side waits for A-20). Editing and disabling open from the
// section's name, which the design does not draw but the catalog needs.
// Under each side, the money item its accepted offers are filed under
// (undrawn, the offers review): «أخرى» shows in coral, and a save that lands
// there says so.
import { type FormEvent, useCallback, useEffect, useState } from 'react';
import { Plus } from 'lucide-react';
import {
  createCategory,
  deleteCategory,
  getCategories,
  type ProviderCategory,
  updateCategory,
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
} from '../../design_system/Desk';
import { DeskModal } from '../../design_system/DeskModal';

type Draft = {
  nameAr: string;
  nameEn: string;
  slug: string;
  icon: string;
  sortOrder: string;
  showForGroom: boolean;
  showForBride: boolean;
};

const EMPTY: Draft = {
  nameAr: '',
  nameEn: '',
  slug: '',
  icon: '',
  sortOrder: '0',
  showForGroom: true,
  showForBride: true,
};

function draftOf(category: ProviderCategory): Draft {
  return {
    nameAr: category.nameAr,
    nameEn: category.nameEn ?? '',
    slug: category.slug,
    icon: category.icon ?? '',
    sortOrder: String(category.sortOrder),
    showForGroom: category.showForGroom,
    showForBride: category.showForBride,
  };
}

/**
 * Where an accepted offer of the section is filed in that side's money
 * (G38), under its name: the item, or «أخرى» in coral when no item fits.
 * Undrawn on a08: a section the matcher does not know would otherwise fall
 * into «أخرى» unseen.
 */
function budgetLine(item: string | null | undefined, key: string) {
  if (item === undefined) return null;
  return item === null ? (
    <small key={key} className="desk-ink--coral" style={{ display: 'block' }}>
      في المال: «أخرى»، ما فيه بند يناسبه
    </small>
  ) : (
    <small key={key} className="desk-ink--muted" style={{ display: 'block' }}>
      في المال: {item}
    </small>
  );
}

function side(category: ProviderCategory, shown: boolean, item: string | null | undefined) {
  if (!shown) return <span className="desk-ink--muted">ما يظهر</span>;
  return (
    <span>
      {category.nameAr}
      {budgetLine(item, 'b')}
    </span>
  );
}

const SIDE_NAMES = { groom: 'العريس', bride: 'العروسة', shared: 'الخطة المشتركة' } as const;

/** After a save: the sides where the section's costs would go to «أخرى». */
function otherSides(category: ProviderCategory): string[] {
  const items = category.budgetItems;
  if (!items) return [];
  return (Object.keys(SIDE_NAMES) as Array<keyof typeof SIDE_NAMES>)
    .filter((key) => items[key] === null)
    .map((key) => SIDE_NAMES[key]);
}

export function CategoriesPage() {
  const { user } = useAuth();
  const canWrite = hasAdminPermission(user, AdminPermission.CATALOG_WRITE);
  const [items, setItems] = useState<ProviderCategory[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<ProviderCategory | 'new' | null>(null);
  const [draft, setDraft] = useState<Draft>(EMPTY);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState<ProviderCategory | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setItems(await getCategories());
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الأقسام.');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  function open(target: ProviderCategory | 'new') {
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
        slug: draft.slug.trim() || null,
        icon: draft.icon.trim() || null,
        showForGroom: draft.showForGroom,
        showForBride: draft.showForBride,
        sortOrder: Number(draft.sortOrder) || 0,
      };
      const result =
        editing === 'new'
          ? await createCategory(payload)
          : editing
            ? await updateCategory(editing.id, payload)
            : null;
      setSaved(result);
      setEditing(null);
      await load();
    } catch (value) {
      setFormError(value instanceof Error ? value.message : 'ما قدرنا نحفظ القسم.');
    } finally {
      setSaving(false);
    }
  }

  const noAudience = !draft.showForGroom && !draft.showForBride;

  return (
    <section>
      <DeskHeader
        title="الأقسام"
        sub="قسم واحد للعريس والعروسة"
        actions={
          <Can permission={AdminPermission.CATALOG_WRITE}>
            <DeskButton icon={Plus} onClick={() => open('new')}>
              قسم جديد
            </DeskButton>
          </Can>
        }
      />
      <CatalogTabs />
      {saved && otherSides(saved).length > 0 ? (
        <DeskNote tone="coral">
          {`تكاليف «${saved.nameAr}» تروح «أخرى» عند ${otherSides(saved).join(' و')}: ما فيه بند في المال يناسب اسمه.`}
        </DeskNote>
      ) : null}
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {items === null && !error ? <DeskNote>لحظة، نحمّل الأقسام…</DeskNote> : null}
      {items && items.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه أقسام بعد.</DeskNote>
        </Panel>
      ) : null}
      {items && items.length > 0 ? (
        <DeskTable
          caption="الأقسام"
          columns={[
            { label: 'القسم', flex: 3 },
            { label: 'عند العريس', flex: 2 },
            { label: 'عند العروسة', flex: 2 },
            { label: 'الحالة', flex: 2 },
          ]}
          rows={items}
          rowKey={(category) => category.id}
          renderRow={(category) => [
            canWrite ? (
              <button
                key="n"
                type="button"
                className="desk-link-button"
                onClick={() => open(category)}
                aria-label={`عدّل ${category.nameAr}`}
              >
                {category.nameAr}
              </button>
            ) : (
              <strong key="n">{category.nameAr}</strong>
            ),
            side(category, category.showForGroom, category.budgetItems?.groom),
            side(category, category.showForBride, category.budgetItems?.bride),
            category.isActive ? (
              <Tag key="s" tone="green">نشط</Tag>
            ) : (
              <span key="s" className="desk-actions">
                <Tag tone="muted">معطّل</Tag>
                <Can permission={AdminPermission.CATALOG_WRITE}>
                  <ConfirmDialog
                    variant="desk"
                    title={`تفعيل ${category.nameAr}`}
                    effects={['يرجع يظهر في الأقسام للعرسان والمزودين حسب مساره.']}
                    confirmLabel="فعّله"
                    trigger={<SoftAction>فعّله</SoftAction>}
                    onConfirm={async () => {
                      await updateCategory(category.id, { nameAr: category.nameAr, isActive: true });
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
        title={editing === 'new' ? 'قسم جديد' : editing ? `تعديل ${editing.nameAr}` : ''}
        open={editing !== null}
        onClose={() => setEditing(null)}
      >
        <form className="desk-form" onSubmit={submit}>
          <label className="desk-field">
            الاسم العربي
            <input
              value={draft.nameAr}
              onChange={(event) => setDraft({ ...draft, nameAr: event.target.value })}
              required
            />
          </label>
          <div className="desk-row">
            <label className="desk-field">
              الاسم الإنجليزي
              <input
                value={draft.nameEn}
                onChange={(event) => setDraft({ ...draft, nameEn: event.target.value })}
                dir="ltr"
              />
            </label>
            <label className="desk-field">
              المعرّف
              <input
                value={draft.slug}
                onChange={(event) => setDraft({ ...draft, slug: event.target.value })}
                dir="ltr"
              />
            </label>
          </div>
          <div className="desk-row">
            <label className="desk-field">
              الأيقونة
              <input
                value={draft.icon}
                onChange={(event) => setDraft({ ...draft, icon: event.target.value })}
                dir="ltr"
              />
            </label>
            <label className="desk-field">
              الترتيب
              <input
                type="number"
                value={draft.sortOrder}
                onChange={(event) => setDraft({ ...draft, sortOrder: event.target.value })}
              />
            </label>
          </div>
          <div className="desk-row">
            <label className="desk-check">
              <input
                type="checkbox"
                checked={draft.showForGroom}
                onChange={(event) => setDraft({ ...draft, showForGroom: event.target.checked })}
              />
              يظهر عند العريس
            </label>
            <label className="desk-check">
              <input
                type="checkbox"
                checked={draft.showForBride}
                onChange={(event) => setDraft({ ...draft, showForBride: event.target.checked })}
              />
              يظهر عند العروسة
            </label>
          </div>
          {noAudience ? <DeskNote tone="coral">اختر مسار واحد على الأقل.</DeskNote> : null}
          {formError ? <DeskNote tone="coral">{formError}</DeskNote> : null}
          <div className="desk-dialog__actions">
            <DeskButton type="submit" disabled={saving || noAudience || !draft.nameAr.trim()}>
              احفظ
            </DeskButton>
            {editing && editing !== 'new' && editing.isActive ? (
              <ConfirmDialog
                variant="desk"
                title={`تعطيل ${editing.nameAr}`}
                effects={['يختفي من الأقسام عند العرسان والمزودين.', 'ما ينحذف، وتقدر ترجّعه بـ«فعّله».']}
                confirmLabel="عطّله"
                confirmTone="coral"
                trigger={<DeskButton tone="white-coral">عطّل القسم</DeskButton>}
                onConfirm={async () => {
                  await deleteCategory(editing.id);
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
