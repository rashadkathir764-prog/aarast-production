import { BackendRequiredPage } from './BackendRequiredPage';

export function ReviewsPage() {
  return (
    <BackendRequiredPage
      eyebrow="الرقابة"
      icon="☆"
      title="التقييمات والمراجعات"
      description="مراقبة مراجعات العملاء تحتاج API إداري حتى لا يتم عرض بيانات وهمية."
      message="هذه الوحدة تحتاج API خلفي قبل التفعيل."
      expectedFields={[
        'العميل',
        'المورد',
        'النجوم',
        'التعليق',
        'الحالة',
        'اعتماد',
        'إخفاء',
        'حذف آمن',
      ]}
    />
  );
}
