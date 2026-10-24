// a13 «تفاصيل مستخدم» and disabling the account (mobile/test/prototype/admin/
// admin_screens.dart `a13User`). The cards «صاحب خطة», «مشارك في خطة»,
// «مسجّل دخول» and «طلب حذف» wait for A-10, and the window gives no counts
// because the server returns none; what it says happens is what disabling
// does (sessions and live invites revoked, the plan kept, no money shown).
import { useCallback, useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { activateUser, disableUser, getUser, type AdminUserRecord } from './api';
import { AdminPermission, hasAdminPermission, useAuth } from '../auth/api';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskRetry,
  phoneSpaced,
} from '../../design_system/Desk';
import { dayMonth } from '../../platform/i18n/deskTime';

export function UserDetailsPage() {
  const { id = '' } = useParams();
  const { user: currentAdmin } = useAuth();
  const [user, setUser] = useState<AdminUserRecord | null>(null);
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
      variant="desk"
      title={`تعطيل حساب ${user.name}`}
      effects={[
        'يطلع من كل أجهزته الآن.',
        'الدعوات اللي أرسلها للمشاركين تنلغي.',
        'خطته تبقى، والمشاركين معه يكملون.',
        'ما تقدر تشوف مال خطته ولا ضيوفه.',
      ]}
      confirmLabel="عطّل"
      confirmTone="coral"
      trigger={<DeskButton tone="white-coral">تعطيل الحساب</DeskButton>}
      onConfirm={async () => {
        await disableUser(user.id);
        await load();
      }}
    />
  ) : (
    <ConfirmDialog
      variant="desk"
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

  return (
    <section>
      <DeskHeader title={user.name} sub={sub} actions={action} />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
    </section>
  );
}
