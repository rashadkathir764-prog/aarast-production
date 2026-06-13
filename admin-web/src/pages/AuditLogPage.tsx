import { BackendRequiredPage } from './BackendRequiredPage';

export function AuditLogPage() {
  return (
    <BackendRequiredPage
      eyebrow="الأمان"
      icon="◷"
      title="سجل العمليات"
      description="سجل داخلي للمساءلة عند توفر API يتتبع تغييرات الإدارة."
      message="سجل العمليات يحتاج API لتتبع تغييرات الإدارة."
      expectedFields={[
        'العملية',
        'المسؤول',
        'الهدف',
        'التاريخ',
        'IP أو الجهاز إن توفر',
        'تفاصيل التغيير',
      ]}
    />
  );
}
