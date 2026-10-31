// a17 «الباقات والظهور المميز»: the provider pays outside the app and an
// administrator records the days of his featured placement here. The
// differences from the drawing (recorded in docs/project/DECISIONS.md with
// B-43): one paid plan, «مميز», since nothing in the app would make «احترافي» differ;
// the «الدفع» column is the administrator's note on how he paid (no amount,
// no «ينتظر الدفع»: a placement exists only once it is recorded); «خلص ·
// ذكّره» is «خلص» because the hourly job tells the provider at the end; and
// the form, «وقّفه», «ألغه» and «جدّد» are not drawn. The table lists the
// running and booked placements, the finished ones behind «اللي خلصت»; a
// running one on a provider customers cannot find reads «مو ظاهر للعرسان».
import { type FormEvent, useCallback, useEffect, useState } from 'react';
import { Crown } from 'lucide-react';
import {
  endFeaturedPeriod,
  getFeaturedPeriods,
  getFeaturedSummary,
  getProviders,
  grantFeaturedPeriod,
  type FeaturedPeriod,
  type FeaturedSummary,
  type ProviderApplication,
  type ProviderReference,
} from './api';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import { DeskModal } from '../../design_system/DeskModal';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskPager,
  DeskRetry,
  DeskTable,
  Panel,
  SoftAction,
  Stat,
  StatRow,
  Tag,
  TwoLine,
} from '../../design_system/Desk';
import { AdminPermission, Can } from '../auth/api';
import { dayMonth } from '../../platform/i18n/deskTime';
import { providerErrorMessage } from './providerHelpers';

const LIMIT = 50;

/** The table lists what runs or is booked; the ones that are over sit behind their own filter. */
const VIEWS = [
  { state: 'CURRENT', label: 'الشغّالة والمحجوزة', empty: 'ما فيه ظهور مميز شغّال أو محجوز. كل المزودين على الظهور العادي.' },
  { state: 'FINISHED', label: 'اللي خلصت', empty: 'ما فيه ظهور مميز خلص أو انوقف.' },
] as const;

type View = (typeof VIEWS)[number]['state'];

/** Today in Sana'a as `YYYY-MM-DD`: placements are bought by the day there. */
export function yemenToday(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Aden',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

export function addDays(day: string, count: number): string {
  const date = new Date(`${day}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + count);
  return date.toISOString().slice(0, 10);
}

/** «18 أكتوبر» for a `YYYY-MM-DD` day. */
function dayLabel(day: string): string {
  return dayMonth(`${day}T12:00:00.000Z`);
}

/**
 * The placement's state as a17 tags it. A running placement on a provider
 * customers cannot find (no active service, not active, unclaimed) ranks
 * and badges nothing, so it is not «شغّال».
 */
export function featuredStateTag(period: Pick<FeaturedPeriod, 'state' | 'startsOn' | 'providerShown'>) {
  switch (period.state) {
    case 'ACTIVE':
      return period.providerShown ? <Tag tone="green">شغّال</Tag> : <Tag tone="coral">مو ظاهر للعرسان</Tag>;
    case 'SCHEDULED':
      return <Tag tone="sky">يبدأ {dayLabel(period.startsOn)}</Tag>;
    case 'EXPIRED':
      return <Tag tone="coral">خلص</Tag>;
    case 'ENDED':
      return <Tag tone="muted">انوقف</Tag>;
  }
}

function placeLine(provider: ProviderReference): string {
  return [provider.primaryCategory?.nameAr, provider.city?.nameAr].filter(Boolean).join(' · ');
}

type GrantTarget = { provider: ProviderReference; startsOn: string | null };

export function FeaturedPlacementsPage() {
  const [view, setView] = useState<View>('CURRENT');
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<{
    items: FeaturedPeriod[];
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  } | null>(null);
  const [summary, setSummary] = useState<FeaturedSummary | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [granting, setGranting] = useState<GrantTarget | 'pick' | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const [list, counts] = await Promise.all([
        getFeaturedPeriods({ state: view, page, limit: LIMIT }),
        getFeaturedSummary(),
      ]);
      setResult(list);
      setSummary(counts);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الباقات.');
    }
  }, [view, page]);

  const current = VIEWS.find((item) => item.state === view)!;
  function pick(next: View) {
    setView(next);
    setPage(1);
    setResult(null);
  }

  useEffect(() => {
    void load();
  }, [load]);

  const today = yemenToday();

  /** A renewal starts the day after the current one ends, or today. */
  function renew(period: FeaturedPeriod) {
    const next = addDays(period.lastDay, 1);
    setGranting({
      provider: period.provider,
      startsOn: period.state === 'ACTIVE' && next > today ? next : null,
    });
  }

  return (
    <section>
      <DeskHeader
        title="الباقات والظهور المميز"
        sub="المزود يدفع لكم برا التطبيق، وأنتم تفعّلون الباقة من هنا"
        actions={
          <>
            {VIEWS.map((item) => (
              <DeskButton
                key={item.state}
                tone={item.state === view ? 'teal' : 'soft'}
                pressed={item.state === view}
                onClick={() => pick(item.state)}
              >
                {item.label}
              </DeskButton>
            ))}
            <Can permission={AdminPermission.PROVIDERS_WRITE}>
              <DeskButton icon={Crown} onClick={() => setGranting('pick')}>
                فعّل باقة لمزود
              </DeskButton>
            </Can>
          </>
        }
      />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {summary ? (
        <StatRow>
          <Stat value={summary.free} label="مجاني" sub="ظهور عادي" />
          <Stat value={summary.featured} label="مميز" sub="فوق في القسم والمدينة" />
          <Stat value={summary.endingThisWeek} label="تنتهي هذا الأسبوع" tone="saffron" />
        </StatRow>
      ) : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل الباقات…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>{current.empty}</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <>
          <DeskTable
            caption={current.label}
            columns={[
              { label: 'المزود', flex: 4 },
              { label: 'الباقة', flex: 2 },
              { label: 'من', flex: 2 },
              { label: 'لين', flex: 2 },
              { label: 'الدفع', flex: 3 },
              { label: '', flex: 3 },
            ]}
            rows={result.items}
            rowKey={(period) => period.id}
            renderRow={(period) => [
              <TwoLine key="p" main={period.provider.businessName} sub={placeLine(period.provider)} />,
              <Tag key="t" tone="saffron">مميز</Tag>,
              dayLabel(period.startsOn),
              dayLabel(period.lastDay),
              <TwoLine
                key="n"
                main={period.note ?? '—'}
                sub={period.grantedBy ? `سجّلها ${period.grantedBy.name}` : undefined}
              />,
              <span key="s" className="desk-tag-cell">
                {featuredStateTag(period)}
                {period.state === 'ENDED' && period.endNote ? (
                  <span className="desk-field-card__more">{period.endNote}</span>
                ) : null}
                <Can permission={AdminPermission.PROVIDERS_WRITE}>
                  <span className="desk-actions">
                    {period.state === 'ACTIVE' || period.state === 'EXPIRED' ? (
                      <SoftAction onClick={() => renew(period)}>جدّد</SoftAction>
                    ) : null}
                    {period.state === 'ACTIVE' || period.state === 'SCHEDULED' ? (
                      <ConfirmDialog
                        variant="desk"
                        title={
                          period.state === 'ACTIVE'
                            ? `نوقّف ظهور «${period.provider.businessName}» المميز؟`
                            : `نلغي ظهور «${period.provider.businessName}» اللي يبدأ ${dayLabel(period.startsOn)}؟`
                        }
                        effects={[
                          period.state === 'ACTIVE'
                            ? 'من الحين يظهر عادي، بدون «مميز» وبدون ما يطلع أول.'
                            : 'ما يبدأ ظهوره المميز.',
                          'يوصله تنبيه، وفيه ملاحظتك لو كتبت.',
                          'التطبيق ما يرجّع فلوس. لو فيه شي يرجع له، رتّبوه معه برا التطبيق.',
                        ]}
                        needsNote
                        noteRequired={false}
                        noteLabel="ملاحظة توصله (اختياري)"
                        confirmLabel={period.state === 'ACTIVE' ? 'وقّفه' : 'ألغه'}
                        confirmTone="coral"
                        trigger={
                          <SoftAction tone="coral">{period.state === 'ACTIVE' ? 'وقّفه' : 'ألغه'}</SoftAction>
                        }
                        describeError={(value) => providerErrorMessage(value)}
                        onConfirm={async (note) => {
                          await endFeaturedPeriod(period.id, note.trim() || undefined);
                          await load();
                        }}
                      />
                    ) : null}
                  </span>
                </Can>
              </span>,
            ]}
          />
          <DeskPager
            page={result.page}
            limit={result.limit}
            total={result.total}
            totalPages={result.totalPages}
            onPageChange={setPage}
          />
        </>
      ) : null}
      <Panel tone="soft">
        <DeskNote>
          التطبيق ما يستلم فلوس. كل تفعيل ينكتب في سجل العمليات باسم اللي فعّله، والمزود يوصله إشعار
          ببداية ونهاية باقته. والعرسان يشوفون «مميز» بوضوح، عشان ما يحسبونه ترشيحًا من اعّرست.
        </DeskNote>
      </Panel>
      <GrantDialog
        target={granting}
        today={today}
        onClose={() => setGranting(null)}
        onGranted={async () => {
          setGranting(null);
          await load();
        }}
      />
    </section>
  );
}

function GrantDialog({
  target,
  today,
  onClose,
  onGranted,
}: {
  target: GrantTarget | 'pick' | null;
  today: string;
  onClose: () => void;
  onGranted: () => Promise<void>;
}) {
  const [provider, setProvider] = useState<ProviderReference | null>(null);
  const [search, setSearch] = useState('');
  const [found, setFound] = useState<ProviderApplication[] | null>(null);
  const [startsLater, setStartsLater] = useState(false);
  const [startsOn, setStartsOn] = useState(today);
  const [endsOn, setEndsOn] = useState(addDays(today, 30));
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (target === null) return;
    const fixed = target === 'pick' ? null : target;
    const start = fixed?.startsOn ?? today;
    setProvider(fixed?.provider ?? null);
    setSearch('');
    setFound(null);
    setStartsLater(Boolean(fixed?.startsOn));
    setStartsOn(start);
    setEndsOn(addDays(start, 30));
    setNote('');
    setError(null);
  }, [target, today]);

  async function find(event: FormEvent) {
    event.preventDefault();
    setError(null);
    try {
      const page = await getProviders({ status: 'ACTIVE', search: search.trim(), limit: 8 });
      setFound(page.items);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نبحث.');
    }
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!provider) return;
    setError(null);
    setSaving(true);
    try {
      await grantFeaturedPeriod(provider.id, {
        endsOn,
        ...(startsLater && startsOn !== today ? { startsOn } : {}),
        ...(note.trim() ? { note: note.trim() } : {}),
      });
      await onGranted();
    } catch (value) {
      setError(providerErrorMessage(value, 'ما قدرنا نفعّل الباقة.'));
    } finally {
      setSaving(false);
    }
  }

  const from = startsLater ? startsOn : today;
  return (
    <DeskModal title="فعّل باقة «مميز»" open={target !== null} onClose={onClose}>
      {provider ? (
        <form className="desk-form" onSubmit={submit}>
          <TwoLine main={provider.businessName} sub={placeLine(provider)} />
          <div className="desk-row">
            <label className="desk-check">
              <input type="radio" checked={!startsLater} onChange={() => setStartsLater(false)} />
              يبدأ من الحين
            </label>
            <label className="desk-check">
              <input type="radio" checked={startsLater} onChange={() => setStartsLater(true)} />
              يبدأ يوم ثاني
            </label>
          </div>
          <div className="desk-row">
            {startsLater ? (
              <label className="desk-field">
                أول يوم
                <input type="date" min={today} value={startsOn} onChange={(event) => setStartsOn(event.target.value)} required />
              </label>
            ) : null}
            <label className="desk-field">
              آخر يوم
              <input type="date" min={from} value={endsOn} onChange={(event) => setEndsOn(event.target.value)} required />
            </label>
          </div>
          <label className="desk-field">
            كيف دفع برا التطبيق (اختياري)
            <input value={note} maxLength={500} placeholder="كاش · 3 شهور" onChange={(event) => setNote(event.target.value)} />
          </label>
          <ul className="desk-dialog__effects">
            <li>
              من {dayLabel(from)} لين {dayLabel(endsOn)} يطلع مع المميزين أول، وعليه «مميز» عند العرسان.
            </li>
            <li>يوصله تنبيه الحين، وقبل النهاية بأسبوع، ولما تخلص.</li>
            <li>التطبيق ما يستلم فلوس، ولا يسجّل مبلغ.</li>
          </ul>
          {error ? <DeskNote tone="coral">{error}</DeskNote> : null}
          <div className="desk-dialog__actions">
            <DeskButton type="submit" disabled={saving || !endsOn}>
              فعّل
            </DeskButton>
            {target === 'pick' ? (
              <DeskButton tone="soft" onClick={() => setProvider(null)}>
                مزود ثاني
              </DeskButton>
            ) : null}
          </div>
        </form>
      ) : (
        <form className="desk-form" onSubmit={find}>
          <label className="desk-field">
            المزود
            <input
              value={search}
              placeholder="ابحث باسم النشاط أو الرقم"
              onChange={(event) => setSearch(event.target.value)}
              required
            />
          </label>
          <div className="desk-dialog__actions">
            <DeskButton type="submit">ابحث</DeskButton>
          </div>
          {found && found.length === 0 ? <DeskNote>ما لقينا مزود نشط بهذا الاسم أو الرقم.</DeskNote> : null}
          {found && found.length > 0 ? (
            <div className="desk-actions">
              {found.map((item) => (
                <SoftAction key={item.id} onClick={() => setProvider(item)}>
                  {item.businessName}
                  {item.isFeatured ? ' · مميز الحين' : ''}
                </SoftAction>
              ))}
            </div>
          ) : null}
          {error ? <DeskNote tone="coral">{error}</DeskNote> : null}
        </form>
      )}
    </DeskModal>
  );
}
