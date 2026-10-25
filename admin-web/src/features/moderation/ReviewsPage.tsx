// a10 «التقييمات» (mobile/test/prototype/admin/admin_screens.dart
// `a10Reviews`). «مبلّغ عنها», the report column and «خلّه» wait for B-28
// and «شوف الحجز» for B-40. The provider's reply (B-09) reads under the
// review as drawn («رد المزود: «…»»); the team hides it like a review with
// «أخفِ الرد» and brings it back with «أظهر الرد» (undrawn: needed to moderate
// it). Hiding takes no reason and tells no one yet (A-08), so the page does
// not say it does.
import { useCallback, useEffect, useState } from 'react';
import {
  getReviews,
  hideReview,
  updateReviewReplyStatus,
  updateReviewStatus,
  type ProviderReview,
} from './api';
import { AdminPermission, Can } from '../auth/api';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskPager,
  DeskRetry,
  DeskTable,
  Panel,
  SoftAction,
  TwoLine,
  stars,
} from '../../design_system/Desk';
import { dayMonth } from '../../platform/i18n/deskTime';

type Tab = 'ALL' | 'HIDDEN';

type Page = {
  items: ProviderReview[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export function ReviewsPage() {
  const [tab, setTab] = useState<Tab>('ALL');
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setResult(
        await getReviews({ status: tab === 'HIDDEN' ? 'HIDDEN' : undefined, page, limit: 20 }),
      );
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل التقييمات.');
    }
  }, [tab, page]);

  useEffect(() => {
    void load();
  }, [load]);

  function pick(next: Tab) {
    setTab(next);
    setPage(1);
    setResult(null);
    setActionError(null);
  }

  async function publish(review: ProviderReview) {
    setBusyId(review.id);
    setActionError(null);
    try {
      await updateReviewStatus(review.id, 'PUBLISHED');
      await load();
    } catch (value) {
      setActionError(value instanceof Error ? value.message : 'ما قدرنا نغيّر التقييم.');
    } finally {
      setBusyId(null);
    }
  }

  async function hide(review: ProviderReview) {
    setActionError(null);
    await hideReview(review.id);
    await load();
  }

  async function setReply(review: ProviderReview, status: 'PUBLISHED' | 'HIDDEN') {
    setBusyId(review.id);
    setActionError(null);
    try {
      await updateReviewReplyStatus(review.id, status);
      await load();
    } catch (value) {
      setActionError(value instanceof Error ? value.message : 'ما قدرنا نغيّر الرد.');
    } finally {
      setBusyId(null);
    }
  }

  return (
    <section>
      <DeskHeader
        title="التقييمات"
        sub="تنشر على طول · المخالف ينخفي"
        actions={(
          [
            ['ALL', 'الكل'],
            ['HIDDEN', 'مخفية'],
          ] as const
        ).map(([value, label]) => (
          <DeskButton
            key={value}
            tone={tab === value ? 'teal' : 'soft'}
            pressed={tab === value}
            onClick={() => pick(value)}
          >
            {label}
          </DeskButton>
        ))}
      />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {actionError ? <DeskRetry message={actionError} onRetry={() => void load()} /> : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل التقييمات…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>{tab === 'HIDDEN' ? 'ما فيه تقييم مخفي.' : 'ما فيه تقييمات بعد.'}</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <>
          <DeskTable
            caption="التقييمات"
            columns={[
              { label: 'التقييم', flex: 6 },
              { label: 'المزود', flex: 2 },
              { label: '', flex: 3 },
            ]}
            rows={result.items}
            rowKey={(review) => review.id}
            renderRow={(review) => [
              <TwoLine
                key="r"
                main={
                  <>
                    <span className="desk-stars" aria-label={`${review.rating} من 5`}>
                      {stars(review.rating)}
                    </span>{' '}
                    {review.comment ? `«${review.comment}»` : 'بدون تعليق'}
                  </>
                }
                sub={[
                  review.user.name,
                  dayMonth(review.createdAt),
                  ...(review.reply
                    ? [
                        `${review.reply.status === 'HIDDEN' ? 'رد المزود (مخفي)' : 'رد المزود'}: «${review.reply.body}»`,
                      ]
                    : []),
                ].join(' · ')}
              />,
              review.provider?.businessName ?? '—',
              <Can key="a" permission={AdminPermission.REVIEWS_WRITE}>
                <span className="desk-actions">
                  {review.status === 'HIDDEN' || review.status === 'PENDING' ? (
                    <SoftAction disabled={busyId === review.id} onClick={() => void publish(review)}>
                      {review.status === 'HIDDEN' ? 'أظهره' : 'انشره'}
                    </SoftAction>
                  ) : null}
                  {review.status !== 'HIDDEN' ? (
                    <ConfirmDialog
                      variant="desk"
                      title={`إخفاء تقييم ${review.user.name}`}
                      effects={[
                        `ما يظهر في ملف ${review.provider?.businessName ?? 'المزود'} ولا يدخل في تقييمه.`,
                        'تقدر ترجّعه من «مخفية».',
                      ]}
                      confirmLabel="أخفِ"
                      confirmTone="coral"
                      trigger={<SoftAction tone="coral">أخفِ</SoftAction>}
                      onConfirm={() => hide(review)}
                    />
                  ) : null}
                  {review.reply?.status === 'HIDDEN' ? (
                    <SoftAction
                      disabled={busyId === review.id}
                      onClick={() => void setReply(review, 'PUBLISHED')}
                    >
                      أظهر الرد
                    </SoftAction>
                  ) : null}
                  {review.reply?.status === 'PUBLISHED' ? (
                    <ConfirmDialog
                      variant="desk"
                      title={`إخفاء رد ${review.provider?.businessName ?? 'المزود'}`}
                      effects={[
                        'الرد ما يظهر للعرسان تحت التقييم، والتقييم يبقى كما هو.',
                        'المزود يشوف إن رده مخفي، وما يقدر يكتب رد ثاني.',
                        'تقدر ترجّعه من «أظهر الرد».',
                      ]}
                      confirmLabel="أخفِ الرد"
                      confirmTone="coral"
                      trigger={<SoftAction tone="coral">أخفِ الرد</SoftAction>}
                      onConfirm={() => setReply(review, 'HIDDEN')}
                    />
                  ) : null}
                </span>
              </Can>,
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
      <DeskNote>التقييم بعد حجز «تم» ما ينحذف بسبب إن المزود ما عجبه.</DeskNote>
    </section>
  );
}
