// a03 «طلبات الانضمام» (mobile/test/prototype/admin/admin_screens.dart
// `a03Applications`). «أُعيد إرسالها» waits for B-01; the method column and
// the automatic checks in «ملاحظة» have no field (D41, B-16, B-13, B-31), so
// the note column carries the admin's own note. The server lists the newest
// first, so the page reads up to 100 and puts the oldest first (A-06).
import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getProviderApplications, type ProviderApplication } from './api';
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

type Status = 'PENDING' | 'NEEDS_CHANGES' | 'REJECTED';

/** The counts the tabs read from the dashboard stats (handed in by the app). */
type ApplicationCounts = { pendingProviders: number; needsChangesProviders: number };

type ProviderApplicationsPageProps = {
  getStats: () => Promise<ApplicationCounts>;
};

const LIMIT = 100;
const PROMISE_MS = 2 * PROMISE.DAY;

function owner(provider: ProviderApplication) {
  const name = provider.ownerName ?? provider.user?.name;
  return (
    <>
      {name ? `${name} · ` : ''}
      <span className="desk-num">{phoneSpaced(provider.phone)}</span>
    </>
  );
}

export function ProviderApplicationsPage({ getStats }: ProviderApplicationsPageProps) {
  const navigate = useNavigate();
  const [status, setStatus] = useState<Status>('PENDING');
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
      const next = await getProviderApplications({ status, page, limit: LIMIT });
      setResult({
        ...next,
        items: [...next.items].sort(
          (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
        ),
      });
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الطلبات.');
    }
  }, [status, page]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    getStats().then(setStats, () => setStats(null));
  }, [getStats]);

  function pick(next: Status) {
    setStatus(next);
    setPage(1);
    setResult(null);
  }

  const tabs: Array<{ status: Status; label: string }> = [
    { status: 'PENDING', label: stats ? `جديد ${stats.pendingProviders}` : 'جديد' },
    {
      status: 'NEEDS_CHANGES',
      label: stats ? `يحتاج تعديل ${stats.needsChangesProviders}` : 'يحتاج تعديل',
    },
    { status: 'REJECTED', label: 'مرفوض' },
  ];
  const now = Date.now();

  return (
    <section>
      <DeskHeader
        title="طلبات الانضمام"
        sub="الأقدم أول · نوعد المزود برد خلال يومين"
        actions={tabs.map((tab) => (
          <DeskButton
            key={tab.status}
            tone={tab.status === status ? 'teal' : 'soft'}
            pressed={tab.status === status}
            onClick={() => pick(tab.status)}
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
              const since = provider.status === 'PENDING'
                ? provider.createdAt
                : provider.reviewedAt ?? provider.createdAt;
              const waited = now - new Date(since).getTime();
              const late = provider.status === 'PENDING' && waited >= PROMISE_MS;
              return [
                <TwoLine key="p" main={provider.businessName} sub={owner(provider)} />,
                provider.primaryCategory?.nameAr ?? '—',
                provider.city?.nameAr ?? '—',
                <span key="w" className={late ? 'desk-bold desk-ink--coral' : undefined}>
                  {spanWords(waited)}
                </span>,
                provider.reviewNote ? (
                  <span key="n" className="desk-tag-cell">
                    <Tag tone={provider.status === 'REJECTED' ? 'muted' : 'saffron'}>
                      <span className="desk-tag--wrap">{provider.reviewNote}</span>
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
