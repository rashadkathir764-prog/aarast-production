import { BackendRequiredPage } from './BackendRequiredPage';

export function ServicesPage() {
  return (
    <BackendRequiredPage
      eyebrow="الكتالوج"
      icon="⌁"
      title="خدمات الموردين"
      description="مراجعة خدمات الموردين تحتاج endpoint إداري مخصص قبل عرض بيانات تشغيلية."
      message="هذه الوحدة تحتاج API خلفي قبل التفعيل."
      expectedFields={[
        'الخدمة',
        'المورد',
        'السعر',
        'المدينة',
        'الفئة',
        'حالة الصور',
        'الحالة',
        'إجراءات المراجعة',
      ]}
    />
  );
}
