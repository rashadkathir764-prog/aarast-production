// a03 «طلبات الانضمام». The method column and the automatic checks in
// «ملاحظة» have no field (D41, B-16, B-13, B-31), so the note column carries
// the review's own state: a profile sent back after changes (B-01, B-02) or
// the team's note. The server lists the newest first, so the page reads up
// to 100 and puts the oldest first (A-06).
import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  getProviderApplications,
  sentBackAfterRefusal,
  type ProviderApplication,
} from './api';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskPager,
  DeskRetry,
  DeskTable,
  Panel,
  Tag,
  TwoLine,
  phoneSpaced,
} from '../../design_system/Desk';
import { PROMISE, spanWords } from '../../platform/i18n/deskTime';

type Queue = 'NEW' | 'RESUBMITTED' | 'NEEDS_CHANGES' | 'REJECTED';

/** The counts the tabs read from the dashboard stats (handed in by the app). */
type ApplicationCounts = {
  pendingProviders: number;
  resubmittedProviders: number;
  needsChangesProviders: number;
};

type ProviderApplicationsPageProps = {
  getStats: () => Promise<ApplicationCounts>;
};

const LIMIT = 100;
const PROMISE_MS = 2 * PROMISE.DAY;

const QUERIES: Record<Queue, { status: string; resubmitted?: boolean }> = {
  NEW: { status: 'PENDING', resubmitted: false },
  RESUBMITTED: { status: 'PENDING', resubmitted: true },
  NEEDS_CHANGES: { status: 'NEEDS_CHANGES' },
  REJECTED: { status: 'REJECTED' },
};

function owner(provider: ProviderApplication) {
  const name = provider.ownerName ?? provider.user?.name;
  return (
    <>
      {name ? `${name} · ` : ''}
      <span className="desk-num">{phoneSpaced(provider.phone)}</span>
    </>
  );
}

/**
 * «أُعيد إرساله · كان يحتاج تعديل» (B-01), or «كان مرفوض» when the decision
 * before this send was a refusal (B-02).
 */
export function resubmittedLine(
  provider: Pick<ProviderApplication, 'resubmitCount' | 'latestDecision'>,
): string {
  const sent = provider.resubmitCount > 1
    ? `أُعيد إرساله ${provider.resubmitCount} مرات`
    : 'أُعيد إرساله';
  return `${sent} · ${sentBackAfterRefusal(provider) ? 'كان مرفوض' : 'كان يحتاج تعديل'}`;
}

/** The team's note a row shows: the whole-profile note, or the first field note. */
function teamNote(provider: ProviderApplication): string | null {
  return provider.reviewNote ?? provider.fieldNotes?.[0]?.note ?? null;
}

export function ProviderApplicationsPage({ getStats }: ProviderApplicationsPageProps) {
  const navigate = useNavigate();
  const [queue, setQueue] = useState<Queue>('NEW');
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<{
    items: ProviderApplication[];
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  } | null>(null);
  const [stats, setStats] = useState<ApplicationCounts | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const next = await getProviderApplications({ ...QUERIES[queue], page, limit: LIMIT });
      const since = (provider: ProviderApplication) =>
        new Date(provider.resubmittedAt ?? provider.createdAt).getTime();
      setResult({
        ...next,
        items: [...next.items].sort((a, b) => since(a) - since(b)),
      });
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الطلبات.');
    }
  }, [queue, page]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    getStats().then(setStats, () => setStats(null));
  }, [getStats]);

  function pick(next: Queue) {
    setQueue(next);
    setPage(1);
    setResult(null);
  }

  const tabs: Array<{ queue: Queue; label: string; tone: 'teal' | 'soft' | 'sky' }> = [
    {
      queue: 'NEW',
      label: stats ? `جديد ${stats.pendingProviders - stats.resubmittedProviders}` : 'جديد',
      tone: 'soft',
    },
    {
      queue: 'RESUBMITTED',
      label: stats ? `أُعيد إرسالها ${stats.resubmittedProviders}` : 'أُعيد إرسالها',
      tone: 'sky',
    },
    {
      queue: 'NEEDS_CHANGES',
      label: stats ? `يحتاج تعديل ${stats.needsChangesProviders}` : 'يحتاج تعديل',
      tone: 'soft',
    },
    { queue: 'REJECTED', label: 'مرفوض', tone: 'soft' },
  ];
  const now = Date.now();

  return (
    <section>
      <DeskHeader
        title="طلبات الانضمام"
        sub="الأقدم أول · نوعد المزود برد خلال يومين"
        actions={tabs.map((tab) => (
          <DeskButton
            key={tab.queue}
            tone={tab.queue === queue ? 'teal' : tab.tone}
            pressed={tab.queue === queue}
            onClick={() => pick(tab.queue)}
          >
            {tab.label}
          </DeskButton>
        ))}
      />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل الطلبات…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه طلبات هنا.</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <>
          <DeskTable
            caption="طلبات الانضمام"
            columns={[
              { label: 'المزود', flex: 4 },
              { label: 'القسم', flex: 3 },
              { label: 'المدينة', flex: 2 },
              { label: 'ينتظر', flex: 2 },
              { label: 'ملاحظة', flex: 4 },
            ]}
            rows={result.items}
            rowKey={(provider) => provider.id}
            onRowClick={(provider) => navigate(`/providers/applications/${provider.id}`)}
            rowLabel={(provider) => `افتح طلب ${provider.businessName}`}
            renderRow={(provider) => {
              const waiting = provider.status === 'PENDING';
              const since = waiting
                ? provider.resubmittedAt ?? provider.createdAt
                : provider.reviewedAt ?? provider.createdAt;
              const waited = now - new Date(since).getTime();
              const late = waiting && waited >= PROMISE_MS;
              const note = teamNote(provider);
              return [
                <TwoLine key="p" main={provider.businessName} sub={owner(provider)} />,
                provider.primaryCategory?.nameAr ?? '—',
                provider.city?.nameAr ?? '—',
                <span key="w" className={late ? 'desk-bold desk-ink--coral' : undefined}>
                  {spanWords(waited)}
                </span>,
                waiting && provider.resubmittedAt ? (
                  <span key="n" className="desk-tag-cell">
                    <Tag tone="sky">{resubmittedLine(provider)}</Tag>
                  </span>
                ) : !waiting && note ? (
                  <span key="n" className="desk-tag-cell">
                    <Tag tone={provider.status === 'REJECTED' ? 'muted' : 'saffron'}>
                      <span className="desk-tag--wrap">{note}</span>
                    </Tag>
                  </span>
                ) : null,
              ];
            }}
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
    </section>
  );
}
