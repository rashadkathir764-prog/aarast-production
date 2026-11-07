// n06 «طلبات البيانات» (D63). The accounts waiting out their 30 days before erasure, soonest
// first, and the downloads of their own data from the last week. The desk
// takes a deletion back only at the account's request («رجّعه بطلبه»); the
// account does the same itself from w06. A download's link belongs to its
// account alone, so the desk sees its state and never the link: the drawn
// «أرسل الرابط» is not built. «كلّمه» has no calling behind it: the number
// is on the row.
import { useCallback, useEffect, useState } from 'react';
import {
  getDataRequests,
  restoreAccountDeletion,
  type DataExportRequest,
  type DataRequests,
  type PendingDeletion,
} from './api';
import {
  DeskHeader,
  DeskNote,
  DeskRetry,
  DeskTable,
  Panel,
  SoftAction,
  Tag,
  phoneSpaced,
} from '../../design_system/Desk';
import { countUnit, dayAgo, dayMonth } from '../../platform/i18n/deskTime';
import { AdminPermission, Can } from '../auth/api';

type Row =
  | { kind: 'export'; key: string; item: DataExportRequest }
  | { kind: 'deletion'; key: string; item: PendingDeletion };

/** The deletion's state as the desk says it. */
export function deletionState(item: PendingDeletion): {
  label: string;
  tone: 'saffron' | 'coral';
} {
  if (item.purgeFailure === 'PROVIDER_HAS_UPCOMING_BOOKINGS') {
    return { label: 'موقوف: عنده حجوزات جاية', tone: 'coral' };
  }
  if (item.purgeFailure) return { label: 'موقوف: تعذّر الحذف', tone: 'coral' };
  if (item.daysLeft <= 0) return { label: 'ينحذف اليوم', tone: 'saffron' };
  return { label: `مهلة: باقي ${countUnit(item.daysLeft, 'day')}`, tone: 'saffron' };
}

/** The download's state as the desk says it. */
export function exportState(item: DataExportRequest): {
  label: string;
  tone: 'green' | 'teal' | 'muted';
} {
  switch (item.state) {
    case 'READY':
      return { label: 'الرابط جاهز', tone: 'green' };
    case 'DOWNLOADED':
      return { label: 'نزّلها', tone: 'teal' };
    case 'EXPIRED':
      return { label: 'انتهى الرابط', tone: 'muted' };
  }
}

export function DataRequestsPage() {
  const [requests, setRequests] = useState<DataRequests | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [restoring, setRestoring] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setRequests(await getDataRequests());
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الطلبات.');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function restore(item: PendingDeletion) {
    setRestoring(item.userId);
    setActionError(null);
    try {
      await restoreAccountDeletion(item.userId);
      await load();
    } catch (value) {
      setActionError(value instanceof Error ? value.message : 'ما قدرنا نرجّع الحساب.');
    } finally {
      setRestoring(null);
    }
  }

  const rows: Row[] = requests
    ? [
        ...requests.exports.map((item) => ({ kind: 'export' as const, key: `e-${item.id}`, item })),
        ...requests.deletions.map((item) => ({
          kind: 'deletion' as const,
          key: `d-${item.userId}`,
          item,
        })),
      ]
    : [];

  return (
    <section>
      <DeskHeader
        title="طلبات البيانات"
        sub="نزّلوا بياناتهم وطلبوا حذف حساباتهم · الحساب ينحذف بعد 30 يوم"
      />
      {actionError ? <DeskNote tone="coral">{actionError}</DeskNote> : null}
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {requests === null && !error ? <DeskNote>لحظة، نحمّل الطلبات…</DeskNote> : null}
      {requests && rows.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه طلب الحين.</DeskNote>
        </Panel>
      ) : null}
      {rows.length > 0 ? (
        <DeskTable
          caption="طلبات البيانات"
          columns={[
            { label: 'الرقم', flex: 3 },
            { label: 'الطلب', flex: 3 },
            { label: 'من', flex: 2 },
            { label: 'الحالة', flex: 3 },
            { label: '', flex: 2 },
          ]}
          rows={rows}
          rowKey={(row) => row.key}
          renderRow={(row) => {
            if (row.kind === 'export') {
              const state = exportState(row.item);
              return [
                phoneSpaced(row.item.phone),
                'نسخة من بياناته',
                dayAgo(row.item.createdAt),
                <Tag key="s" tone={state.tone}>
                  {state.label}
                </Tag>,
                null,
              ];
            }
            const state = deletionState(row.item);
            return [
              phoneSpaced(row.item.phone),
              row.item.kind === 'PROVIDER_ACCOUNT_DELETION' ? 'حذف حساب مزود' : 'حذف الحساب',
              dayMonth(row.item.requestedAt),
              <Tag key="s" tone={state.tone}>
                {state.label}
              </Tag>,
              // RA-AD-10: taking a deletion back needs USERS_WRITE (support reads only).
              <Can key="a" permission={AdminPermission.USERS_WRITE}>
                <SoftAction
                  disabled={restoring !== null}
                  aria-label={`رجّع حساب ${row.item.name} بطلبه`}
                  onClick={(event) => {
                    event.stopPropagation();
                    void restore(row.item);
                  }}
                >
                  {restoring === row.item.userId ? 'لحظة…' : 'رجّعه بطلبه'}
                </SoftAction>
              </Can>,
            ];
          }}
        />
      ) : null}
      <DeskNote>
        حذف حساب المزود ما يكمل وعنده حجوزات جاية، لين يسلّمها أو يلغيها والعرسان يتبلّغون.
      </DeskNote>
    </section>
  );
}
