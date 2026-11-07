// a11 «البلاغات»: the open reports beside the one being read, the chats'
// and, in their own tab, the assistant answers' (RA-ST-04, D95). The
// reported message, «احذف الرسالة» and the history on the same party wait
// for B-41; «نبّه المزود» and «اطلب إيقافه» wait for A-09. What stays is
// closing the report: «ما فيه شيء» (dismissed) and «تمت المراجعة».
import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  type ConversationReport,
  getConversationReports,
  updateConversationReportStatus,
} from './api';
import { AssistantReportsPanel } from './AssistantReportsPanel';
import { getProvider } from '../providers/api';
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
} from '../../design_system/Desk';
import { dayAgo } from '../../platform/i18n/deskTime';
import { pageToShow } from '../../platform/api/query';

/**
 * The account that owns each reported provider: null when the provider has
 * none (an admin-listed business), undefined when it could not be read. A
 * report whose reporter owns the conversation's provider was filed by the
 * provider, so the reported party is the customer.
 */
async function providerOwners(
  reports: ConversationReport[],
): Promise<Map<string, string | null | undefined>> {
  const ids = [...new Set(reports.map((report) => report.conversation.provider.id))];
  const results = await Promise.allSettled(ids.map((id) => getProvider(id)));
  return new Map(
    ids.map((id, index) => {
      const result = results[index];
      return [id, result.status === 'fulfilled' ? result.value.userId : undefined];
    }),
  );
}

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
  const [owners, setOwners] = useState<Map<string, string | null | undefined>>(new Map());
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

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
      setOwners(await providerOwners(next.items));
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

  function parties(report: ConversationReport) {
    const provider = report.conversation.provider;
    const byProvider = owners.get(provider.id) != null && owners.get(provider.id) === report.reporter.id;
    return { provider, byProvider };
  }

  function listLine(report: ConversationReport) {
    const { provider, byProvider } = parties(report);
    const who = byProvider
      ? `${provider.businessName} بلّغ عن العميل`
      : `${report.reporter.name} بلّغ عن ${provider.businessName}`;
    return `${who} · ${dayAgo(report.createdAt)}`;
  }

  async function close(report: ConversationReport, status: ConversationReport['status']) {
    setBusy(true);
    setActionError(null);
    try {
      await updateConversationReportStatus(report.id, status);
      await load();
    } catch (value) {
      setActionError(value instanceof Error ? value.message : 'ما قدرنا نقفل البلاغ.');
    } finally {
      setBusy(false);
    }
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
                setActionError(null);
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
                  {parties(selected).byProvider ? (
                    <>
                      المبلّغ:{' '}
                      <Link to={`/providers/${selected.conversation.provider.id}`}>
                        {selected.conversation.provider.businessName}
                      </Link>{' '}
                      (المزود نفسه) · المبلّغ عنه: العميل في المحادثة
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
                <Can permission={AdminPermission.CONVERSATION_REPORTS_WRITE}>
                  <div className="desk-report__actions">
                    <DeskButton disabled={busy} onClick={() => void close(selected, 'REVIEWED')}>
                      تمت المراجعة
                    </DeskButton>
                    <DeskButton tone="soft" disabled={busy} onClick={() => void close(selected, 'DISMISSED')}>
                      ما فيه شيء
                    </DeskButton>
                  </div>
                </Can>
                {actionError ? <DeskNote tone="coral">{actionError}</DeskNote> : null}
              </Panel>
            ) : null}
          </div>
        </div>
      ) : null}
    </>
  );
}
