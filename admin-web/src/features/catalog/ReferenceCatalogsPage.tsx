// a09 «الكتالوجات»: the starter catalogs that change in the app without a
// release, each item with its days before the wedding and its audience, and
// the published version beside the draft. «ارجع للمنشور» waits for A-19 (no
// call drops a draft). Adding and editing are not drawn and stay, in a
// window, so the days before the wedding can still change from the panel.
import { type FormEvent, type ReactNode, useCallback, useEffect, useState } from 'react';
import {
  createReferenceCatalogItem,
  disableReferenceCatalogItem,
  getReferenceCatalog,
  getReferenceCatalogs,
  publishReferenceCatalogItem,
  type ReferenceCatalog,
  type ReferenceCatalogItem,
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

function daysBefore(revision: ReferenceCatalogRevision | null): number | null {
  const value = revision?.metadata?.daysBefore;
  const days = typeof value === 'number' ? value : Number(value);
  return value === undefined || value === null || !Number.isFinite(days) ? null : days;
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
    const metadata = isTasks
      ? {
          ...(base?.metadata ?? {}),
          daysBefore: draft.days.trim() === '' ? null : Number(draft.days),
        }
      : undefined;
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
      ...(metadata ? { metadata: metadata as Record<string, string | number | boolean | null> } : {}),
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
