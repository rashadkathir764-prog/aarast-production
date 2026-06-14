import { ReactNode } from 'react';
import { DetailField } from '../components/DetailField';
import { EmptyState } from '../components/EmptyState';
import { PageHeader } from '../components/PageHeader';
import { SectionCard } from '../components/SectionCard';
import { StatusBadge } from '../components/StatusBadge';

type BackendRequiredPageProps = {
  eyebrow: string;
  icon: string;
  title: string;
  description: string;
  message: string;
  expectedFields: string[];
  children?: ReactNode;
};

export function BackendRequiredPage({
  eyebrow,
  icon,
  title,
  description,
  message,
  expectedFields,
  children,
}: BackendRequiredPageProps) {
  return (
    <section className="page-stack">
      <PageHeader
        eyebrow={eyebrow}
        icon={icon}
        title={title}
        description={description}
        meta={<StatusBadge status="API_REQUIRED" />}
      />

      <SectionCard>
        <EmptyState title="هذه الوحدة تحتاج API خلفي قبل التفعيل" message={message} tone="api" />
      </SectionCard>

      <div className="two-column">
        <SectionCard
          title="حقول مطلوبة عند ربط API"
          subtitle="هذه ليست بيانات تشغيلية، بل عقد واجهة جاهز للربط لاحقا."
        >
          <div className="requirement-list">
            {expectedFields.map((field) => (
              <DetailField label="حقل" key={field}>
                {field}
              </DetailField>
            ))}
          </div>
        </SectionCard>
        <SectionCard
          title="حالة الصفحة"
          subtitle="المسار يعمل ولا يكسر التنقل، لكنه لا يدعي وجود بيانات غير متاحة."
        >
          <div className="placeholder-panel">
            <StatusBadge status="API_REQUIRED" />
            <p>تم تجهيز الواجهة بشكل آمن بانتظار endpoint إداري واضح.</p>
          </div>
        </SectionCard>
      </div>

      {children}
    </section>
  );
}
