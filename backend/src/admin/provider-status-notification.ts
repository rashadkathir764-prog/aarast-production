import { NotificationType, ProviderStatus } from '@prisma/client';

/** Adds the team's note to the standard sentence, never instead of it (D54). */
export function withTeamNote(sentence: string, note: string | null | undefined): string {
  const trimmed = note?.trim();
  return trimmed ? `${sentence}\nملاحظة الفريق: ${trimmed}` : sentence;
}

/**
 * What a provider reads when the team moves his profile (B-19: each status
 * its own type; B-38: the words say what is true, «مزود» and no «بوابة»).
 * The portal opens on the screen of his status, so each opens the portal.
 */
export function switchProviderStatusNotification(
  businessName: string,
  status: ProviderStatus,
  reviewNote: string | null,
): { type: NotificationType; title: string; body: string } {
  const profile = businessName.trim() ? `ملف ${businessName.trim()}` : 'ملفك';
  switch (status) {
    case ProviderStatus.ACTIVE:
      return {
        type: NotificationType.PROVIDER_APPROVED,
        title: 'اعتمدنا ملفك',
        body: withTeamNote(
          `${profile} صار ظاهر للعرسان، وتقدر تستقبل طلباتهم.`,
          reviewNote,
        ),
      };
    case ProviderStatus.NEEDS_CHANGES:
      return {
        type: NotificationType.PROVIDER_NEEDS_CHANGES,
        title: 'ملفك يحتاج تعديل',
        body: withTeamNote(
          `صلّح ${profile} على ملاحظات فريق اعّرست، وبعدها أرسل التعديل.`,
          reviewNote,
        ),
      };
    case ProviderStatus.REJECTED:
      return {
        type: NotificationType.PROVIDER_REJECTED,
        title: 'ما اعتمدنا ملفك',
        body: withTeamNote(
          `صلّح ${profile} وقدّم من جديد من حسابك.`,
          reviewNote,
        ),
      };
    case ProviderStatus.SUSPENDED:
      return {
        type: NotificationType.PROVIDER_SUSPENDED,
        title: 'وقّفنا ملفك',
        body: withTeamNote(
          `${profile} ما يظهر للعرسان ولا يستقبل طلبات، والحجوزات المؤكدة ما تنلغى. لو عندك سؤال كلّم فريق اعّرست.`,
          reviewNote,
        ),
      };
    case ProviderStatus.PENDING:
      return {
        type: NotificationType.PROVIDER_IN_REVIEW,
        title: 'ملفك تحت المراجعة',
        body: `نراجع ${profile} ونبلغك هنا.`,
      };
  }
}
