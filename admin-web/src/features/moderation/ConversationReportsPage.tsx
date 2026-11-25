// a11 «البلاغات»: the open reports beside the one being read, the chats'
// and, in their own tab, the assistant answers' (RA-ST-04, D95). RA-AD-22:
// the reported party is named by the server, the customer included, with
// what can be done about him: suspending an active provider (its reason
// reaches him, as a06's «إيقاف») for whom holds PROVIDERS_WRITE, and the
// customer's account page, where disabling lives. The reported message, «احذف الرسالة» and the history on the same
// party wait for B-41. Closing the report stays: «ما فيه شيء» (dismissed)
// and «تمت المراجعة», each with the reason its reporter is told (Q-50 (أ),
// D124), sent to him as a notification.
import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  type ConversationReport,
  getConversationReports,
  updateConversationReportStatus,
} from './api';
import { AssistantReportsPanel } from './AssistantReportsPanel';
import { suspendProvider } from '../providers/api';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import { AdminPermission, Can, hasAdminPermission, useAuth } from '../auth/api';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskPager,
  DeskRetry,
  DeskTable,
  Panel,
  TwoLine,
  phoneSpaced,
} from '../../design_system/Desk';
import { dayAgo } from '../../platform/i18n/deskTime';
import { pageToShow } from '../../platform/api/query';

type Page = {
  items: ConversationReport[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

type Tab = 'CHATS' | 'ASSISTANT';

export function ConversationReportsPage() {
  const [tab, setTab] = useState<Tab>('CHATS');
  return (
    <section className="desk-fill-page">
      <DeskHeader
        title="البلاغات"
        actions={(
          [
            ['CHATS', 'المحادثات'],
            // RA-ST-04 (D95): the assistant answers reported by their readers.
            ['ASSISTANT', 'إجابات المساعد'],
          ] as const
        ).map(([value, label]) => (
          <DeskButton
            key={value}
            tone={tab === value ? 'teal' : 'soft'}
            pressed={tab === value}
            onClick={() => setTab(value)}
          >
            {label}
          </DeskButton>
        ))}
      />
      {tab === 'CHATS' ? <ChatReports /> : <AssistantReportsPanel />}
    </section>
  );
}

function ChatReports() {
  const { user } = useAuth();
  const canOpenUsers = hasAdminPermission(user, AdminPermission.USERS_READ);
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const next = await getConversationReports({ status: 'OPEN', page, limit: 20 });
      // RA-AD-12: past the last page after its last report was closed.
      const shown = pageToShow(page, next.totalPages);
      if (shown !== page) {
        setPage(shown);
        return;
      }
      setResult(next);
      setSelectedId((current) =>
        next.items.some((report) => report.id === current) ? current : next.items[0]?.id ?? null,
      );
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل البلاغات.');
    }
  }, [page]);

  useEffect(() => {
    void load();
  }, [load]);

  const selected = result?.items.find((report) => report.id === selectedId) ?? null;
  const reportedProvider =
    selected?.reported.kind === 'PROVIDER' ? selected.reported.provider : null;

  function customerName(report: ConversationReport): string {
    return report.reported.kind === 'CUSTOMER'
      ? report.reported.user?.name ?? 'حساب محذوف'
      : report.reporter.name;
  }

  function listLine(report: ConversationReport) {
    const provider = report.conversation.provider.businessName;
    const who =
      report.reported.kind === 'CUSTOMER'
        ? `${provider} بلّغ عن ${customerName(report)}`
        : `${report.reporter.name} بلّغ عن ${provider}`;
    return `${who} · ${dayAgo(report.createdAt)}`;
  }

  function customerLink(user: { id: string; name: string }) {
    return canOpenUsers ? <Link to={`/users/${user.id}`}>{user.name}</Link> : user.name;
  }

  /** The dialog shows a failure itself and stays open with the reason typed. */
  async function close(report: ConversationReport, status: ConversationReport['status'], note: string) {
    await updateConversationReportStatus(report.id, status, note);
    await load();
  }

  function reporterLink(report: ConversationReport) {
    return canOpenUsers ? (
      <Link to={`/users/${report.reporter.id}`}>{report.reporter.name}</Link>
    ) : (
      report.reporter.name
    );
  }

  return (
    <>
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل البلاغات…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه بلاغ مفتوح.</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <div className="desk-split">
          <div className="desk-split__main" style={{ flex: 2 }}>
            <DeskTable
              caption="البلاغات المفتوحة"
              columns={[{ label: 'البلاغ', flex: 4 }]}
              rows={result.items}
              rowKey={(report) => report.id}
              highlight={(report) => report.id === selectedId}
              onRowClick={(report) => {
                setSelectedId(report.id);
              }}
              rowLabel={(report) => `اقرأ بلاغ ${report.reason}`}
              renderRow={(report) => [
                <TwoLine key="r" main={report.reason} sub={listLine(report)} />,
              ]}
            />
            <DeskPager
              page={result.page}
              limit={result.limit}
              total={result.total}
              totalPages={result.totalPages}
              onPageChange={setPage}
            />
          </div>
          <div className="desk-split__side desk-split__side--fill" style={{ flex: 3 }}>
            {selected ? (
              <Panel className="desk-report">
                <h2 className="desk-report__title">{selected.reason}</h2>
                <p className="desk-report__who">
                  {selected.reported.kind === 'CUSTOMER' ? (
                    <>
                      المبلّغ:{' '}
                      <Link to={`/providers/${selected.conversation.provider.id}`}>
                        {selected.conversation.provider.businessName}
                      </Link>{' '}
                      (المزود نفسه) · المبلّغ عنه:{' '}
                      {selected.reported.user ? (
                        <>
                          {customerLink(selected.reported.user)}
                          {selected.reported.user.phone ? (
                            <>
                              {' '}
                              <span className="desk-num">{phoneSpaced(selected.reported.user.phone)}</span>
                            </>
                          ) : null}
                        </>
                      ) : (
                        'حساب محذوف'
                      )}
                    </>
                  ) : (
                    <>
                      المبلّغ: {reporterLink(selected)} · المبلّغ عنه:{' '}
                      <Link to={`/providers/${selected.conversation.provider.id}`}>
                        {selected.conversation.provider.businessName}
                      </Link>
                    </>
                  )}
                </p>
                {reportedProvider?.status === 'ACTIVE' ? (
                  <Can permission={AdminPermission.PROVIDERS_WRITE}>
                    <div className="desk-report__actions">
                      <ConfirmDialog
                        title={`إيقاف ${reportedProvider.businessName}`}
                        effects={[
                          'يختفي من الدليل وما توصله طلبات جديدة.',
                          'يوصله السبب، ويقدر يتواصل مع الدعم.',
                        ]}
                        needsNote
                        noteMaxLength={2000} // AdminReviewActionDto.reason
                        noteLabel="السبب (يوصل المزود)"
                        confirmLabel="أوقف"
                        confirmTone="coral"
                        trigger={<DeskButton tone="coral">إيقاف</DeskButton>}
                        onConfirm={async (reason) => {
                          await suspendProvider(reportedProvider.id, reason);
                          await load();
                        }}
                      />
                    </div>
                  </Can>
                ) : null}
                {selected.reported.kind === 'CUSTOMER' && selected.reported.user && canOpenUsers ? (
                  <div className="desk-report__actions">
                    <Link className="desk-btn desk-btn--soft" to={`/users/${selected.reported.user.id}`}>
                      افتح حسابه
                    </Link>
                  </div>
                ) : null}
                <Can permission={AdminPermission.CONVERSATION_REPORTS_WRITE}>
                  <div className="desk-report__actions">
                    {(
                      [
                        ['REVIEWED', 'تمت المراجعة', 'تمت مراجعة البلاغ', 'teal'],
                        ['DISMISSED', 'ما فيه شيء', 'ما فيه شيء في البلاغ', 'soft'],
                      ] as const
                    ).map(([status, label, title, tone]) => (
                      <ConfirmDialog
                        key={status}
                        title={title}
                        effects={['يتقفل البلاغ ويطلع من المفتوحة.', 'يوصل المبلّغ السبب في تنبيه.']}
                        needsNote
                        noteMaxLength={500} // CONVERSATION_REPORT_CLOSING_NOTE_MAX_LENGTH
                        noteLabel="السبب (يوصل المبلّغ)"
                        confirmLabel="اقفل البلاغ"
                        trigger={<DeskButton tone={tone}>{label}</DeskButton>}
                        onConfirm={(note) => close(selected, status, note)}
                      />
                    ))}
                  </div>
                </Can>
              </Panel>
            ) : null}
          </div>
        </div>
      ) : null}
    </>
  );
}
