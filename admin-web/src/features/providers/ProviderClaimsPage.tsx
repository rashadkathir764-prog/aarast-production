// a07 «ملفات بلا حساب» (mobile/test/prototype/admin/admin_screens.dart
// `a07Listed`), the part B-12 brings: the claims of a listing the back
// office made, each waiting for an administrator who approves (the listing
// becomes the account's) or refuses with a reason the claimant reads. The
// list of every unclaimed listing and its claim date wait for A-07; the
// «رابط الاستلام» column and «طلبات تنتظره» left with D41 (no WhatsApp claim
// link, and an unclaimed listing takes no requests). The import stays on
// the directory page.
import { useCallback, useEffect, useState } from 'react';
import {
  approveProviderClaim,
  getProviderClaims,
  rejectProviderClaim,
  type ProviderClaimRequest,
} from './api';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import { providerErrorMessage } from './providerHelpers';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskPager,
  DeskRetry,
  DeskTable,
  Panel,
  SoftAction,
  Tag,
  TwoLine,
  phoneSpaced,
} from '../../design_system/Desk';
import { AdminPermission, Can } from '../auth/api';
import { agoWords, whenShort } from '../../platform/i18n/deskTime';

type Queue = ProviderClaimRequest['status'];

const LIMIT = 50;

const QUEUES: Array<{ status: Queue; label: string }> = [
  { status: 'PENDING', label: 'ينتظر' },
  { status: 'APPROVED', label: 'استلمه' },
  { status: 'REJECTED', label: 'ما قبلناه' },
];

/** The claim's state as a07 tags it. */
export function claimTag(claim: Pick<ProviderClaimRequest, 'status'>) {
  switch (claim.status) {
    case 'PENDING':
      return <Tag tone="saffron">ينتظر المراجعة</Tag>;
    case 'APPROVED':
      return <Tag tone="green">استلمه</Tag>;
    case 'REJECTED':
      return <Tag tone="coral">ما قبلناه</Tag>;
  }
}

export function ProviderClaimsPage() {
  const [queue, setQueue] = useState<Queue>('PENDING');
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<{
    items: ProviderClaimRequest[];
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  } | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setResult(await getProviderClaims({ status: queue, page, limit: LIMIT }));
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل طلبات الاستلام.');
    }
  }, [queue, page]);

  useEffect(() => {
    void load();
  }, [load]);

  function pick(next: Queue) {
    setQueue(next);
    setPage(1);
    setResult(null);
  }

  const sub = result && queue === 'PENDING'
    ? `يستلمها صاحبها برقمه بعد ما نراجع · ${result.total} طلب ينتظر`
    : 'يستلمها صاحبها برقمه بعد ما نراجع';

  return (
    <section>
      <DeskHeader
        title="ملفات بلا حساب"
        sub={sub}
        actions={QUEUES.map((tab) => (
          <DeskButton
            key={tab.status}
            tone={tab.status === queue ? 'teal' : 'soft'}
            pressed={tab.status === queue}
            onClick={() => pick(tab.status)}
          >
            {tab.label}
          </DeskButton>
        ))}
      />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل طلبات الاستلام…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه طلبات استلام هنا.</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <>
          <DeskTable
            caption="طلبات استلام الملفات"
            columns={[
              { label: 'الملف', flex: 4 },
              { label: 'القسم', flex: 2 },
              { label: 'صاحب الطلب', flex: 3 },
              { label: 'الحالة', flex: 3 },
              { label: '', flex: 3 },
            ]}
            rows={result.items}
            rowKey={(claim) => claim.id}
            renderRow={(claim) => [
              <TwoLine
                key="f"
                main={claim.provider.businessName}
                sub={
                  <>
                    {claim.provider.city?.nameAr ? `${claim.provider.city.nameAr} · ` : ''}
                    <span className="desk-num">{phoneSpaced(claim.provider.phone)}</span>
                  </>
                }
              />,
              claim.provider.primaryCategory?.nameAr ?? '—',
              <TwoLine
                key="c"
                main={claim.claimant?.name ?? '—'}
                sub={`طلب ${agoWords(claim.createdAt)}`}
              />,
              <span key="s" className="desk-tag-cell">
                {claimTag(claim)}
                {claim.status !== 'PENDING' && claim.decidedAt ? (
                  <span className="desk-field-card__more">
                    {claim.decidedBy?.name ?? 'الإدارة'} · {whenShort(claim.decidedAt)}
                    {claim.note ? ` · ${claim.note}` : ''}
                  </span>
                ) : null}
              </span>,
              claim.status === 'PENDING' ? (
                <Can key="a" permission={AdminPermission.PROVIDERS_WRITE}>
                  <span className="desk-actions">
                    <ConfirmDialog
                      variant="desk"
                      title={`سلّم «${claim.provider.businessName}» لصاحب الطلب`}
                      effects={[
                        `يصير الملف لحساب ${claim.claimant?.name ?? 'صاحب الطلب'} برقمه ${phoneSpaced(claim.claimant?.phone ?? '')}.`,
                        'يبدأ يستقبل طلبات العرسان.',
                        'يوصله تنبيه إن استلامه انقبل.',
                      ]}
                      confirmLabel="سلّمه الملف"
                      confirmTone="green"
                      trigger={<SoftAction tone="green">اقبل</SoftAction>}
                      describeError={(error) => providerErrorMessage(error)}
                      onConfirm={async () => {
                        await approveProviderClaim(claim.id);
                        await load();
                      }}
                    />
                    <ConfirmDialog
                      variant="desk"
                      title={`ما نقبل استلام «${claim.provider.businessName}»`}
                      effects={['الملف يبقى بلا حساب وما يستقبل طلبات.', 'السبب يوصل صاحب الطلب في تنبيه.']}
                      needsNote
                      noteLabel="السبب (يوصل صاحب الطلب)"
                      confirmLabel="ارفض"
                      confirmTone="coral"
                      trigger={<SoftAction tone="coral">ارفض</SoftAction>}
                      describeError={(error) => providerErrorMessage(error)}
                      onConfirm={async (note) => {
                        await rejectProviderClaim(claim.id, note);
                        await load();
                      }}
                    />
                  </span>
                </Can>
              ) : null,
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
    </section>
  );
}
