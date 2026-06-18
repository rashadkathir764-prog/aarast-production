import { BackendRequiredPage } from './BackendRequiredPage';

export function PaymentsPage() {
  return (
    <BackendRequiredPage
      eyebrow="النطاق المؤجل"
      icon="$"
      title="المدفوعات والفواتير غير مفعلة"
      description="لا توجد واجهة إدارة للمدفوعات في نطاق MVP الحالي، ولا يتم عرض أي حالة دفع أو فواتير وهمية."
      message="هذه الوحدة مؤجلة حتى يتم اعتماد backend حقيقي للمدفوعات. تم إبقاء المسار آمنا حتى لا يقود إلى 404."
      expectedFields={[
        'Payment admin API',
        'Invoice lifecycle',
        'Refund or dispute rules',
        'Audit trail',
      ]}
    />
  );
}

export function NotificationsPage() {
  return (
    <BackendRequiredPage
      eyebrow="قيد التجهيز"
      icon="!"
      title="إشعارات الإدارة قيد التجهيز"
      description="يوجد نظام إشعارات للمستخدمين، لكن لا يوجد endpoint إداري مستقل لإرسال أو إدارة إشعارات المنصة."
      message="تم تعطيل إجراءات الإشعارات الإدارية حتى يتوفر API واضح بدلا من محاكاة بيانات أو إرسال وهمي."
      expectedFields={[
        'Admin notification API',
        'Audience targeting',
        'Delivery status',
        'Safe send confirmation',
      ]}
    />
  );
}

export function ReportsPage() {
  return (
    <BackendRequiredPage
      eyebrow="قيد التجهيز"
      icon="%"
      title="التقارير والتحليلات قيد التجهيز"
      description="لا يوجد endpoint إداري للتقارير أو التصدير ضمن قائمة APIs المتاحة، لذلك لا يتم عرض أرقام تحليلية وهمية."
      message="صفحة التقارير محفوظة كمسار آمن، لكنها تنتظر backend حقيقي قبل التفعيل."
      expectedFields={[
        'Report summary API',
        'Date range filters',
        'Export endpoint',
        'Source-of-truth metrics',
      ]}
    />
  );
}

export function ProviderCreateUnavailablePage() {
  return (
    <BackendRequiredPage
      eyebrow="إجراء غير متاح"
      icon="+"
      title="إضافة مورد جديد غير متاحة من الإدارة"
      description="قائمة APIs المتاحة تدعم مراجعة الموردين وتفعيلهم أو تعليقهم، ولا تحتوي على POST /admin/providers لإنشاء مورد جديد."
      message="إنشاء الموردين يتم عبر طلبات الانضمام المتاحة حاليا. تم إبقاء المسار آمنا بدون إنشاء API وهمي."
      expectedFields={[
        'POST /admin/providers',
        'Provider ownership rules',
        'City and category validation',
        'Review workflow',
      ]}
    />
  );
}

export function ServiceCreateUnavailablePage() {
  return (
    <BackendRequiredPage
      eyebrow="إجراء غير متاح"
      icon="+"
      title="إضافة خدمة جديدة غير متاحة من الإدارة"
      description="لا يوجد endpoint إداري لإنشاء الخدمات ضمن قائمة APIs المتاحة، لذلك تم تعطيل مسار الإنشاء."
      message="يمكن عرض حالة صفحة الخدمات، لكن إنشاء الخدمات يحتاج backend حقيقي قبل التفعيل."
      expectedFields={[
        'POST /admin/services',
        'Provider relation',
        'Category and city validation',
        'Review and activation workflow',
      ]}
    />
  );
}
