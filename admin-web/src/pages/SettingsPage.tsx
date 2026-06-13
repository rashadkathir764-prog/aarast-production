import { DetailField } from '../components/DetailField';
import { EmptyState } from '../components/EmptyState';
import { PageHeader } from '../components/PageHeader';
import { SectionCard } from '../components/SectionCard';
import { StatusBadge } from '../components/StatusBadge';

export function SettingsPage() {
  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="التحكم"
        icon="⚙"
        title="الإعدادات العامة"
        description="إعدادات المنصة تعرض كواجهة جاهزة فقط إلى أن يتوفر API حفظ إداري."
        meta={<StatusBadge status="API_REQUIRED" />}
      />

      <SectionCard>
        <EmptyState
          title="هذه الوحدة تحتاج API خلفي قبل التفعيل"
          message="لا يوجد endpoint إداري لحفظ إعدادات المنصة حاليا، لذلك تظهر الصفحة بوضع قراءة فقط."
          tone="api"
        />
      </SectionCard>

      <div className="settings-grid">
        <SectionCard title="بيانات المنصة" subtitle="قراءة فقط إلى حين الربط.">
          <div className="details-grid">
            <DetailField label="اسم المنصة">أعرست</DetailField>
            <DetailField label="رقم الدعم">بانتظار API</DetailField>
            <DetailField label="المدن الافتراضية">تدار من صفحة المدن</DetailField>
            <DetailField label="نسبة العمولة لاحقا">مؤجلة خارج MVP</DetailField>
          </div>
        </SectionCard>

        <SectionCard title="حالة التشغيل" subtitle="لا توجد أزرار حفظ وهمية.">
          <div className="details-grid">
            <DetailField label="حالة التسجيل">بانتظار API</DetailField>
            <DetailField label="وضع الصيانة">بانتظار API</DetailField>
            <DetailField label="إعدادات OTP">WhatsApp / Email لاحقا</DetailField>
            <DetailField label="حالة الصفحة">قراءة فقط</DetailField>
          </div>
        </SectionCard>
      </div>
    </section>
  );
}
