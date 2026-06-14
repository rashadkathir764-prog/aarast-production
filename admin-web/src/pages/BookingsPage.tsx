import { BackendRequiredPage } from './BackendRequiredPage';

export function BookingsPage() {
  return (
    <BackendRequiredPage
      eyebrow="العمليات"
      icon="▤"
      title="الحجوزات والطلبات"
      description="إدارة الحجوزات أو طلبات التشغيل عند توفر endpoint إداري مخصص."
      message="وحدة الحجوزات تحتاج ربط API الإداري قبل التفعيل."
      expectedFields={[
        'رقم الحجز',
        'العميل',
        'المورد',
        'الخدمة',
        'التاريخ',
        'الحالة',
        'المبلغ',
        'إجراءات آمنة',
      ]}
    />
  );
}
