import {
  activateProvider,
  approveProvider,
  rejectProvider,
  requestProviderChanges,
  setProviderVerified,
  suspendProvider,
  type ProviderApplication,
} from './api';
import { ActionButton, ActionLink } from '../../design_system/ActionButton';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import { DetailField } from '../../design_system/DetailField';
import { StatusBadge } from '../../design_system/StatusBadge';
import { AdminPermission, Can } from '../auth/api';

export function shortId(value: string) {
  return `#${value.slice(0, 8).toUpperCase()}`;
}

type ProviderActionsProps = {
  provider: ProviderApplication;
  onChanged: () => Promise<void> | void;
  detailsPath?: string;
};

export function providerActionVisibility(
  status: ProviderApplication['status'],
) {
  return {
    approve: ['PENDING', 'NEEDS_CHANGES', 'REJECTED'].includes(status),
    activate: status === 'SUSPENDED',
    requestChanges: ['PENDING', 'REJECTED'].includes(status),
    reject: ['PENDING', 'NEEDS_CHANGES'].includes(status),
    suspend: status === 'ACTIVE',
  };
}

/** Verify is offered on an active provider; clearing the badge always is. */
export function providerVerificationAction(
  provider: Pick<ProviderApplication, 'status' | 'verifiedAt'>,
): 'verify' | 'unverify' | null {
  if (provider.verifiedAt) return 'unverify';
  return provider.status === 'ACTIVE' ? 'verify' : null;
}

export function ProviderActions({
  provider,
  onChanged,
  detailsPath,
}: ProviderActionsProps) {
  const actions = providerActionVisibility(provider.status);
  const verification = providerVerificationAction(provider);

  async function run(action: () => Promise<ProviderApplication>) {
    await action();
    await onChanged();
  }

  return (
    <div className="actions">
      {detailsPath ? (
        <ActionLink tone="ghost" size="small" to={detailsPath}>
          عرض
        </ActionLink>
      ) : null}
      <Can permission={AdminPermission.PROVIDERS_WRITE}>
        {actions.approve ? (
        <ConfirmDialog
          title="اعتماد المورد"
          message="سيصبح المورد ظاهرا للعملاء في سوق الموردين بعد الاعتماد."
          confirmLabel="اعتماد"
          trigger={
            <ActionButton size="small" type="button">
              اعتماد
            </ActionButton>
          }
          onConfirm={() => run(() => approveProvider(provider.id))}
        />
        ) : null}
        {actions.activate ? (
        <ConfirmDialog
          title="تفعيل المورد"
          message="سيعود المورد إلى الحالة النشطة والمتاحة في السوق العام."
          confirmLabel="تفعيل"
          trigger={
            <ActionButton tone="ghost" size="small" type="button">
              تفعيل
            </ActionButton>
          }
          onConfirm={() => run(() => activateProvider(provider.id))}
        />
        ) : null}
        {actions.requestChanges ? (
        <ConfirmDialog
          title="طلب تعديل"
          message="سيبقى المورد مخفيا حتى يراجع بياناته ويعالج ملاحظات الإدارة."
          confirmLabel="طلب تعديل"
          needsNote
          noteLabel="ملاحظة الإدارة"
          trigger={
            <ActionButton tone="ghost" size="small" type="button">
              طلب تعديل
            </ActionButton>
          }
          onConfirm={(note) =>
            run(() => requestProviderChanges(provider.id, note))
          }
        />
        ) : null}
        {actions.reject ? (
        <ConfirmDialog
          title="رفض الطلب"
          message="سيبقى المورد مخفيا عن العملاء ولن يظهر في السوق العام."
          confirmLabel="رفض"
          tone="danger"
          needsNote
          noteLabel="سبب الرفض"
          trigger={
            <ActionButton tone="danger" size="small" type="button">
              رفض
            </ActionButton>
          }
          onConfirm={(reason) => run(() => rejectProvider(provider.id, reason))}
        />
        ) : null}
        {actions.suspend ? (
        <ConfirmDialog
          title="إيقاف المورد"
          message="سيتم إخفاء المورد من السوق العام مؤقتا حتى تتم مراجعته."
          confirmLabel="إيقاف"
          tone="danger"
          needsNote
          noteLabel="سبب الإيقاف"
          trigger={
            <ActionButton tone="ghost" size="small" type="button">
              إيقاف
            </ActionButton>
          }
          onConfirm={(reason) => run(() => suspendProvider(provider.id, reason))}
        />
        ) : null}
        {verification === 'verify' ? (
        <ConfirmDialog
          title="توثيق المورد"
          message="تأكد أنك راجعت وثائق المورد (السجل التجاري أو الهوية). ستظهر شارة «موثّق» للعملاء."
          confirmLabel="توثيق"
          trigger={
            <ActionButton tone="ghost" size="small" type="button">
              توثيق
            </ActionButton>
          }
          onConfirm={() => run(() => setProviderVerified(provider.id, true))}
        />
        ) : null}
        {verification === 'unverify' ? (
        <ConfirmDialog
          title="إلغاء التوثيق"
          message="ستختفي شارة «موثّق» عن المورد في التطبيق."
          confirmLabel="إلغاء التوثيق"
          tone="danger"
          trigger={
            <ActionButton tone="ghost" size="small" type="button">
              إلغاء التوثيق
            </ActionButton>
          }
          onConfirm={() => run(() => setProviderVerified(provider.id, false))}
        />
        ) : null}
      </Can>
    </div>
  );
}

export function ProviderSummaryCard({
  provider,
}: {
  provider: ProviderApplication;
}) {
  return (
    <article className="provider-summary">
      <div className="provider-summary__avatar" aria-hidden="true">
        {provider.logoUrl ? (
          <img src={provider.logoUrl} alt="" />
        ) : (
          provider.businessName.slice(0, 1)
        )}
      </div>
      <div className="provider-summary__main">
        <span className="eyebrow">ملف مورد</span>
        <h2>{provider.businessName}</h2>
        <p>
          {provider.user?.name ?? provider.ownerName ?? 'مالك غير محدد'} ·{' '}
          {provider.city?.nameAr ?? 'مدينة غير محددة'} ·{' '}
          {provider.primaryCategory?.nameAr ?? 'فئة غير محددة'}
        </p>
      </div>
      <div className="provider-summary__details">
        <DetailField label="رقم الطلب">{shortId(provider.id)}</DetailField>
        <DetailField label="الهاتف">
          <span dir="ltr">{provider.phone}</span>
        </DetailField>
        <StatusBadge status={provider.status} />
        {provider.verifiedAt ? (
          <DetailField label="التوثيق">
            موثّق منذ {new Date(provider.verifiedAt).toLocaleDateString('ar')}
          </DetailField>
        ) : null}
      </div>
    </article>
  );
}
