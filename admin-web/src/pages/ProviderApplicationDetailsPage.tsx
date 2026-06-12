import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { getProviderApplication, ProviderApplication } from '../api/admin';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { StatusBadge } from '../components/StatusBadge';
import {
  formatDate,
  ProviderActions,
  ProviderSummaryCard,
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

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!provider) {
    return <EmptyState title="الطلب غير موجود" message="لا يمكن عرض هذا الطلب." />;
  }

  return (
    <section className="page-stack">
      <div className="page-heading">
        <div>
          <p>تفاصيل طلب المورد</p>
          <h2>{provider.businessName}</h2>
        </div>
        <Link className="button ghost" to="/providers/applications">
          العودة للطلبات
        </Link>
      </div>

      <ProviderSummaryCard provider={provider} />

      <section className="panel">
        <div className="panel-title">
          <h3>إجراءات المراجعة</h3>
          <StatusBadge status={provider.status} />
        </div>
        <ProviderActions provider={provider} onChanged={load} />
        {provider.reviewNote ? (
          <p className="review-note">ملاحظة الإدارة: {provider.reviewNote}</p>
        ) : null}
      </section>

      <div className="two-column">
        <section className="panel">
          <h3>بيانات النشاط</h3>
          <dl className="details-list">
            <dt>اسم النشاط</dt>
            <dd>{provider.businessName}</dd>
            <dt>الهاتف</dt>
            <dd dir="ltr">{provider.phone}</dd>
            <dt>المدينة</dt>
            <dd>{provider.city?.nameAr ?? 'غير محدد'}</dd>
            <dt>الفئة</dt>
            <dd>{provider.primaryCategory?.nameAr ?? 'غير محدد'}</dd>
            <dt>تاريخ الطلب</dt>
            <dd>{formatDate(provider.createdAt)}</dd>
          </dl>
          <p className="muted-text">{provider.description ?? 'لا يوجد وصف.'}</p>
        </section>

        <section className="panel">
          <h3>صاحب الحساب</h3>
          <dl className="details-list">
            <dt>الاسم</dt>
            <dd>{provider.user?.name ?? provider.ownerName ?? 'غير محدد'}</dd>
            <dt>هاتف الحساب</dt>
            <dd dir="ltr">{provider.user?.phone ?? 'غير محدد'}</dd>
            <dt>البريد</dt>
            <dd>{provider.user?.email ?? provider.email ?? 'غير محدد'}</dd>
            <dt>الدور</dt>
            <dd>{provider.user?.role ?? 'غير محدد'}</dd>
          </dl>
        </section>
      </div>

      <section className="panel">
        <div className="panel-title">
          <h3>الخدمات</h3>
          <span>{provider.servicesCount}</span>
        </div>
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
          <EmptyState title="لا توجد خدمات" message="لم يضف المورد خدمات بعد." />
        )}
      </section>

      <section className="panel">
        <div className="panel-title">
          <h3>الباقات</h3>
          <span>{provider.packagesCount}</span>
        </div>
        {provider.packages?.length ? (
          <div className="cards-grid">
            {provider.packages.map((providerPackage) => (
              <article className="mini-card" key={providerPackage.id}>
                <strong>{providerPackage.title}</strong>
                <span>{providerPackage.price ?? 'حسب الطلب'} YER</span>
                <p>{providerPackage.description ?? 'لا يوجد وصف.'}</p>
              </article>
            ))}
          </div>
        ) : (
          <EmptyState title="لا توجد باقات" message="لم يضف المورد باقات بعد." />
        )}
      </section>
    </section>
  );
}
