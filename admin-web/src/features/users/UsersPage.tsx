// «المستخدمون»: drawn in the designs' sidebar but without a page of its own
// (D56), so it uses the desk kit the designed pages use. The desk's top
// search («ابحث برقم أو اسم…») lands here as ?search= until n05 «ابحث برقم»
// exists (A-14). A row opens a13, where an account is disabled or enabled
// with what that does; the list itself changes nothing.
import { type FormEvent, useCallback, useEffect, useState } from 'react';import { useNavigate, useSearchParams } from 'react-router-dom';
import { getUsers, type AdminUserRecord } from './api';
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
  grouped,
  phoneSpaced,
} from '../../design_system/Desk';
import { dayMonth } from '../../platform/i18n/deskTime';

type Page = {
  items: AdminUserRecord[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

const ROLE_TAGS: Record<string, { label: string; tone: 'teal' | 'sky' | 'muted' }> = {
  ADMIN: { label: 'إدارة', tone: 'teal' },
  PROVIDER: { label: 'مزود', tone: 'sky' },
  USER: { label: 'مستخدم', tone: 'muted' },
};

export function UsersPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const search = searchParams.get('search') ?? '';
  const [draft, setDraft] = useState(search);
  // The page belongs to its search: a new search from the top bar or this
  // page starts from its first page.
  const [paging, setPaging] = useState({ search, page: 1 });
  const page = paging.search === search ? paging.page : 1;
  const setPage = useCallback((next: number) => setPaging({ search, page: next }), [search]);
  const [attempt, setAttempt] = useState(0);
  const [result, setResult] = useState<Page | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setDraft(search);
    // RA-AD-10: a new term never shows the previous term's rows or count.
    setResult(null);
  }, [search]);

  useEffect(() => {
    // Only the answer to the latest search and page is shown.
    let current = true;
    setError(null);
    getUsers({ search, page, limit: 20 }).then(
      (next) => {
        if (!current) return;
        if (page > next.totalPages && next.totalPages > 0) setPage(next.totalPages);
        else setResult(next as Page);
      },
      (value: unknown) => {
        if (current) setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل المستخدمين.');
      },
    );
    return () => {
      current = false;
    };
  }, [search, page, attempt, setPage]);

  const load = () => setAttempt((value) => value + 1);

  function submit(event: FormEvent) {
    event.preventDefault();
    const term = draft.trim();
    setSearchParams(term ? { search: term } : {});
  }

  return (
    <section>
      <DeskHeader
        title="المستخدمون"
        sub={result ? `${grouped(result.total)} حساب${search ? ` يطابق «${search}»` : ''}` : undefined}
      />
      <Panel>
        <form className="desk-row" onSubmit={submit} role="search" style={{ alignItems: 'flex-end' }}>
          <label className="desk-field">
            ابحث بالاسم أو الرقم
            <input value={draft} onChange={(event) => setDraft(event.target.value)} />
          </label>
          <DeskButton type="submit">ابحث</DeskButton>
        </form>
      </Panel>
      <div className="desk-gap" />
      {error ? <DeskRetry message={error} onRetry={load} /> : null}
      {result === null && !error ? <DeskNote>لحظة، نحمّل المستخدمين…</DeskNote> : null}
      {result && result.items.length === 0 ? (
        <Panel>
          <DeskNote>{search ? `ما فيه حساب يطابق «${search}».` : 'ما فيه حسابات بعد.'}</DeskNote>
        </Panel>
      ) : null}
      {result && result.items.length > 0 ? (
        <>
          <DeskTable
            caption="المستخدمون"
            columns={[
              { label: 'الحساب', flex: 3 },
              { label: 'النوع', flex: 2 },
              { label: 'ملف المزود', flex: 3 },
              { label: 'الحالة', flex: 2 },
              { label: 'من', flex: 2 },
            ]}
            rows={result.items}
            rowKey={(user) => user.id}
            onRowClick={(user) => navigate(`/users/${user.id}`)}
            rowLabel={(user) => `افتح ${user.name}`}
            renderRow={(user) => {
              const role = ROLE_TAGS[user.role] ?? { label: user.role, tone: 'muted' as const };
              return [
                <TwoLine
                  key="a"
                  main={user.name}
                  sub={user.phone ? <span className="desk-num">{phoneSpaced(user.phone)}</span> : undefined}
                />,
                <Tag key="r" tone={role.tone}>{role.label}</Tag>,
                user.provider ? (
                  <TwoLine key="p" main={user.provider.businessName} sub={user.provider.primaryCategory?.nameAr} />
                ) : (
                  <span key="p" className="desk-ink--muted">—</span>
                ),
                user.status === 'ACTIVE' ? (
                  <Tag key="s" tone="green">نشط</Tag>
                ) : (
                  <Tag key="s" tone="coral">معطّل</Tag>
                ),
                user.createdAt ? dayMonth(user.createdAt) : '—',
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
