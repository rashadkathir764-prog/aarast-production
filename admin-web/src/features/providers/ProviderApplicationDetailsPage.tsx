import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { getProviderApplication, type ProviderApplication } from './api';
import { ActionLink } from '../../design_system/ActionButton';
import { DetailField } from '../../design_system/DetailField';
import { EmptyState } from '../../design_system/EmptyState';
import { ErrorState } from '../../design_system/ErrorState';
import { LoadingState } from '../../design_system/LoadingState';
import { PageHeader } from '../../design_system/PageHeader';
import { SectionCard } from '../../design_system/SectionCard';
import { StatusBadge } from '../../design_system/StatusBadge';
import { Timeline } from '../../design_system/Timeline';
import { formatDate } from '../../platform/i18n/formatDate';
import {
  ProviderActions,
  ProviderSummaryCard,
  shortId,
} from './providerHelpers';

export function ProviderApplicationDetailsPage() {
  const { id } = useParams();
  const [provider, setProvider] = useState<ProviderApplication | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    if (!id) return;
    setIsLoading(true);
    setError(null);
    try {
      setProvider(await getProviderApplication(id));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل تفاصيل الطلب.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [id]);

  if (isLoading) return <LoadingState title="جاري تحميل ملف الطلب" />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!provider) {
    return (
      <EmptyState
        title="الطلب غير موجود"
        message="لا يمكن عرض هذا الطلب."
      />
    );
  }

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="تفاصيل طلب المورد"
        icon="□"
        title={provider.businessName}
        description="مراجعة بيانات النشاط والتواصل والخدمات قبل اعتماد الظهور العام."
        actions={
          <ActionLink className="button--ghost" tone="ghost" to="/providers/applications">
            العودة للطلبات
          </ActionLink>
        }
        meta={
          <>
            <StatusBadge status={provider.status} />
            <span>{shortId(provider.id)}</span>
            <span>{formatDate(provider.createdAt)}</span>
          </>
        }
      />

      <ProviderSummaryCard provider={provider} />

      <SectionCard
        title="إجراءات المراجعة"
        subtitle="الرفض والإيقاف وطلب التعديل تستخدم ملاحظة واضحة قبل التنفيذ."
        actions={<StatusBadge status={provider.status} />}
      >
        <ProviderActions provider={provider} onChanged={load} />
        {provider.reviewNote ? (
          <p className="review-note">ملاحظة الإدارة: {provider.reviewNote}</p>
        ) : null}
      </SectionCard>

      <div className="two-column">
        <SectionCard title="بيانات النشاط" subtitle="معلومات العرض العام">
          <div className="details-grid">
            <DetailField label="اسم النشاط">{provider.businessName}</DetailField>
            <DetailField label="المدينة">
              {provider.city?.nameAr ?? 'غير محدد'}
            </DetailField>
            <DetailField label="الفئة">
              {provider.primaryCategory?.nameAr ?? 'غير محدد'}
            </DetailField>
            <DetailField label="الهاتف">
              <span dir="ltr">{provider.phone}</span>
            </DetailField>
            <DetailField label="واتساب">
              <span dir="ltr">{provider.whatsapp ?? 'غير محدد'}</span>
            </DetailField>
            <DetailField label="البريد">{provider.email ?? 'غير محدد'}</DetailField>
          </div>
          <p className="muted-text">{provider.description ?? 'لا يوجد وصف.'}</p>
        </SectionCard>

        <SectionCard title="صاحب الحساب" subtitle="بيانات آمنة للعرض الإداري">
          <div className="details-grid">
            <DetailField label="الاسم">
              {provider.user?.name ?? provider.ownerName ?? 'غير محدد'}
            </DetailField>
            <DetailField label="هاتف الحساب">
              <span dir="ltr">{provider.user?.phone ?? 'غير محدد'}</span>
            </DetailField>
            <DetailField label="البريد">
              {provider.user?.email ?? provider.email ?? 'غير محدد'}
            </DetailField>
            <DetailField label="الدور">
              {provider.user?.role ?? 'غير محدد'}
            </DetailField>
          </div>
        </SectionCard>
      </div>

      <div className="two-column">
        <SectionCard title="خط المراجعة" subtitle="حالة الطلب منذ الإنشاء.">
          <Timeline
            items={[
              {
                title: 'تم إنشاء الطلب',
                caption: formatDate(provider.createdAt),
                tone: 'gold',
              },
              {
                title: provider.reviewedAt ? 'تمت مراجعته' : 'بانتظار القرار',
                caption: provider.reviewedAt
                  ? formatDate(provider.reviewedAt)
                  : 'لم يتم تسجيل مراجعة بعد',
                tone: provider.reviewedAt ? 'success' : 'warning',
              },
            ]}
          />
        </SectionCard>

        <SectionCard title="المستندات والصور" subtitle="حسب ما يتيحه backend حاليا.">
          <div className="media-preview">
            {provider.logoUrl ? <img src={provider.logoUrl} alt="" /> : null}
            {provider.coverUrl ? <img src={provider.coverUrl} alt="" /> : null}
            {!provider.logoUrl && !provider.coverUrl ? (
              <EmptyState
                title="لا توجد صور مرفقة"
                message="لم يرسل المورد شعارا أو غلافا في البيانات الحالية."
              />
            ) : null}
          </div>
        </SectionCard>
      </div>

      <SectionCard
        title="الخدمات والباقات"
        subtitle="تظهر فقط عند وجود بيانات حقيقية ضمن ملف المورد."
      >
        <div className="cards-grid">
          {provider.services?.map((service) => (
            <article className="mini-card" key={service.id}>
              <strong>{service.title}</strong>
              <span>{service.category?.nameAr ?? 'فئة غير محددة'}</span>
              <p>{service.description ?? 'لا يوجد وصف.'}</p>
            </article>
          ))}
          {provider.packages?.map((providerPackage) => (
            <article className="mini-card" key={providerPackage.id}>
              <strong>{providerPackage.title}</strong>
              <span>
                {providerPackage.price ?? 'حسب الطلب'} {providerPackage.currency}
              </span>
              <p>{providerPackage.description ?? 'لا يوجد وصف.'}</p>
            </article>
          ))}
        </div>
        {!provider.services?.length && !provider.packages?.length ? (
          <EmptyState
            title="لا توجد خدمات أو باقات"
            message="لم يضف المورد خدمات أو باقات بعد."
          />
        ) : null}
      </SectionCard>
    </section>
  );
}
