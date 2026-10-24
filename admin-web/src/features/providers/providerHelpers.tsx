import type { ReactNode } from 'react';
import {
  activateProvider,
  approveProvider,
  rejectProvider,
  requestProviderChanges,
  setProviderVerified,
  suspendProvider,
  type ProviderApplication,
} from './api';
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import { DeskButton, Tag } from '../../design_system/Desk';
import { AdminPermission, Can } from '../auth/api';

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

const STATUS_TAGS: Record<string, { label: string; tone: 'green' | 'coral' | 'saffron' | 'sky' | 'muted' }> = {
  ACTIVE: { label: 'نشط', tone: 'green' },
  SUSPENDED: { label: 'موقوف', tone: 'coral' },
  PENDING: { label: 'جديد', tone: 'sky' },
  NEEDS_CHANGES: { label: 'يحتاج تعديل', tone: 'saffron' },
  REJECTED: { label: 'مرفوض', tone: 'muted' },
};

/** The provider's state as a design tag («نشط», «موقوف»…). */
export function ProviderStatusTag({ status }: { status: string }) {
  const tag = STATUS_TAGS[status] ?? { label: status, tone: 'muted' as const };
  return <Tag tone={tag.tone}>{tag.label}</Tag>;
}

/** The status word inside a sentence: «نشط من مارس». */
export function providerStatusWord(status: string): string {
  return STATUS_TAGS[status]?.label ?? status;
}

type Decision = {
  key: string;
  button: ReactNode;
  dialog: (trigger: ReactNode) => ReactNode;
};

/**
 * The decisions an admin with PROVIDERS_WRITE can take on a provider, as the
 * designs draw them (a04 review: «اطلب تعديل · اعتماد · رفض»; a06 details:
 * «إيقاف · إلغاء التوثيق»). Each confirms first and says only what the
 * server really does.
 */
export function ProviderDecisions({
  provider,
  onChanged,
}: {
  provider: ProviderApplication;
  onChanged: () => Promise<void> | void;
}) {
  const actions = providerActionVisibility(provider.status);
  const verification = providerVerificationAction(provider);
  const name = provider.businessName;

  async function run(action: () => Promise<ProviderApplication>) {
    await action();
    await onChanged();
  }

  const decisions: Decision[] = [];
  if (actions.requestChanges) {
    decisions.push({
      key: 'changes',
      button: <DeskButton tone="saffron">اطلب تعديل</DeskButton>,
      dialog: (trigger) => (
        <ConfirmDialog
          variant="desk"
          title={`اطلب تعديل من ${name}`}
          effects={['يبقى مخفي عن العرسان لين يعدّل.', 'ملاحظتك توصله في تنبيه.']}
          needsNote
          noteLabel="الملاحظة (توصل المزود)"
          confirmLabel="أرسل الملاحظة"
          confirmTone="saffron"
          trigger={trigger}
          onConfirm={(note) => run(() => requestProviderChanges(provider.id, note))}
        />
      ),
    });
  }
  if (actions.approve) {
    decisions.push({
      key: 'approve',
      button: <DeskButton tone="green">اعتماد</DeskButton>,
      dialog: (trigger) => (
        <ConfirmDialog
          variant="desk"
          title={`اعتماد ${name}`}
          effects={[
            'يظهر للعرسان في الدليل لما تكون عنده خدمة نشطة.',
            'يوصله تنبيه إن طلبه انقبل.',
          ]}
          confirmLabel="اعتمد"
          confirmTone="green"
          trigger={trigger}
          onConfirm={() => run(() => approveProvider(provider.id))}
        />
      ),
    });
  }
  if (actions.reject) {
    decisions.push({
      key: 'reject',
      button: <DeskButton tone="white-coral">رفض</DeskButton>,
      dialog: (trigger) => (
        <ConfirmDialog
          variant="desk"
          title={`رفض ${name}`}
          effects={['ما يظهر للعرسان.', 'السبب يوصله في تنبيه.']}
          needsNote
          noteLabel="السبب (يوصل المزود)"
          confirmLabel="ارفض"
          confirmTone="coral"
          trigger={trigger}
          onConfirm={(reason) => run(() => rejectProvider(provider.id, reason))}
        />
      ),
    });
  }
  if (actions.suspend) {
    decisions.push({
      key: 'suspend',
      button: <DeskButton tone="coral">إيقاف</DeskButton>,
      dialog: (trigger) => (
        <ConfirmDialog
          variant="desk"
          title={`إيقاف ${name}`}
          effects={[
            'يختفي من الدليل وما توصله طلبات جديدة.',
            'يوصله السبب، ويقدر يتواصل مع الدعم.',
          ]}
          needsNote
          noteLabel="السبب (يوصل المزود)"
          confirmLabel="أوقف"
          confirmTone="coral"
          trigger={trigger}
          onConfirm={(reason) => run(() => suspendProvider(provider.id, reason))}
        />
      ),
    });
  }
  if (actions.activate) {
    decisions.push({
      key: 'activate',
      button: <DeskButton tone="teal">تفعيل</DeskButton>,
      dialog: (trigger) => (
        <ConfirmDialog
          variant="desk"
          title={`تفعيل ${name}`}
          effects={['يرجع للدليل ويستقبل طلبات.', 'يوصله تنبيه إن حسابه رجع.']}
          confirmLabel="فعّله"
          trigger={trigger}
          onConfirm={() => run(() => activateProvider(provider.id))}
        />
      ),
    });
  }
  if (verification === 'verify') {
    decisions.push({
      key: 'verify',
      button: <DeskButton tone="soft">توثيق</DeskButton>,
      dialog: (trigger) => (
        <ConfirmDialog
          variant="desk"
          title={`توثيق ${name}`}
          effects={[
            'تأكد إنك راجعت السجل التجاري أو الهوية.',
            'تظهر علامة «موثّق» للعرسان.',
          ]}
          confirmLabel="وثّقه"
          confirmTone="green"
          trigger={trigger}
          onConfirm={() => run(() => setProviderVerified(provider.id, true))}
        />
      ),
    });
  }
  if (verification === 'unverify') {
    decisions.push({
      key: 'unverify',
      button: <DeskButton tone="soft">إلغاء التوثيق</DeskButton>,
      dialog: (trigger) => (
        <ConfirmDialog
          variant="desk"
          title={`إلغاء توثيق ${name}`}
          effects={['تختفي علامة «موثّق» من ملفه.']}
          confirmLabel="ألغِ التوثيق"
          confirmTone="coral"
          trigger={trigger}
          onConfirm={() => run(() => setProviderVerified(provider.id, false))}
        />
      ),
    });
  }

  if (decisions.length === 0) return null;
  return (
    <Can permission={AdminPermission.PROVIDERS_WRITE}>
      {decisions.map((decision) => (
        <span key={decision.key} className="desk-contents">
          {decision.dialog(decision.button)}
        </span>
      ))}
    </Can>
  );
}
