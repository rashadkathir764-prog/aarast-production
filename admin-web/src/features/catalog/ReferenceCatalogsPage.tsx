// a09 «الكتالوجات»: the starter catalogs that change in the app without a
// release, each item with its days before the wedding and its audience, and
// the published version beside the draft. «ارجع للمنشور» waits for A-19 (no
// call drops a draft). Adding and editing are not drawn and stay, in a
// window, so the days before the wedding can still change from the panel.
// D73: a money item names the provider sections its «ابحث» searches and its
// accepted offers are filed from; none chosen leaves it to the words.
import { type FormEvent, type ReactNode, useCallback, useEffect, useState } from 'react';
import {
  createReferenceCatalogItem,
  disableReferenceCatalogItem,
  getCategories,
  getReferenceCatalog,
  getReferenceCatalogs,
  publishReferenceCatalogItem,
  type ProviderCategory,
  type ReferenceCatalog,
  type ReferenceCatalogItem,
  type ReferenceCatalogItemPayload,
  type ReferenceCatalogRevision,
  type ReferenceCatalogSummary,
  updateReferenceCatalogItem,
} from './api';
import { CatalogTabs } from './CatalogTabs';
import { AdminPermission, Can } from '../auth/api';
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
import { countUnit } from '../../platform/i18n/deskTime';

const TASKS = 'tasks.starter';
const MONEY = 'money.starter.categories';

/** The catalog switch as the design names it. */
const CATALOG_LABELS: Record<string, string> = {
  'tasks.starter': 'قوالب المهام',
  'money.starter.categories': 'تصنيفات الميزانية',
};

const ICONS = [
  'users', 'gem', 'file-check', 'building-2', 'utensils', 'camera', 'speaker', 'car',
  'moon-star', 'bed-double', 'shirt', 'scissors', 'watch', 'shopping-bag', 'spray-can',
  'home', 'key-round', 'plane', 'mail', 'gift', 'navigation', 'shield-check', 'sparkles',
  'wand-2', 'flower-2', 'layout-grid', 'cake-slice', 'music-2', 'flower', 'package-open', 'hotel',
];

/**
 * The task categories the app files a task under (its «القسم»), in the
 * app's own words. Left empty («تلقائي») the app files a built-in task where
 * it always has; GENERAL is «عامة» chosen on purpose.
 */
const TASK_CATEGORIES: ReadonlyArray<readonly [string, string]> = [
  ['GENERAL', 'عامة'],
  ['VENUE', 'القاعة'],
  ['GUESTS', 'الضيوف'],
  ['MONEY', 'المال'],
  ['PROVIDERS', 'المزودين'],
  ['ATTIRE', 'الملابس'],
  ['PHOTOGRAPHY', 'التصوير'],
  ['CATERING', 'الضيافة'],
  ['DECOR', 'الزينة'],
  ['DOCUMENTS', 'المستندات'],
];

function taskCategory(revision: ReferenceCatalogRevision | null): string {
  const value = revision?.metadata?.taskCategory;
  return typeof value === 'string' && TASK_CATEGORIES.some(([key]) => key === value) ? value : '';
}

function daysBefore(revision: ReferenceCatalogRevision | null): number | null {
  const value = revision?.metadata?.daysBefore;
  const days = typeof value === 'number' ? value : Number(value);
  return value === undefined || value === null || !Number.isFinite(days) ? null : days;
}

/** D73: the provider sections (by slug) a money item is linked to. */
function providerCategorySlugs(revision: ReferenceCatalogRevision | null): string[] {
  const value = revision?.metadata?.providerCategorySlugs;
  return Array.isArray(value) ? value.filter((slug): slug is string => typeof slug === 'string') : [];
}

function daysWords(days: number | null): string {
  return days === null ? '—' : countUnit(days, 'day');
}

function audience(revision: ReferenceCatalogRevision): string {
  if (revision.showForGroom && revision.showForBride) return 'العريس والعروسة';
  if (revision.showForGroom) return 'العريس';
  if (revision.showForBride) return 'العروسة';
  return '—';
}

function itemTag(item: ReferenceCatalogItem) {
  if (item.hasUnpublishedChanges) return <Tag tone="saffron">مسودة</Tag>;
  if (item.published?.isActive === false) return <Tag tone="muted">موقوفة</Tag>;
  return <Tag tone="green">منشورة</Tag>;
}

type Draft = {
  key: string;
  nameAr: string;
  groupNameAr: string;
  groupKey: string;
  days: string;
  /** A task's category; empty leaves it to the app («تلقائي»). */
  category: string;
  /** A money item's linked provider sections; empty leaves it to the words. */
  slugs: string[];
  icon: string;
  sortOrder: string;
  showForGroom: boolean;
  showForBride: boolean;
  isRecommended: boolean;
};

const EMPTY: Draft = {
  key: '',
  nameAr: '',
  groupNameAr: '',
  groupKey: '',
  days: '',
  category: '',
  slugs: [],
  icon: '',
  sortOrder: '0',
  showForGroom: true,
  showForBride: true,
  isRecommended: false,
};

export function ReferenceCatalogsPage() {
  const [summaries, setSummaries] = useState<ReferenceCatalogSummary[]>([]);
  const [catalog, setCatalog] = useState<ReferenceCatalog | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [editing, setEditing] = useState<ReferenceCatalogItem | 'new' | null>(null);
  const [draft, setDraft] = useState<Draft>(EMPTY);
  const [busy, setBusy] = useState(false);
  const [sections, setSections] = useState<ProviderCategory[] | null>(null);
  const [sectionsError, setSectionsError] = useState<string | null>(null);

  const open = useCallback(async (key: string) => {
    setError(null);
    try {
      const next = await getReferenceCatalog(key);
      setCatalog(next);
      setSelectedId((current) => {
        if (next.items.some((item) => item.id === current)) return current;
        return (next.items.find((item) => item.hasUnpublishedChanges) ?? next.items[0])?.id ?? null;
      });
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الكتالوج.');
    }
  }, []);

  const load = useCallback(async () => {
    setError(null);
    try {
      const list = await getReferenceCatalogs();
      setSummaries(list);
      const first = list.find((summary) => summary.key === TASKS) ?? list[0];
      if (first) await open(first.key);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الكتالوجات.');
    }
  }, [open]);

  useEffect(() => {
    void load();
  }, [load]);

  const isTasks = catalog?.key === TASKS;
  const isMoney = catalog?.key === MONEY;

  // The active provider sections a money item may be linked to.
  useEffect(() => {
    if (!isMoney || sections !== null) return;
    let live = true;
    setSectionsError(null);
    getCategories()
      .then((list) => {
        if (live) setSections(list.filter((section) => section.isActive));
      })
      .catch((value: unknown) => {
        if (live) setSectionsError(value instanceof Error ? value.message : 'ما قدرنا نحمّل أقسام المزودين.');
      });
    return () => {
      live = false;
    };
  }, [isMoney, sections]);
  const selected = catalog?.items.find((item) => item.id === selectedId) ?? null;

  async function publish(item: ReferenceCatalogItem) {
    if (!catalog) return;
    setBusy(true);
    setActionError(null);
    try {
      await publishReferenceCatalogItem(catalog.key, item.id);
      await open(catalog.key);
    } catch (value) {
      setActionError(value instanceof Error ? value.message : 'ما قدرنا ننشر المسودة.');
    } finally {
      setBusy(false);
    }
  }

  function edit(target: ReferenceCatalogItem | 'new') {
    setEditing(target);
    setActionError(null);
    if (target === 'new') {
      setDraft(EMPTY);
      return;
    }
    const value = target.current;
    const days = daysBefore(value);
    setDraft({
      key: target.key,
      nameAr: value.nameAr,
      groupNameAr: value.groupNameAr ?? '',
      groupKey: value.groupKey ?? '',
      days: days === null ? '' : String(days),
      category: taskCategory(value),
      slugs: providerCategorySlugs(value),
      icon: value.icon ?? '',
      sortOrder: String(value.sortOrder),
      showForGroom: value.showForGroom,
      showForBride: value.showForBride,
      isRecommended: value.isRecommended,
    });
  }

  async function save(event: FormEvent) {
    event.preventDefault();
    if (!catalog || !editing || !draft.nameAr.trim()) return;
    setBusy(true);
    setActionError(null);
    const base = editing === 'new' ? null : editing.current;
    let metadata: Record<string, unknown> | undefined;
    if (isTasks) {
      metadata = {
        ...(base?.metadata ?? {}),
        daysBefore: draft.days.trim() === '' ? null : Number(draft.days),
      };
      // «تلقائي» stores nothing: the app keeps its own filing for the task.
      if (draft.category) metadata.taskCategory = draft.category;
      else delete metadata.taskCategory;
    }
    if (isMoney) {
      metadata = { ...(base?.metadata ?? {}) };
      // No section chosen stores nothing: the app files the item by its words.
      if (draft.slugs.length > 0) metadata.providerCategorySlugs = draft.slugs;
      else delete metadata.providerCategorySlugs;
    }
    const payload = {
      ...(editing === 'new' && draft.key.trim() ? { key: draft.key.trim() } : {}),
      nameAr: draft.nameAr.trim(),
      groupNameAr: draft.groupNameAr.trim() || null,
      groupKey: draft.groupKey.trim() || null,
      icon: draft.icon || null,
      sortOrder: Number(draft.sortOrder) || 0,
      showForGroom: draft.showForGroom,
      showForBride: draft.showForBride,
      isRecommended: draft.isRecommended,
      ...(metadata ? { metadata: metadata as ReferenceCatalogItemPayload['metadata'] } : {}),
    };
    try {
      if (editing === 'new') {
        const created = await createReferenceCatalogItem(catalog.key, payload);
        setSelectedId(created.id);
      } else {
        await updateReferenceCatalogItem(catalog.key, editing.id, payload);
        setSelectedId(editing.id);
      }
      setEditing(null);
      await open(catalog.key);
    } catch (value) {
      setActionError(value instanceof Error ? value.message : 'ما قدرنا نحفظ.');
    } finally {
      setBusy(false);
    }
  }

  const noun = isTasks ? 'المهمة' : 'البند';
  const columns = isTasks
    ? [
        { label: 'المهمة', flex: 4 },
        { label: 'قبل العرس', flex: 2 },
        { label: 'لمين', flex: 2 },
        { label: 'الحالة', flex: 2 },
      ]
    : [
        { label: 'البند', flex: 4 },
        { label: 'لمين', flex: 2 },
        { label: 'الحالة', flex: 2 },
      ];

  return (
    <section className="desk-fill-page">
      <DeskHeader
        title="الكتالوجات"
        sub="تتحدث في التطبيق بدون إصدار جديد"
        actions={summaries.map((summary) => (
          <DeskButton
            key={summary.key}
            tone={summary.key === catalog?.key ? 'teal' : 'soft'}
            pressed={summary.key === catalog?.key}
            onClick={() => void open(summary.key)}
          >
            {CATALOG_LABELS[summary.key] ?? summary.nameAr}
          </DeskButton>
        ))}
      />
      <CatalogTabs />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {catalog === null && !error ? <DeskNote>لحظة، نحمّل الكتالوج…</DeskNote> : null}
      {catalog ? (
        <div className="desk-split">
          <div className="desk-split__main" style={{ flex: 3 }}>
            {catalog.items.length === 0 ? (
              <Panel>
                <DeskNote>ما فيه عناصر بعد.</DeskNote>
              </Panel>
            ) : (
              <DeskTable
                caption={CATALOG_LABELS[catalog.key] ?? catalog.nameAr}
                columns={columns}
                rows={catalog.items}
                rowKey={(item) => item.id}
                highlight={(item) => item.id === selectedId}
                onRowClick={(item) => setSelectedId(item.id)}
                rowLabel={(item) => `اقرأ ${item.current.nameAr}`}
                renderRow={(item) => {
                  const cells: ReactNode[] = [
                    <TwoLine key="n" main={item.current.nameAr} sub={item.current.groupNameAr ?? undefined} />,
                    <span key="a" className="desk-nowrap">{audience(item.current)}</span>,
                    <span key="t">{itemTag(item)}</span>,
                  ];
                  if (isTasks) cells.splice(1, 0, daysWords(daysBefore(item.current)));
                  return cells;
                }}
              />
            )}
          </div>
          <div className="desk-split__side desk-split__side--fill" style={{ flex: 2 }}>
            <Panel>
              {selected ? (
                <>
                  <h2 className="desk-panel__title">
                    {selected.current.nameAr} · {selected.hasUnpublishedChanges ? 'مسودة' : 'منشورة'}
                  </h2>
                  {selected.hasUnpublishedChanges ? (
                    <Compare item={selected} isTasks={isTasks} />
                  ) : null}
                  <Can permission={AdminPermission.CATALOG_WRITE}>
                    <div className="desk-report__actions">
                      {selected.hasUnpublishedChanges ? (
                        <DeskButton disabled={busy} onClick={() => void publish(selected)}>
                          انشر المسودة
                        </DeskButton>
                      ) : null}
                      <DeskButton tone="soft" onClick={() => edit(selected)}>
                        عدّل
                      </DeskButton>
                    </div>
                  </Can>
                  {actionError && editing === null ? <DeskNote tone="coral">{actionError}</DeskNote> : null}
                  <DeskNote>النشر يوصل الخطط الجديدة بس، والخطط القائمة ما تتغير.</DeskNote>
                </>
              ) : null}
              <Can permission={AdminPermission.CATALOG_WRITE}>
                <div className="desk-report__actions">
                  <SoftAction onClick={() => edit('new')}>{isTasks ? 'أضف مهمة' : 'أضف بند'}</SoftAction>
                </div>
              </Can>
            </Panel>
          </div>
        </div>
      ) : null}

      <DeskModal
        title={editing === 'new' ? (isTasks ? 'مهمة جديدة' : 'بند جديد') : editing ? `تعديل ${editing.current.nameAr}` : ''}
        open={editing !== null}
        onClose={() => setEditing(null)}
      >
        <form className="desk-form" onSubmit={save}>
          <label className="desk-field">
            {noun}
            <input
              value={draft.nameAr}
              onChange={(event) => setDraft({ ...draft, nameAr: event.target.value })}
              required
            />
          </label>
          <div className="desk-row">
            <label className="desk-field">
              المجموعة
              <input
                value={draft.groupNameAr}
                onChange={(event) => setDraft({ ...draft, groupNameAr: event.target.value })}
              />
            </label>
            <label className="desk-field">
              معرّف المجموعة
              <input
                value={draft.groupKey}
                onChange={(event) => setDraft({ ...draft, groupKey: event.target.value })}
                dir="ltr"
              />
            </label>
          </div>
          <div className="desk-row">
            {isTasks ? (
              <label className="desk-field">
                قبل العرس (أيام)
                <input
                  type="number"
                  min={0}
                  value={draft.days}
                  onChange={(event) => setDraft({ ...draft, days: event.target.value })}
                />
              </label>
            ) : null}
            {isTasks ? (
              <label className="desk-field">
                القسم
                <select
                  value={draft.category}
                  onChange={(event) => setDraft({ ...draft, category: event.target.value })}
                >
                  <option value="">تلقائي</option>
                  {TASK_CATEGORIES.map(([key, label]) => (
                    <option key={key} value={key}>
                      {label}
                    </option>
                  ))}
                </select>
              </label>
            ) : null}
            <label className="desk-field">
              الأيقونة
              <select value={draft.icon} onChange={(event) => setDraft({ ...draft, icon: event.target.value })}>
                <option value="">بدون</option>
                {ICONS.map((icon) => (
                  <option key={icon} value={icon}>
                    {icon}
                  </option>
                ))}
              </select>
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
          {isMoney ? (
            <div className="desk-field" role="group" aria-labelledby="money-sections-label">
              <span id="money-sections-label">أقسام المزودين</span>
              {sectionsError ? <DeskNote tone="coral">{sectionsError}</DeskNote> : null}
              {sections === null && !sectionsError ? <DeskNote>لحظة، نحمّل الأقسام…</DeskNote> : null}
              {sections?.map((section) => (
                <label key={section.slug} className="desk-check">
                  <input
                    type="checkbox"
                    checked={draft.slugs.includes(section.slug)}
                    onChange={(event) =>
                      setDraft({
                        ...draft,
                        slugs: event.target.checked
                          ? [...draft.slugs, section.slug]
                          : draft.slugs.filter((slug) => slug !== section.slug),
                      })
                    }
                  />
                  {section.nameAr}
                </label>
              ))}
              <DeskNote>«ابحث» في البند يدور على هذي الأقسام، والعرض المقبول منها ينحسب عليه. بدون قسم، التطبيق يربطه من اسمه.</DeskNote>
            </div>
          ) : null}
          {editing === 'new' ? (
            <label className="desk-field">
              المعرّف الثابت (اختياري)
              <input
                value={draft.key}
                onChange={(event) => setDraft({ ...draft, key: event.target.value })}
                dir="ltr"
              />
            </label>
          ) : null}
          <div className="desk-row">
            <label className="desk-check">
              <input
                type="checkbox"
                checked={draft.showForGroom}
                onChange={(event) => setDraft({ ...draft, showForGroom: event.target.checked })}
              />
              العريس
            </label>
            <label className="desk-check">
              <input
                type="checkbox"
                checked={draft.showForBride}
                onChange={(event) => setDraft({ ...draft, showForBride: event.target.checked })}
              />
              العروسة
            </label>
            <label className="desk-check">
              <input
                type="checkbox"
                checked={draft.isRecommended}
                onChange={(event) => setDraft({ ...draft, isRecommended: event.target.checked })}
              />
              مقترح من البداية
            </label>
          </div>
          <DeskNote>التعديل ينحفظ مسودة، وما يوصل التطبيق إلا لما تنشره.</DeskNote>
          {actionError ? <DeskNote tone="coral">{actionError}</DeskNote> : null}
          <div className="desk-dialog__actions">
            <DeskButton type="submit" disabled={busy || !draft.nameAr.trim()}>
              احفظ مسودة
            </DeskButton>
            {catalog && editing && editing !== 'new' && editing.current.isActive ? (
              <ConfirmDialog
                variant="desk"
                title={`إيقاف ${editing.current.nameAr}`}
                effects={['يختفي من الخطط الجديدة على طول بدون مسودة.', 'الخطط القائمة ما تتغير.']}
                confirmLabel="أوقفه"
                confirmTone="coral"
                trigger={<DeskButton tone="white-coral">أوقف</DeskButton>}
                onConfirm={async () => {
                  await disableReferenceCatalogItem(catalog.key, editing.id);
                  setEditing(null);
                  await open(catalog.key);
                }}
              />
            ) : null}
            {/* RA-AD-14: the reverse of «أوقف», the same way: active and
                published at once. */}
            {catalog && editing && editing !== 'new' && !editing.current.isActive ? (
              <ConfirmDialog
                variant="desk"
                title={`تشغيل ${editing.current.nameAr}`}
                effects={[
                  'يرجع للخطط الجديدة على طول.',
                  'أي تعديل محفوظ مسودة ينزل معه.',
                  'الخطط القائمة ما تتغير.',
                ]}
                confirmLabel="شغّله"
                trigger={<DeskButton tone="soft">شغّل</DeskButton>}
                onConfirm={async () => {
                  await updateReferenceCatalogItem(catalog.key, editing.id, { isActive: true });
                  await publishReferenceCatalogItem(catalog.key, editing.id);
                  setEditing(null);
                  await open(catalog.key);
                }}
              />
            ) : null}
          </div>
        </form>
      </DeskModal>
    </section>
  );
}

/** «المنشور» beside «المسودة», the changed lines in sky. */
function Compare({ item, isTasks }: { item: ReferenceCatalogItem; isTasks: boolean }) {
  const before = item.published;
  const after = item.current;
  const lines: Array<[string, string]> = [];
  if (isTasks) {
    lines.push([
      before ? `قبل ${daysWords(daysBefore(before))}` : '—',
      `قبل ${daysWords(daysBefore(after))}`,
    ]);
  } else {
    lines.push([before?.nameAr ?? '—', after.nameAr]);
  }
  lines.push([before?.groupNameAr ?? '—', after.groupNameAr ?? '—']);
  if ((before?.isActive ?? true) !== after.isActive) {
    lines.push([before?.isActive ? 'شغّال' : 'موقوف', after.isActive ? 'شغّال' : 'موقوف']);
  }
  return (
    <table className="desk-compare">
      <caption className="desk-sr">المنشور والمسودة</caption>
      <thead>
        <tr>
          <th scope="col">المنشور</th>
          <th scope="col">المسودة</th>
        </tr>
      </thead>
      <tbody>
        {lines.map(([was, now], index) => (
          <tr key={index}>
            <td>{was}</td>
            <td className={was !== now ? 'is-changed' : undefined}>{now}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
