import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { activateUser, disableUser, getUser, ProviderApplication } from '../api/admin';
import { AdminUser } from '../api/auth';
import { ActionButton, ActionLink } from '../components/ActionButton';
import { DetailField } from '../components/DetailField';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { PageHeader } from '../components/PageHeader';
import { RoleBadge } from '../components/RoleBadge';
import { SectionCard } from '../components/SectionCard';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate } from './providerHelpers';
import { Can } from '../auth/Can';
import { AdminPermission } from '../auth/adminPermissions';

type UserDetails = AdminUser & {
  provider?: ProviderApplication | null;
};

export function UserDetailsPage() {
  const { id } = useParams();
  const [user, setUser] = useState<UserDetails | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    if (!id) return;
    setIsLoading(true);
    setError(null);
    try {
      setUser(await getUser(id));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل تفاصيل المستخدم.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [id]);

  async function toggleUserStatus() {
    if (!user) return;
    setError(null);
    try {
      if (user.status === 'ACTIVE') {
        await disableUser(user.id);
      } else {
        await activateUser(user.id);
      }
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحديث حالة الحساب.');
    }
  }

  if (isLoading) return <LoadingState title="جاري تحميل تفاصيل المستخدم" />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!user) {
    return (
      <EmptyState
        title="المستخدم غير موجود"
        message="لا يمكن عرض هذا الحساب من واجهة الإدارة الحالية."
      />
    );
  }

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="تفاصيل مستخدم"
        icon="♙"
        title={user.name}
        description="عرض آمن لبيانات الحساب المتاحة من Admin API فقط، بدون كلمات مرور أو رموز جلسات أو OTP."
        actions={
          <>
            <Can permission={AdminPermission.USERS_WRITE}>
              <ActionButton
                tone={user.status === 'ACTIVE' ? 'danger' : 'ghost'}
                onClick={toggleUserStatus}
              >
                {user.status === 'ACTIVE' ? 'تعطيل الحساب' : 'تفعيل الحساب'}
              </ActionButton>
            </Can>
            <ActionLink tone="ghost" to="/users">
              العودة للمستخدمين
            </ActionLink>
          </>
        }
        meta={
          <>
            <RoleBadge role={user.role} />
            <StatusBadge status={user.status} />
          </>
        }
      />

      <SectionCard title="بيانات الحساب" subtitle="حقول قراءة فقط من استجابة الإدارة.">
        <div className="details-grid">
          <DetailField label="الاسم">{user.name}</DetailField>
          <DetailField label="الهاتف">
            <span dir="ltr">{user.phone ?? 'غير محدد'}</span>
          </DetailField>
          <DetailField label="البريد">{user.email ?? 'غير محدد'}</DetailField>
          <DetailField label="الدور">
            <RoleBadge role={user.role} />
          </DetailField>
          <DetailField label="الحالة">
            <StatusBadge status={user.status} />
          </DetailField>
          <DetailField label="تاريخ التسجيل">{formatDate(user.createdAt)}</DetailField>
          <DetailField label="آخر تحديث">{formatDate(user.updatedAt)}</DetailField>
        </div>
      </SectionCard>

      <SectionCard title="المزود المرتبط" subtitle="يظهر فقط إذا كان الحساب مرتبطا بملف مزود حقيقي.">
        {user.provider ? (
          <div className="compact-list">
            <Link className="compact-row" to={`/providers/${user.provider.id}`}>
              <b>ملف</b>
              <div>
                <strong>{user.provider.businessName}</strong>
                <span>
                  {user.provider.city?.nameAr ?? 'مدينة غير محددة'} ·{' '}
                  {user.provider.primaryCategory?.nameAr ?? 'فئة غير محددة'}
                </span>
              </div>
              <StatusBadge status={user.provider.status} />
            </Link>
          </div>
        ) : (
          <EmptyState
            title="لا يوجد مزود مرتبط"
            message="هذا الحساب غير مرتبط بملف مزود في بيانات الإدارة الحالية."
          />
        )}
      </SectionCard>
    </section>
  );
}
