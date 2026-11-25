// n01 «الصندوق»: one inbox for the queues this admin can act on, each item with its
// promise: provider applications and claims waiting for review, open
// conversation reports and (RA-AD-27) the photos waiting for review, the
// reported assistant answers and reviews, the account deletions that
// failed and the provider profile changes waiting. The owner column, the «لي / بدون مسؤول / الكل» filters and «ضغط
// الفريق» are not built.
import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Clock } from 'lucide-react';
import {
  getProviderApplications,
  getProfileChanges,
  getProviderClaims,
  sentBackAfterRefusal,
  type ProfileChange,
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
import { everyPage } from '../../platform/api/query';

/** The slice of a conversation report the inbox reads. */
export type InboxReport = {
  id: string;
  reason: string;
  createdAt: string;
  reporter: { id: string; name: string };
  conversation: { provider: { id: string; businessName: string } };
  /** RA-AD-22: who it is about, as the server reads it. */
  reported: { kind: 'PROVIDER' } | { kind: 'CUSTOMER'; user: { name: string } | null };
};

/** The slice of a reported assistant answer the inbox reads. */
export type InboxAssistantReport = { id: string; reason: string; createdAt: string };

/** The slice of a portfolio photo waiting for review the inbox reads. */
export type InboxPhoto = {
  id: string;
  createdAt: string;
  provider: { id: string; businessName: string };
};

/** The slice of a reported review the inbox reads (its open reports, newest first). */
export type InboxReview = {
  id: string;
  provider?: { id: string; businessName: string } | null;
  openReportCount?: number;
  openReports?: { reason: string; createdAt: string }[];
};

/** The slice of a pending account deletion the inbox reads. */
export type InboxDeletion = {
  userId: string;
  name: string;
  scheduledFor: string;
  purgeFailedAt: string | null;
};

type InboxPage<T> = { items: T[]; total: number };
type PageParams = { page: number; limit: number };

type DashboardPageProps = {
  // The queues other features own, handed in by the app.
  /** Open conversation reports (moderation). */
  getOpenReports: (params: { status: 'OPEN' } & PageParams) => Promise<InboxPage<InboxReport>>;
  /** Open reports on assistant answers (moderation). */
  getOpenAssistantReports: (
    params: { status: 'OPEN' } & PageParams,
  ) => Promise<InboxPage<InboxAssistantReport>>;
  /** Portfolio photos waiting for review (moderation). */
  getPendingPhotos: (params: { status: 'PENDING' } & PageParams) => Promise<InboxPage<InboxPhoto>>;
  /** Reviews with an open report (moderation). */
  getReportedReviews: (params: { reported: 'true' } & PageParams) => Promise<InboxPage<InboxReview>>;
  /** The pending account deletions (users). */
  getDeletions: () => Promise<{ deletions: InboxDeletion[] }>;
};

type Kind = 'join' | 'claim' | 'change' | 'report' | 'answer' | 'review' | 'photo' | 'failure';

type InboxItem = {
  key: string;
  kind: Kind;
  title: string;
  sub: string;
  start: string;
  to: string;
};

/** The promise per kind, as «الوعد لكل نوع» writes it. */
const PROMISES: Record<
  Kind,
  { label: string; words: string; ms: number; tag: string; tone: 'sky' | 'coral' | 'saffron' }
> = {
  report: { label: 'بلاغ', words: '4 ساعات', ms: 4 * PROMISE.HOUR, tag: 'بلاغ', tone: 'coral' },
  // RA-AD-27: a reported answer or review is a report in the same desk
  // (D94, D95), so it takes the report's promise.
  answer: { label: 'بلاغ إجابة', words: '4 ساعات', ms: 4 * PROMISE.HOUR, tag: 'بلاغ', tone: 'coral' },
  review: { label: 'بلاغ تقييم', words: '4 ساعات', ms: 4 * PROMISE.HOUR, tag: 'تقييم', tone: 'coral' },
  join: { label: 'انضمام', words: 'يومين', ms: 2 * PROMISE.DAY, tag: 'انضمام', tone: 'sky' },
  // Not drawn in n01: a claim (B-12) is a joining by another door, so it
  // takes the joining's promise.
  claim: { label: 'استلام ملف', words: 'يومين', ms: 2 * PROMISE.DAY, tag: 'استلام', tone: 'sky' },
  // RA-AD-27: not drawn in n01; a provider's change of his listing is
  // reviewed as his joining was, so it takes the joining's promise.
  change: { label: 'تعديل ملف', words: 'يومين', ms: 2 * PROMISE.DAY, tag: 'تعديل ملف', tone: 'sky' },
  // n07 draws two hours for a photo.
  photo: { label: 'صورة معرض', words: 'ساعتين', ms: 2 * PROMISE.HOUR, tag: 'صورة', tone: 'saffron' },
  // A deletion fails on the day it was due (D63), so it is late from then.
  failure: { label: 'حذف ما كمل', words: 'فورًا', ms: 0, tag: 'فشل', tone: 'coral' },
};


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

/** A provider's change of his name, logo, cover, city or category (RA-BE-152). */
function changeItem(change: ProfileChange): InboxItem {
  return {
    key: `change-${change.id}`,
    kind: 'change',
    title: change.provider.businessName,
    sub: `يطلب تعديل ملفه · ${agoWords(change.createdAt)}`,
    start: change.createdAt,
    to: '/profile-changes',
  };
}

function reportItem(report: InboxReport): InboxItem {
  const provider = report.conversation.provider.businessName;
  // The provider's owner filed it: the reported party is the customer.
  const sub =
    report.reported.kind === 'CUSTOMER'
      ? `«${provider}» بلّغ عن ${report.reported.user?.name ?? 'حساب محذوف'}`
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

function answerItem(report: InboxAssistantReport): InboxItem {
  return {
    key: `answer-${report.id}`,
    kind: 'answer',
    title: report.reason,
    sub: 'بلاغ على إجابة المساعد',
    start: report.createdAt,
    to: '/conversation-reports',
  };
}

function photoItem(photo: InboxPhoto): InboxItem {
  return {
    key: `photo-${photo.id}`,
    kind: 'photo',
    title: `صورة جديدة في معرض «${photo.provider.businessName}»`,
    sub: agoWords(photo.createdAt),
    start: photo.createdAt,
    to: '/photos',
  };
}

/** A reported review waits from the oldest of its open reports the server sent. */
function reviewItem(review: InboxReview): InboxItem[] {
  const reports = review.openReports ?? [];
  const oldest = reports[reports.length - 1];
  if (!oldest) return [];
  return [
    {
      key: `review-${review.id}`,
      kind: 'review',
      title: `تقييم على «${review.provider?.businessName ?? 'مزود'}»`,
      sub: `${review.openReportCount ?? reports.length} بلاغ · ${reports[0].reason}`,
      start: oldest.createdAt,
      to: '/reviews',
    },
  ];
}

function failureItem(deletion: InboxDeletion): InboxItem {
  return {
    key: `failure-${deletion.userId}`,
    kind: 'failure',
    title: deletion.name,
    sub: 'الحذف ما كمل في موعده',
    start: deletion.scheduledFor,
    to: '/data-requests',
  };
}

function none<T>(): Promise<InboxPage<T>> {
  return Promise.resolve({ items: [], total: 0 });
}

export function DashboardPage({
  getOpenReports,
  getOpenAssistantReports,
  getPendingPhotos,
  getReportedReviews,
  getDeletions,
}: DashboardPageProps) {
  const { user } = useAuth();
  const navigate = useNavigate();
  const actsOnJoins = hasAdminPermission(user, AdminPermission.PROVIDERS_WRITE);
  const actsOnReports = hasAdminPermission(user, AdminPermission.CONVERSATION_REPORTS_WRITE);
  // RA-AD-27: photos and reviews are decided with REVIEWS_WRITE; a failed
  // deletion is the accounts team's (USERS_WRITE, as n06).
  const actsOnReviews = hasAdminPermission(user, AdminPermission.REVIEWS_WRITE);
  const actsOnAccounts = hasAdminPermission(user, AdminPermission.USERS_WRITE);
  const [items, setItems] = useState<InboxItem[] | null>(null);
  // The server's count of open items, which past a thousand per queue
  // (everyPage's cap) exceeds the rows read.
  const [open, setOpen] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [now, setNow] = useState(() => new Date());

  const load = useCallback(async () => {
    setError(null);
    try {
      const [joins, claims, changes, reports, answers, photos, reviews, failures] = await Promise.all([
        // RA-AD-07: every page, so the most overdue are never left out.
        actsOnJoins
          ? everyPage((page, limit) => getProviderApplications({ status: 'PENDING', page, limit }))
          : none<ProviderApplication>(),
        actsOnJoins
          ? everyPage((page, limit) => getProviderClaims({ status: 'PENDING', page, limit }))
          : none<ProviderClaimRequest>(),
        // RA-AD-27: decided with PROVIDERS_WRITE, as a joining.
        actsOnJoins
          ? everyPage((page, limit) => getProfileChanges({ status: 'PENDING', page, limit }))
          : none<ProfileChange>(),
        actsOnReports
          ? everyPage((page, limit) => getOpenReports({ status: 'OPEN', page, limit }))
          : none<InboxReport>(),
        actsOnReports
          ? everyPage((page, limit) => getOpenAssistantReports({ status: 'OPEN', page, limit }))
          : none<InboxAssistantReport>(),
        actsOnReviews
          ? everyPage((page, limit) => getPendingPhotos({ status: 'PENDING', page, limit }))
          : none<InboxPhoto>(),
        actsOnReviews
          ? everyPage((page, limit) => getReportedReviews({ reported: 'true', page, limit }))
          : none<InboxReview>(),
        actsOnAccounts
          ? getDeletions().then(({ deletions }) => {
              const failed = deletions.filter((deletion) => deletion.purgeFailedAt !== null);
              return { items: failed, total: failed.length };
            })
          : none<InboxDeletion>(),
      ]);
      const next = [
        ...joins.items.map(joinItem),
        ...claims.items.map(claimItem),
        ...changes.items.map(changeItem),
        ...reports.items.map(reportItem),
        ...answers.items.map(answerItem),
        ...photos.items.map(photoItem),
        ...reviews.items.flatMap(reviewItem),
        ...failures.items.map(failureItem),
      ];
      const current = new Date();
      next.sort(
        (a, b) =>
          deadline(a.start, PROMISES[a.kind].ms, current).remainingMs -
          deadline(b.start, PROMISES[b.kind].ms, current).remainingMs,
      );
      setNow(current);
      setOpen(
        [joins, claims, changes, reports, answers, photos, reviews, failures].reduce(
          (sum, queue) => sum + queue.total,
          0,
        ),
      );
      setItems(next);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الصندوق.');
    }
  }, [
    actsOnJoins,
    actsOnReports,
    actsOnReviews,
    actsOnAccounts,
    getOpenReports,
    getOpenAssistantReports,
    getPendingPhotos,
    getReportedReviews,
    getDeletions,
  ]);

  useEffect(() => {
    void load();
  }, [load]);

  const actsOn: Record<Kind, boolean> = {
    report: actsOnReports,
    answer: actsOnReports,
    review: actsOnReviews,
    join: actsOnJoins,
    claim: actsOnJoins,
    change: actsOnJoins,
    photo: actsOnReviews,
    failure: actsOnAccounts,
  };
  const kinds = (Object.keys(PROMISES) as Kind[]).filter((kind) => actsOn[kind]);
  const late = items?.filter((item) => deadline(item.start, PROMISES[item.kind].ms, now).overdue).length ?? 0;
  const sub = items
    ? // Past the cap the late count is of the rows read: at least that.
      `كل شغل اللوحة في مكان واحد · ${open} مفتوح · ${late}${open > items.length ? '+' : ''} تعدّت الوقت`
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
