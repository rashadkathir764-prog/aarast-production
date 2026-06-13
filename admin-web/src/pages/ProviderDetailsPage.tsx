import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { getProvider, ProviderApplication } from '../api/admin';
import { ActionLink } from '../components/ActionButton';
import { DetailField } from '../components/DetailField';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { PageHeader } from '../components/PageHeader';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';
import { Timeline } from '../components/Timeline';
import {
  formatDate,
  ProviderActions,
  ProviderSummaryCard,
} from './providerHelpers';

export function ProviderDetailsPage() {
  const { id } = useParams();
  const [provider, setProvider] = useState<ProviderApplication | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    if (!id) return;
    setIsLoading(true);
    setError(null);
    try {
      setProvider(await getProvider(id));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل المورد.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [id]);

  if (isLoading) return <LoadingState title="جاري تحميل ملف المورد" />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!provider) {
    return (
      <EmptyState
        title="المورد غير موجود"
        message="لا يمكن عرض هذا المورد."
      />
    );
  }

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="إدارة مورد"
        icon="◉"
        title={provider.businessName}
        description="ملف إداري لمتابعة حالة المورد وجودة بياناته وخدماته."
        actions={
          <ActionLink tone="ghost" to="/providers">
            العودة للموردين
          </ActionLink>
        }
        meta={
          <>
            <StatusBadge status={provider.status} />
            <span>آخر تحديث {formatDate(provider.updatedAt)}</span>
          </>
        }
      />

      <ProviderSummaryCard provider={provider} />

      <div className="stats-grid">
        <StatCard title="الخدمات" value={provider.servicesCount} tone="info" />
        <StatCard title="الباقات" value={provider.packagesCount} tone="gold" />
        <StatCard
          title="طلبات العروض"
          value={provider.quoteRequestsCount}
          tone="warning"
        />
        <StatCard
          title="التقييمات"
          value={provider.reviewsCount}
          tone="success"
          hint={`متوسط ${provider.ratingAverage}`}
        />
      </div>

      <SectionCard
        title="حالة الظهور العام"
        subtitle="إجراءات الإدارة المباشرة على حالة المورد."
        actions={<StatusBadge status={provider.status} />}
      >
        <ProviderActions provider={provider} onChanged={load} />
        {provider.reviewNote ? (
          <p className="review-note">ملاحظة الإدارة: {provider.reviewNote}</p>
        ) : null}
      </SectionCard>

      <div className="two-column">
        <SectionCard title="بيانات عامة" subtitle="معلومات منشورة أو إدارية آمنة">
          <div className="details-grid">
            <DetailField label="الهاتف">
              <span dir="ltr">{provider.phone}</span>
            </DetailField>
            <DetailField label="واتساب">
              <span dir="ltr">{provider.whatsapp ?? 'غير محدد'}</span>
            </DetailField>
            <DetailField label="المدينة">
              {provider.city?.nameAr ?? 'غير محدد'}
            </DetailField>
            <DetailField label="الفئة">
              {provider.primaryCategory?.nameAr ?? 'غير محدد'}
            </DetailField>
            <DetailField label="العنوان">
              {provider.address ?? 'غير محدد'}
            </DetailField>
            <DetailField label="تاريخ الإنشاء">
              {formatDate(provider.createdAt)}
            </DetailField>
          </div>
          <p className="muted-text">{provider.description ?? 'لا يوجد وصف.'}</p>
        </SectionCard>

        <SectionCard title="سجل الحالة" subtitle="آخر قرار إداري مسجل.">
          <Timeline
            items={[
              {
                title: 'تم إنشاء ملف المورد',
                caption: formatDate(provider.createdAt),
                tone: 'gold',
              },
              {
                title: provider.reviewedAt ? 'آخر مراجعة إدارية' : 'لا توجد مراجعة بعد',
                caption: provider.reviewedAt
                  ? formatDate(provider.reviewedAt)
                  : 'بانتظار إجراء الإدارة',
                tone: provider.reviewedAt ? 'success' : 'warning',
              },
            ]}
          />
        </SectionCard>
      </div>

      <SectionCard title="الخدمات" subtitle={`${provider.servicesCount} خدمة مسجلة.`}>
        {provider.services?.length ? (
          <div className="cards-grid">
            {provider.services.map((service) => (
              <article className="mini-card" key={service.id}>
                <strong>{service.title}</strong>
                <span>{service.category?.nameAr ?? 'فئة غير محددة'}</span>
                <p>{service.description ?? 'لا يوجد وصف.'}</p>
              </article>
            ))}
          </div>
        ) : (
          <EmptyState
            title="لا توجد خدمات"
            message="لم يضف المورد خدمات بعد."
          />
        )}
      </SectionCard>
    </section>
  );
}
