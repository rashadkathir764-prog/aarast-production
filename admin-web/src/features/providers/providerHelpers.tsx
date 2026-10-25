import type { ReactNode } from 'react';
import {
  activateProvider,
  approveProvider,
  rejectProvider,
  requestProviderChanges,
  setProviderVerified,
  suspendProvider,
  type ProviderApplication,
  type ProviderFieldNote,
} from './api';

function fieldNotesWord(count: number): string {
  if (count === 1) return 'ملاحظتك على الحقل';
  if (count === 2) return 'ملاحظاتك على الحقلين';
  return `ملاحظاتك على ${count} حقول`;
}
import { ConfirmDialog } from '../../design_system/ConfirmDialog';
import { DeskButton, Tag } from '../../design_system/Desk';
import { ApiError } from '../../platform/api/client';
import { AdminPermission, Can } from '../auth/api';

/**
 * What the reviewer reads, and does next, when the server refuses a
 * provider action for a known reason. The API client keeps the server's
 * code on the error and leaves its meaning to the pages that act on it;
 * every provider page reads it here.
 */
const PROVIDER_ERROR_MESSAGES: Record<string, string> = {
  PROVIDER_PHONE_TAKEN: 'هذا الرقم مسجّل لمزوّد آخر. ابحث عنه في القائمة بدل إضافته من جديد.',
  // B-12: a claim that can no longer be honoured.
  PROVIDER_CLAIM_LISTING_TAKEN: 'الملف صار له صاحب أو ما عاد نشط. ارفض الطلب.',
  PROVIDER_CLAIM_ACCOUNT_INACTIVE: 'حساب صاحب الطلب موقوف. ارفض الطلب.',
  PROVIDER_CLAIM_ACCOUNT_HAS_PROVIDER: 'صاحب الطلب عنده ملف مزود ثاني. ارفض الطلب.',
  PROVIDER_CLAIM_PHONE_CHANGED:
    'رقم صاحب الطلب تغيّر وما عاد نفس رقم الملف. ارفض الطلب، ويقدر يطلبه من جديد من رقم الملف.',
  PROVIDER_CLAIM_NOT_PENDING: 'انحسم هذا الطلب قبل. حدّث الصفحة.',
  // D41 (B-10): approval needs an active service with its price.
  PROVIDER_SERVICE_REQUIRED:
    'ما عنده خدمة نشطة بسعرها. اطلب منه تعديل يضيف خدمته وسعرها، وبعدها اعتمده.',
};

export function providerErrorMessage(error: unknown, fallback = 'ما قدرنا ننفذ الطلب.'): string {
  if (error instanceof ApiError && error.code) {
    const known = PROVIDER_ERROR_MESSAGES[error.code];
    if (known) return known;
  }
  return error instanceof Error ? error.message : fallback;
}

/**
 * The server's lifecycle matrix: a refused profile leaves REJECTED only by
 * its provider reopening it (B-02), and the notes can be rewritten while the
 * provider is still fixing (B-01).
 */
export function providerActionVisibility(
  status: ProviderApplication['status'],
) {
  return {
    approve: ['PENDING', 'NEEDS_CHANGES'].includes(status),
    activate: status === 'SUSPENDED',
    requestChanges: ['PENDING', 'NEEDS_CHANGES'].includes(status),
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
  fieldNotes = [],
  onChanged,
}: {
  provider: ProviderApplication;
  /** The notes written on the fields (a04), sent with «اطلب تعديل» (B-01). */
  fieldNotes?: ProviderFieldNote[];
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
          effects={[
            'يبقى مخفي عن العرسان لين يعدّل.',
            fieldNotes.length > 0
              ? `${fieldNotesWord(fieldNotes.length)} تظهر له جنب الحقل نفسه.`
              : 'اكتب ملاحظة عامة هنا، أو اضغط «ملاحظة» على الحقل اللي يحتاج تعديل.',
            provider.status === 'NEEDS_CHANGES'
              ? 'اللي ترسله الحين يحل محل كل ملاحظاته: الملاحظة العامة هنا، وملاحظات الحقول جنب كل حقل. اللي تمسحه ما يوصله.'
              : 'لما يصلّح ويرسل التعديل، يرجع لقائمة «أُعيد إرسالها».',
          ]}
          needsNote
          noteRequired={fieldNotes.length === 0}
          noteLabel="ملاحظة عامة (توصل المزود)"
          // While he fixes, the box opens with the note he reads now, so
          // sending replaces what the reviewer sees (B-01).
          initialNote={provider.status === 'NEEDS_CHANGES' ? (provider.reviewNote ?? '') : ''}
          describeError={(error) => providerErrorMessage(error)}
          confirmLabel="أرسل الملاحظات"
          confirmTone="saffron"
          trigger={trigger}
          onConfirm={(note) =>
            run(() => requestProviderChanges(provider.id, { note, fieldNotes }))
          }
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
          describeError={(error) => providerErrorMessage(error)}
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
