import { Link } from 'react-router-dom';
import {
  activateProvider,
  approveProvider,
  ProviderApplication,
  rejectProvider,
  requestProviderChanges,
  suspendProvider,
} from '../api/admin';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { StatusBadge } from '../components/StatusBadge';

export function formatDate(value?: string | null) {
  if (!value) return 'غير محدد';
  return new Intl.DateTimeFormat('ar-YE', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }).format(new Date(value));
}

type ProviderActionsProps = {
  provider: ProviderApplication;
  onChanged: () => Promise<void> | void;
  detailsPath?: string;
};

export function ProviderActions({
  provider,
  onChanged,
  detailsPath,
}: ProviderActionsProps) {
  async function run(action: () => Promise<ProviderApplication>) {
    await action();
    await onChanged();
  }

  return (
    <div className="actions">
      {detailsPath ? (
        <Link className="button small ghost" to={detailsPath}>
          عرض التفاصيل
        </Link>
      ) : null}
      {provider.status !== 'ACTIVE' ? (
        <ConfirmDialog
          title="قبول المورد"
          message="سيصبح المورد ظاهراً للعملاء في سوق الموردين."
          confirmLabel="قبول"
          trigger={<button className="button small">قبول</button>}
          onConfirm={() => run(() => approveProvider(provider.id))}
        />
      ) : null}
      {provider.status === 'SUSPENDED' ? (
        <ConfirmDialog
          title="تنشيط المورد"
          message="سيصبح المورد نشطاً ومتاحاً في السوق العام."
          confirmLabel="تنشيط"
          trigger={<button className="button small ghost">تنشيط</button>}
          onConfirm={() => run(() => activateProvider(provider.id))}
        />
      ) : null}
      {provider.status !== 'NEEDS_CHANGES' ? (
        <ConfirmDialog
          title="طلب تعديل"
          message="سيبقى المورد مخفياً حتى يراجع بياناته."
          confirmLabel="طلب تعديل"
          needsNote
          noteLabel="ملاحظة الإدارة"
          trigger={<button className="button small ghost">طلب تعديل</button>}
          onConfirm={(note) => run(() => requestProviderChanges(provider.id, note))}
        />
      ) : null}
      {provider.status !== 'REJECTED' ? (
        <ConfirmDialog
          title="رفض الطلب"
          message="سيبقى المورد مخفياً عن العملاء."
          confirmLabel="رفض"
          tone="danger"
          needsNote
          noteLabel="سبب الرفض"
          trigger={<button className="button small danger">رفض</button>}
          onConfirm={(reason) => run(() => rejectProvider(provider.id, reason))}
        />
      ) : null}
      {provider.status !== 'SUSPENDED' ? (
        <ConfirmDialog
          title="إيقاف المورد"
          message="سيتم إخفاء المورد من السوق العام مؤقتاً."
          confirmLabel="إيقاف"
          tone="danger"
          needsNote
          noteLabel="سبب الإيقاف"
          trigger={<button className="button small ghost">إيقاف</button>}
          onConfirm={(reason) => run(() => suspendProvider(provider.id, reason))}
        />
      ) : null}
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
      <div>
        <h3>{provider.businessName}</h3>
        <p>
          {provider.user?.name ?? provider.ownerName ?? 'مالك غير محدد'} ·{' '}
          {provider.city?.nameAr ?? 'مدينة غير محددة'} ·{' '}
          {provider.primaryCategory?.nameAr ?? 'فئة غير محددة'}
        </p>
      </div>
      <StatusBadge status={provider.status} />
    </article>
  );
}
