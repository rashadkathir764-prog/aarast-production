// RA-ST-04 (D95): the assistant answers their readers reported, beside the
// chat reports in «البلاغات» (a11) and under the same permissions. The team
// reads what was asked, the answer and why (the reporter stays unnamed),
// and closes the report with «تمت المراجعة». What it learns feeds the
// assistant's instructions; nothing here changes an answer already given.
import { useCallback, useEffect, useState } from 'react';
import { type AssistantAnswerReport, getAssistantReports, resolveAssistantReport } from './api';
import { AdminPermission, Can } from '../auth/api';
import {
  DeskButton,
  DeskNote,
  DeskPager,
  DeskRetry,
  DeskTable,
  Panel,
  TwoLine,
} from '../../design_system/Desk';
import { dayAgo } from '../../platform/i18n/deskTime';

/** The ready-made requests as the app names them (b11). */
const KIND_LABELS: Record<string, string> = {
  PLAN: 'خطة عمل حتى يوم العرس',
  BUDGET_SPLIT: 'وزّع لي الميزانية',
  COMPARE_QUOTES: 'قارن عروض الأسعار',
  CHEAPER: 'وين أوفر؟',
  FORGOTTEN: 'ايش نسيت؟',
  NEGOTIATION: 'اكتب رسالة تفاوض',
  QUESTION: 'سؤال آخر',
};

/** What the reader asked: their own words, or the request they picked. */
export function assistantReportAsked(report: AssistantAnswerReport): string {
  return report.question?.trim() || KIND_LABELS[report.kind] || report.kind;
}

type Page = {
  items: AssistantAnswerReport[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export function AssistantReportsPanel() {
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setError(null);
    try {
      const next = await getAssistantReports({ status: 'OPEN', page, limit: 20 });
      setResult(next);
      setSelectedId((current) =>
        next.items.some((report) => report.id === current) ? current : next.items[0]?.id ?? null,
      );
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل بلاغات المساعد.');
    }
  }, [page]);

  useEffect(() => {
    void load();
  }, [load]);

  const selected = result?.items.find((report) => report.id === selectedId) ?? null;

  async function resolve(report: AssistantAnswerReport) {
    setBusy(true);
    setActionError(null);
    try {
      await resolveAssistantReport(report.id);
      await load();
    } catch (value) {
      setActionError(value instanceof Error ? value.message : 'ما قدرنا نقفل البلاغ.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل بلاغات المساعد…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه إجابة مبلّغ عنها.</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <div className="desk-split">
          <div className="desk-split__main" style={{ flex: 2 }}>
            <DeskTable
              caption="إجابات المساعد المبلّغ عنها"
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
                <TwoLine
                  key="r"
                  main={report.reason}
                  sub={`${assistantReportAsked(report)} · ${dayAgo(report.createdAt)}`}
                />,
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
                <p className="desk-report__who">السؤال: {assistantReportAsked(selected)}</p>
                <p style={{ whiteSpace: 'pre-wrap' }}>{selected.answer}</p>
                <Can permission={AdminPermission.CONVERSATION_REPORTS_WRITE}>
                  <div className="desk-report__actions">
                    <DeskButton disabled={busy} onClick={() => void resolve(selected)}>
                      تمت المراجعة
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
