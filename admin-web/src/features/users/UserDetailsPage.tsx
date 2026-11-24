// a13 «تفاصيل مستخدم» and disabling the account. RA-AD-25: the page answers
// the first week's questions: the plans he owns or shares (no money, no
// guests), his business, the chat reports he filed and those filed on him,
// and where he is signed in. Disabling asks for its reason (RA-AD-23), and
// what the window says happens is what disabling does (sessions and live
// invites revoked, the plan kept, no money shown).
import { type ReactNode, useCallback, useEffect, useId, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import {
  activateUser,
  disableUser,
  getUser,
  type AdminUserDetail,
  type AdminUserReport,
} from './api';
import { AdminPermission, hasAdminPermission, useAuth } from '../auth/api';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskRetry,
  Panel,
  TwoLine,
  phoneSpaced,
} from '../../design_system/Desk';
import { dayAgo, dayMonth, whenClock } from '../../platform/i18n/deskTime';

/** RA-AD-23: the server's `MaxLength` of the reason (RA-AD-16). */
const DISABLE_REASON_MAX_LENGTH = 500;

const REPORT_STATUS: Record<AdminUserReport['status'], string | null> = {
  OPEN: null,
  REVIEWED: 'تمت المراجعة',
  DISMISSED: 'ما فيه شيء',
};

/** One card of the page, named by its title for the reader and for tests. */
function Card({ title, children }: { title: string; children: ReactNode }) {
  const id = useId();
  return (
    <div role="region" aria-labelledby={id}>
      <Panel>
        <h2 className="desk-panel__title" id={id}>
          {title}
        </h2>
        {children}
      </Panel>
    </div>
  );
}

function reportLine(report: AdminUserReport): string {
  const who =
    report.direction === 'FILED'
      ? `بلاغ منه على ${report.counterpart}`
      : `بلاغ عليه من ${report.counterpart}`;
  const status = REPORT_STATUS[report.status];
  return [who, dayAgo(report.createdAt), status].filter(Boolean).join(' · ');
}

export function UserDetailsPage() {
  const { id = '' } = useParams();
  const { user: currentAdmin } = useAuth();
  const [user, setUser] = useState<AdminUserDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setUser(await getUser(id));
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل الحساب.');
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!user) {
    return error ? <DeskRetry message={error} onRetry={() => void load()} /> : <DeskNote>لحظة، نحمّل الحساب…</DeskNote>;
  }

  // The server refuses an admin account unless the actor is a super admin,
  // and never lets an admin disable themself; the button follows it.
  const canChange =
    hasAdminPermission(currentAdmin, AdminPermission.USERS_WRITE) &&
    user.id !== currentAdmin?.id &&
    (user.role !== 'ADMIN' || currentAdmin?.adminRole === 'SUPER_ADMIN');

  const sub = (
    <>
      {user.phone ? <span className="desk-num">{phoneSpaced(user.phone)}</span> : null}
      {user.phone && user.createdAt ? ' · ' : null}
      {user.createdAt ? `من ${dayMonth(user.createdAt)}` : null}
    </>
  );

  const action = !canChange ? null : user.status === 'ACTIVE' ? (
    <ConfirmDialog
      title={`تعطيل حساب ${user.name}`}
      effects={[
        'يطلع من كل أجهزته الآن.',
        'الدعوات اللي أرسلها للمشاركين تنلغي.',
        'خطته تبقى، والمشاركين معه يكملون.',
        'ما تقدر تشوف مال خطته ولا ضيوفه.',
      ]}
      needsNote
      noteMaxLength={DISABLE_REASON_MAX_LENGTH}
      noteLabel="السبب"
      confirmLabel="عطّل"
      confirmTone="coral"
      trigger={<DeskButton tone="white-coral">تعطيل الحساب</DeskButton>}
      onConfirm={async (reason) => {
        await disableUser(user.id, reason);
        await load();
      }}
    />
  ) : (
    <ConfirmDialog
      title={`تفعيل حساب ${user.name}`}
      effects={['يقدر يدخل من جديد برقمه.']}
      confirmLabel="فعّل"
      trigger={<DeskButton>تفعيل الحساب</DeskButton>}
      onConfirm={async () => {
        await activateUser(user.id);
        await load();
      }}
    />
  );

  const provider = user.provider;
  const where = provider
    ? [provider.primaryCategory?.nameAr, provider.city?.nameAr].filter(Boolean).join(' · ')
    : '';

  return (
    <section>
      <DeskHeader title={user.name} sub={sub} actions={action} />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      <Card title="الخطط">
        {user.plans.length === 0 ? (
          <DeskNote>ما عنده خطة ولا هو مشارك في خطة.</DeskNote>
        ) : (
          <ul className="desk-list">
            {user.plans.map((plan) => (
              <li key={plan.id}>
                <TwoLine
                  main={plan.title}
                  sub={[
                    plan.role === 'OWNER' ? 'صاحب الخطة' : 'مشارك فيها',
                    plan.weddingDate ? `العرس ${dayMonth(plan.weddingDate)}` : null,
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                />
              </li>
            ))}
          </ul>
        )}
      </Card>
      <Card title="المزود">
        {provider ? (
          <TwoLine
            main={<Link to={`/providers/${provider.id}`}>{provider.businessName}</Link>}
            sub={where || undefined}
          />
        ) : (
          <DeskNote>ما عنده ملف مزود.</DeskNote>
        )}
      </Card>
      <Card title="البلاغات">
        {user.reports.length === 0 ? (
          <DeskNote>ما فيه بلاغ منه ولا عليه.</DeskNote>
        ) : (
          <ul className="desk-list">
            {user.reports.map((report) => (
              <li key={report.id}>
                <TwoLine main={report.reason} sub={reportLine(report)} />
              </li>
            ))}
          </ul>
        )}
      </Card>
      <Card title="الدخول">
        <dl className="desk-pairs">
          <div>
            <dt>أجهزة داخل منها التطبيق</dt>
            <dd>{user.sessions.application}</dd>
          </div>
          {user.role === 'ADMIN' ? (
            <div>
              <dt>جلسات اللوحة المفتوحة</dt>
              <dd>{user.sessions.admin}</dd>
            </div>
          ) : null}
          <div>
            <dt>آخر دخول</dt>
            <dd>{user.sessions.lastLoginAt ? whenClock(user.sessions.lastLoginAt) : 'ما دخل بعد'}</dd>
          </div>
        </dl>
      </Card>
    </section>
  );
}
