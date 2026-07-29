import { ProviderStatus } from '@prisma/client';

export function switchProviderStatusNotification(
  businessName: string,
  status: ProviderStatus,
  reviewNote: string | null,
): { title: string; body: string } {
  const name = businessName.trim() || 'ملف المزوّد';
  switch (status) {
    case ProviderStatus.ACTIVE:
      return {
        title: 'تم اعتماد حساب المزوّد',
        body: `أصبح ${name} نشطًا ويمكنك الآن إدارة الخدمات والطلبات.`,
      };
    case ProviderStatus.NEEDS_CHANGES:
      return {
        title: 'مطلوب تعديل ملف المزوّد',
        body:
          reviewNote ??
          `راجع بيانات ${name} وحدّثها وفق ملاحظات فريق أعرست.`,
      };
    case ProviderStatus.REJECTED:
      return {
        title: 'لم يُعتمد طلب المزوّد',
        body:
          reviewNote ??
          `راجع حالة ${name} قبل تحديث الملف أو التواصل مع الدعم.`,
      };
    case ProviderStatus.SUSPENDED:
      return {
        title: 'تم إيقاف حساب المزوّد',
        body:
          reviewNote ??
          `توقفت عمليات ${name} مؤقتًا حتى تعيد الإدارة تفعيل الحساب.`,
      };
    case ProviderStatus.PENDING:
      return {
        title: 'طلب المزوّد قيد المراجعة',
        body: `يجري فريق أعرست مراجعة بيانات ${name}.`,
      };
  }
}
