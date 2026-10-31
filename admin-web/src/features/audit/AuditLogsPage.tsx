// a15 «سجل التدقيق»: names instead of raw ids and the action in words. The server
// keeps ids only, so the page reads each admin's and provider's name once
// (A-12 would send them); a target other than a provider or a user shows its
// kind. «السبب» waits for A-12, which would store the note of the action.
import { useCallback, useEffect, useState } from 'react';
import { CheckCircle2, Clock, XCircle } from 'lucide-react';
import { type AdminAuditLog, type AdminAuditPhase, getAdminAuditLogs } from './api';
import {
  DeskHeader,
  DeskNote,
  DeskPager,
  DeskRetry,
  DeskTable,
  Panel,
} from '../../design_system/Desk';
import { whenClock } from '../../platform/i18n/deskTime';

type Kind = 'provider' | 'user' | string;

type ActionWords = { label: string; target: Kind };

/** The route templates the audit interceptor records, in the designs' words. */
const ACTIONS: Array<[string, RegExp, ActionWords]> = [
  ['POST', /^\/admin\/providers$/, { label: 'أضاف مزود بلا حساب', target: '—' }],
  ['PATCH', /^\/admin\/providers\/:id\/approve$/, { label: 'اعتمد', target: 'provider' }],
  ['PATCH', /^\/admin\/providers\/:id\/reject$/, { label: 'رفض', target: 'provider' }],
  ['PATCH', /^\/admin\/providers\/:id\/request-changes$/, { label: 'طلب تعديل', target: 'provider' }],
  ['PATCH', /^\/admin\/providers\/:id\/suspend$/, { label: 'أوقف', target: 'provider' }],
  ['PATCH', /^\/admin\/providers\/:id\/activate$/, { label: 'فعّل', target: 'provider' }],
  ['PATCH', /^\/admin\/providers\/:id\/verify$/, { label: 'وثّق', target: 'provider' }],
  ['PATCH', /^\/admin\/providers\/:id\/unverify$/, { label: 'ألغى التوثيق', target: 'provider' }],
  ['POST', /^\/admin\/services$/, { label: 'أضاف خدمة', target: '—' }],
  ['PATCH', /^\/admin\/services\/:id$/, { label: 'عدّل خدمة', target: 'خدمة' }],
  ['DELETE', /^\/admin\/services\/:id$/, { label: 'أوقف خدمة', target: 'خدمة' }],
  ['PATCH', /^\/admin\/reviews\/:id\/status$/, { label: 'غيّر حالة تقييم', target: 'تقييم' }],
  ['DELETE', /^\/admin\/reviews\/:id$/, { label: 'أخفى تقييم', target: 'تقييم' }],
  ['PATCH', /^\/admin\/conversation-reports\/:id\/status$/, { label: 'قفل بلاغ', target: 'بلاغ' }],
  ['PATCH', /^\/admin\/notifications\/:id\/read$/, { label: 'علّم إشعار مقروء', target: 'إشعار' }],
  ['PATCH', /^\/admin\/notifications\/:id\/archive$/, { label: 'أرشف إشعار', target: 'إشعار' }],
  ['DELETE', /^\/admin\/notifications\/:id$/, { label: 'حذف إشعار', target: 'إشعار' }],
  ['POST', /^\/admin\/provider-categories$/, { label: 'أضاف قسم', target: '—' }],
  ['PATCH', /^\/admin\/provider-categories\/:id$/, { label: 'عدّل قسم', target: 'قسم' }],
  ['DELETE', /^\/admin\/provider-categories\/:id$/, { label: 'عطّل قسم', target: 'قسم' }],
  ['POST', /^\/admin\/cities$/, { label: 'أضاف مدينة', target: '—' }],
  ['PATCH', /^\/admin\/cities\/:id$/, { label: 'عدّل مدينة', target: 'مدينة' }],
  ['DELETE', /^\/admin\/cities\/:id$/, { label: 'عطّل مدينة', target: 'مدينة' }],
  ['PATCH', /^\/admin\/users\/:id\/activate$/, { label: 'فعّل حساب', target: 'user' }],
  ['PATCH', /^\/admin\/users\/:id\/disable$/, { label: 'عطّل حساب', target: 'user' }],
  ['POST', /^\/admin\/reference-catalogs\/:catalogKey\/items$/, { label: 'أضاف عنصر كتالوج', target: '—' }],
  ['PATCH', /^\/admin\/reference-catalogs\/:catalogKey\/items\/:id$/, { label: 'عدّل عنصر كتالوج', target: 'عنصر كتالوج' }],
  ['POST', /^\/admin\/reference-catalogs\/:catalogKey\/items\/:id\/publish$/, { label: 'نشر عنصر كتالوج', target: 'عنصر كتالوج' }],
  ['DELETE', /^\/admin\/reference-catalogs\/:catalogKey\/items\/:id$/, { label: 'أوقف عنصر كتالوج', target: 'عنصر كتالوج' }],
  ['POST', /^\/admin\/governorates$/, { label: 'أضاف محافظة', target: '—' }],
  ['PATCH', /^\/admin\/governorates\/:id$/, { label: 'عدّل محافظة', target: 'محافظة' }],
  ['DELETE', /^\/admin\/governorates\/:id$/, { label: 'عطّل محافظة', target: 'محافظة' }],
  ['POST', /^\/admin\/governorates\/:id\/districts$/, { label: 'أضاف مديرية', target: 'محافظة' }],
  ['PATCH', /^\/admin\/districts\/:id$/, { label: 'عدّل مديرية', target: 'مديرية' }],
  ['DELETE', /^\/admin\/districts\/:id$/, { label: 'عطّل مديرية', target: 'مديرية' }],
  ['POST', /^\/admin\/districts\/:id\/localities$/, { label: 'أضاف منطقة', target: 'مديرية' }],
  ['PATCH', /^\/admin\/localities\/:id$/, { label: 'عدّل منطقة', target: 'منطقة' }],
  ['DELETE', /^\/admin\/localities\/:id$/, { label: 'عطّل منطقة', target: 'منطقة' }],
];

export function auditActionWords(method: string, route: string): ActionWords {
  const found = ACTIONS.find(([verb, pattern]) => verb === method && pattern.test(route));
  return found?.[2] ?? { label: 'إجراء آخر', target: '—' };
}

const ROLE_SHORT: Record<AdminAuditLog['actorAdminRole'], string> = {
  SUPER_ADMIN: 'مدير أعلى',
  OPERATIONS: 'تشغيل',
  MODERATOR: 'إشراف',
  SUPPORT: 'دعم',
};

const RESULTS: Record<AdminAuditPhase, { label: string; Icon: typeof CheckCircle2; tone: string }> = {
  SUCCEEDED: { label: 'نجح', Icon: CheckCircle2, tone: 'desk-ink--green' },
  FAILED: { label: 'فشل', Icon: XCircle, tone: 'desk-ink--coral' },
  ATTEMPT: { label: 'بدون نتيجة', Icon: Clock, tone: 'desk-ink--muted' },
};

/**
 * Each action is recorded twice (an attempt, then its result); one line per
 * action keeps its result, or the attempt when no result came.
 */
export function oneLinePerAction(logs: AdminAuditLog[]): AdminAuditLog[] {
  const finals = new Set(logs.filter((log) => log.phase !== 'ATTEMPT').map((log) => log.eventId));
  return logs.filter((log) => log.phase !== 'ATTEMPT' || !finals.has(log.eventId));
}

type AuditLogsPageProps = {
  /** Name lookups handed in by the app (users and providers own them). */
  getUserName: (id: string) => Promise<string>;
  getProviderName: (id: string) => Promise<string>;
};

type Page = {
  items: AdminAuditLog[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export function AuditLogsPage({ getUserName, getProviderName }: AuditLogsPageProps) {
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page | null>(null);
  const [names, setNames] = useState<Map<string, string>>(new Map());
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const next = await getAdminAuditLogs({ page, limit: 40 });
      const wanted = new Map<string, () => Promise<string>>();
      for (const log of next.items) {
        wanted.set(`user:${log.actorUserId}`, () => getUserName(log.actorUserId));
        const kind = auditActionWords(log.method, log.route).target;
        if (log.targetId && kind === 'provider') {
          const id = log.targetId;
          wanted.set(`provider:${id}`, () => getProviderName(id));
        }
        if (log.targetId && kind === 'user') {
          const id = log.targetId;
          wanted.set(`user:${id}`, () => getUserName(id));
        }
      }
      const keys = [...wanted.keys()];
      const read = await Promise.allSettled(keys.map((key) => wanted.get(key)!()));
      const found = new Map<string, string>();
      keys.forEach((key, index) => {
        const outcome = read[index];
        if (outcome.status === 'fulfilled') found.set(key, outcome.value);
      });
      setNames(found);
      setResult(next);
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل السجل.');
    }
  }, [page, getUserName, getProviderName]);

  useEffect(() => {
    void load();
  }, [load]);

  function target(log: AdminAuditLog): string {
    const kind = auditActionWords(log.method, log.route).target;
    if (!log.targetId || kind === '—') return '—';
    if (kind === 'provider') return names.get(`provider:${log.targetId}`) ?? 'مزود';
    if (kind === 'user') return names.get(`user:${log.targetId}`) ?? 'حساب';
    return kind;
  }

  const rows = result ? oneLinePerAction(result.items) : [];

  return (
    <section>
      <DeskHeader title="سجل التدقيق" sub="كل إجراء في اللوحة" />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل السجل…</DeskNote> : null}
      {result && rows.length === 0 ? (
        <Panel>
          <DeskNote>ما فيه إجراءات بعد.</DeskNote>
        </Panel>
      ) : null}
      {result && rows.length > 0 ? (
        <>
          <DeskTable
            caption="سجل التدقيق"
            columns={[
              { label: 'متى', flex: 2 },
              { label: 'مين', flex: 2 },
              { label: 'ايش سوى', flex: 4 },
              { label: 'على', flex: 3 },
              { label: 'النتيجة', flex: 1 },
            ]}
            rows={rows}
            rowKey={(log) => log.id}
            renderRow={(log) => {
              const outcome = RESULTS[log.phase];
              return [
                whenClock(log.createdAt),
                <span key="w" className="desk-small">
                  {names.get(`user:${log.actorUserId}`) ?? 'عضو'} · {ROLE_SHORT[log.actorAdminRole]}
                </span>,
                <strong key="a">{auditActionWords(log.method, log.route).label}</strong>,
                target(log),
                <span key="r" className={outcome.tone} role="img" aria-label={outcome.label}>
                  <outcome.Icon size={18} aria-hidden="true" />
                </span>,
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
