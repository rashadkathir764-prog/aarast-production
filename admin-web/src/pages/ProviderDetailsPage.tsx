import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { getProvider, ProviderApplication } from '../api/admin';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { StatusBadge } from '../components/StatusBadge';
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

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!provider) {
    return <EmptyState title="المورد غير موجود" message="لا يمكن عرض هذا المورد." />;
  }

  return (
    <section className="page-stack">
      <div className="page-heading">
        <div>
          <p>إدارة مورد</p>
          <h2>{provider.businessName}</h2>
        </div>
        <Link className="button ghost" to="/providers">
          العودة للموردين
        </Link>
      </div>

      <ProviderSummaryCard provider={provider} />

      <section className="panel">
        <div className="panel-title">
          <h3>حالة الظهور العام</h3>
          <StatusBadge status={provider.status} />
        </div>
        <ProviderActions provider={provider} onChanged={load} />
        {provider.reviewNote ? (
          <p className="review-note">ملاحظة الإدارة: {provider.reviewNote}</p>
        ) : null}
      </section>

      <div className="stats-grid compact">
        <article className="stat-card">
          <p>الخدمات</p>
          <strong>{provider.servicesCount}</strong>
        </article>
        <article className="stat-card">
          <p>الباقات</p>
          <strong>{provider.packagesCount}</strong>
        </article>
        <article className="stat-card">
          <p>طلبات عروض الأسعار</p>
          <strong>{provider.quoteRequestsCount}</strong>
        </article>
        <article className="stat-card">
          <p>التقييمات</p>
          <strong>{provider.reviewsCount}</strong>
        </article>
      </div>

      <section className="panel">
        <h3>بيانات عامة</h3>
        <dl className="details-list">
          <dt>الهاتف</dt>
          <dd dir="ltr">{provider.phone}</dd>
          <dt>المدينة</dt>
          <dd>{provider.city?.nameAr ?? 'غير محدد'}</dd>
          <dt>الفئة</dt>
          <dd>{provider.primaryCategory?.nameAr ?? 'غير محدد'}</dd>
          <dt>تاريخ الإنشاء</dt>
          <dd>{formatDate(provider.createdAt)}</dd>
        </dl>
      </section>
    </section>
  );
}
