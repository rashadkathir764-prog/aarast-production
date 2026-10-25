// n01 «الصندوق» (mobile/test/prototype/admin/admin_center.dart `n01Inbox`):
// one inbox for the queues this admin can act on, each item with its
// promise. Only the queues the server has are here: provider applications
// waiting for review and open conversation reports. The owner column, the
// «لي / بدون مسؤول / الكل» filters and «ضغط الفريق» wait for A-01
// (docs/superpowers/audit/admin_build_classification.md).
import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Clock } from 'lucide-react';
import {
  getProvider,
  getProviderApplications,
  getProviderClaims,
  sentBackAfterRefusal,
  type ProviderApplication,
  type ProviderClaimRequest,
} from '../providers/api';
import { AdminPermission, hasAdminPermission, useAuth } from '../auth/api';
import {
  DeskHeader,
  DeskNote,
  DeskRetry,
  DeskTable,
  Panel,
  Tag,
  TwoLine,
} from '../../design_system/Desk';
import { agoWords, deadline, PROMISE } from '../../platform/i18n/deskTime';

/** The slice of a conversation report the inbox reads. */
export type InboxReport = {
  id: string;
  reason: string;
  createdAt: string;
  reporter: { id: string; name: string };
  conversation: { provider: { id: string; businessName: string } };
};

type InboxPage<T> = { items: T[]; total: number };

type DashboardPageProps = {
  /** Open conversation reports, handed in by the app (moderation owns them). */
  getOpenReports: (params: {
    status: 'OPEN';
    page: number;
    limit: number;
  }) => Promise<InboxPage<InboxReport>>;
};

type Kind = 'join' | 'claim' | 'report';

type InboxItem = {
  key: string;
  kind: Kind;
  title: string;
  sub: string;
  start: string;
  to: string;
};

/** The promise per kind, as «الوعد لكل نوع» writes it. */
const PROMISES: Record<Kind, { label: string; words: string; ms: number; tag: string; tone: 'sky' | 'coral' }> = {
  report: { label: 'بلاغ', words: '4 ساعات', ms: 4 * PROMISE.HOUR, tag: 'بلاغ', tone: 'coral' },
  join: { label: 'انضمام', words: 'يومين', ms: 2 * PROMISE.DAY, tag: 'انضمام', tone: 'sky' },
  // Not drawn in n01: a claim (B-12) is a joining by another door, so it
  // takes the joining's promise.
  claim: { label: 'استلام ملف', words: 'يومين', ms: 2 * PROMISE.DAY, tag: 'استلام', tone: 'sky' },
};

const LIMIT = 100;

function joinItem(provider: ProviderApplication): InboxItem {
  const where = [provider.primaryCategory?.nameAr, provider.city?.nameAr]
    .filter(Boolean)
    .join(' · ');
  // A profile sent back after changes (B-01) or after a reopened refusal
  // (B-02) waits from the time it came back, as n01 draws it.
  if (provider.resubmittedAt) {
    return {
      key: `join-${provider.id}`,
      kind: 'join',
      title: provider.businessName,
      sub: sentBackAfterRefusal(provider) ? 'قدّم من جديد بعد الرفض' : 'أُعيد إرساله بعد التعديل',
      start: provider.resubmittedAt,
      to: `/providers/applications/${provider.id}`,
    };
  }
  return {
    key: `join-${provider.id}`,
    kind: 'join',
    title: provider.businessName,
    sub: where ? `${where} · ${agoWords(provider.createdAt)}` : agoWords(provider.createdAt),
    start: provider.createdAt,
    to: `/providers/applications/${provider.id}`,
  };
}

/** A claim of a listing waiting for review (B-12). */
function claimItem(claim: ProviderClaimRequest): InboxItem {
  return {
    key: `claim-${claim.id}`,
    kind: 'claim',
    title: claim.provider.businessName,
    sub: `${claim.claimant?.name ?? 'حساب'} يطلب استلام الملف · ${agoWords(claim.createdAt)}`,
    start: claim.createdAt,
    to: '/providers/listed',
  };
}

function reportItem(report: InboxReport, ownerId: string | null | undefined): InboxItem {
  const provider = report.conversation.provider.businessName;
  // The provider's owner filed it: the reported party is the customer.
  const sub =
    ownerId && ownerId === report.reporter.id
      ? `«${provider}» بلّغ عن عميل`
      : `${report.reporter.name} بلّغ عن «${provider}»`;
  return {
    key: `report-${report.id}`,
    kind: 'report',
    title: report.reason,
    sub,
    start: report.createdAt,
    to: '/conversation-reports',
  };
}

export function DashboardPage({ getOpenReports }: DashboardPageProps) {
  const { user } = useAuth();
  const navigate = useNavigate();
  const actsOnJoins = hasAdminPermission(user, AdminPermission.PROVIDERS_WRITE);
  const actsOnReports = hasAdminPermission(user, AdminPermission.CONVERSATION_REPORTS_WRITE);
  const [items, setItems] = useState<InboxItem[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState(() => new Date());

  const load = useCallback(async () => {
    setError(null);
    try {
      const [joins, claims, reports] = await Promise.all([
        actsOnJoins
          ? getProviderApplications({ status: 'PENDING', page: 1, limit: LIMIT })
          : Promise.resolve({ items: [] as ProviderApplication[], total: 0 }),
        actsOnJoins
          ? getProviderClaims({ status: 'PENDING', page: 1, limit: LIMIT })
          : Promise.resolve({ items: [] as ProviderClaimRequest[], total: 0 }),
        actsOnReports
          ? getOpenReports({ status: 'OPEN', page: 1, limit: LIMIT })
          : Promise.resolve({ items: [] as InboxReport[], total: 0 }),
      ]);
      const providerIds = [...new Set(reports.items.map((report) => report.conversation.provider.id))];
      const owners = await Promise.allSettled(providerIds.map((id) => getProvider(id)));
      const ownerOf = new Map(
        providerIds.map((id, index) => {
          const result = owners[index];
          return [id, result.status === 'fulfilled' ? result.value.userId : undefined];
        }),
      );
      const next = [
        ...joins.items.map(joinItem),
        ...claims.items.map(claimItem),
        ...reports.items.map((report) =>
          reportItem(report, ownerOf.get(report.conversation.provider.id)),
        ),
      ];
      const current = new Date();
      next.sort(
        (a, b) =>
          deadline(a.start, PROMISES[a.kind].ms, current).remainingMs -
          deadline(b.start, PROMISES[b.kind].ms, current).remainingMs,
      );
      setNow(current);
      setItems(next);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الصندوق.');
    }
  }, [actsOnJoins, actsOnReports, getOpenReports]);

  useEffect(() => {
    void load();
  }, [load]);

  const kinds = (Object.keys(PROMISES) as Kind[]).filter((kind) =>
    kind === 'report' ? actsOnReports : actsOnJoins,
  );
  const late = items?.filter((item) => deadline(item.start, PROMISES[item.kind].ms, now).overdue).length ?? 0;
  const sub = items
    ? `كل شغل اللوحة في مكان واحد · ${items.length} مفتوح · ${late} تعدّت الوقت`
    : 'كل شغل اللوحة في مكان واحد';

  return (
    <section className="desk-fill-page">
      <DeskHeader title="الصندوق" sub={sub} />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      <div className="desk-split">
        <div className="desk-split__main" style={{ flex: 4 }}>
          {items === null && !error ? <DeskNote>لحظة، نجمع البنود…</DeskNote> : null}
          {items && items.length === 0 ? (
            <Panel>
              <DeskNote>ما فيه شي ينتظر الآن.</DeskNote>
            </Panel>
          ) : null}
          {items && items.length > 0 ? (
            <DeskTable
              caption="بنود الصندوق"
              columns={[
                { label: 'البند', flex: 5 },
                { label: 'النوع', flex: 2 },
                { label: 'الوقت', flex: 2 },
              ]}
              rows={items}
              rowKey={(item) => item.key}
              highlight={(item) => deadline(item.start, PROMISES[item.kind].ms, now).overdue}
              onRowClick={(item) => navigate(item.to)}
              rowLabel={(item) => `افتح ${item.title}`}
              renderRow={(item) => {
                const promise = PROMISES[item.kind];
                const time = deadline(item.start, promise.ms, now);
                return [
                  <TwoLine key="t" main={item.title} sub={item.sub} />,
                  <Tag key="k" tone={promise.tone}>
                    {promise.tag}
                  </Tag>,
                  <span key="s" className={`desk-sla${time.late ? ' is-late' : ''}`}>
                    <Clock size={14} aria-hidden="true" />
                    {time.label}
                  </span>,
                ];
              }}
            />
          ) : null}
        </div>
        {kinds.length > 0 ? (
          <div className="desk-split__side" style={{ flex: 2 }}>
            <Panel>
              <h2 className="desk-panel__title">الوعد لكل نوع</h2>
              <dl className="desk-pairs">
                {kinds.map((kind) => (
                  <div key={kind}>
                    <dt>{PROMISES[kind].label}</dt>
                    <dd>{PROMISES[kind].words}</dd>
                  </div>
                ))}
              </dl>
            </Panel>
          </div>
        ) : null}
      </div>
    </section>
  );
}
