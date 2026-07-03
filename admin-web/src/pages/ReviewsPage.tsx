import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  getProviders,
  getReviews,
  hideReview,
  ProviderApplication,
  ProviderReview,
  updateReviewStatus,
} from '../api/admin';
import { ActionButton } from '../components/ActionButton';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { FilterSelect } from '../components/FilterSelect';
import { LoadingState } from '../components/LoadingState';
import { PageHeader } from '../components/PageHeader';
import { SearchInput } from '../components/SearchInput';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge, statusLabel } from '../components/StatusBadge';
import { TableToolbar } from '../components/TableToolbar';

const statuses = [
  { value: '', label: 'كل الحالات' },
  { value: 'PUBLISHED', label: 'منشورة' },
  { value: 'PENDING', label: 'قيد المراجعة' },
  { value: 'HIDDEN', label: 'مخفية' },
];

export function ReviewsPage() {
  const [providers, setProviders] = useState<ProviderApplication[]>([]);
  const [reviews, setReviews] = useState<ProviderReview[]>([]);
  const [providerId, setProviderId] = useState('');
  const [status, setStatus] = useState('');
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const [reviewPage, providerPage] = await Promise.all([
        getReviews({ search, providerId, status, limit: 100 }),
        getProviders({ limit: 100 }),
      ]);
      setReviews(reviewPage.items);
      setProviders(providerPage.items);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل التقييمات.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [providerId, status]);

  async function setReviewStatus(review: ProviderReview, nextStatus: string) {
    await updateReviewStatus(review.id, nextStatus);
    await load();
  }

  async function hide(review: ProviderReview) {
    await hideReview(review.id);
    await load();
  }

  if (isLoading) return <LoadingState title="جاري تحميل التقييمات" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  const publishedCount = reviews.filter((review) => review.status === 'PUBLISHED').length;
  const hiddenCount = reviews.filter((review) => review.status === 'HIDDEN').length;
  const pendingCount = reviews.filter((review) => review.status === 'PENDING').length;
  const averageRating =
    reviews.length === 0
      ? '0.0'
      : (reviews.reduce((total, review) => total + review.rating, 0) / reviews.length).toFixed(1);

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="إدارة التقييمات"
        icon="☆"
        title="رقابة تقييمات الموردين"
        description="إدارة حقيقية من /admin/reviews: عرض كل الحالات، نشر، إخفاء، وإعادة احتساب تقييم المورد."
        meta={<span>{reviews.length} تقييم معروض</span>}
      />

      <div className="stats-grid">
        <StatCard title="التقييمات" value={reviews.length} tone="gold" />
        <StatCard title="منشورة" value={publishedCount} tone="success" />
        <StatCard title="قيد المراجعة" value={pendingCount} tone="warning" />
        <StatCard title="مخفية" value={hiddenCount} tone="danger" />
        <StatCard title="متوسط النجوم" value={averageRating} tone="info" />
      </div>

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            value={search}
            onChange={setSearch}
            onSubmit={load}
            placeholder="بحث بالعميل أو المورد أو التعليق"
          />
          <FilterSelect label="الحالة" value={status} onChange={setStatus} options={statuses} />
          <FilterSelect
            label="المورد"
            value={providerId}
            onChange={setProviderId}
            options={[
              { value: '', label: 'كل الموردين' },
              ...providers.map((provider) => ({
                value: provider.id,
                label: provider.businessName,
              })),
            ]}
          />
        </TableToolbar>
      </SectionCard>

      <SectionCard title="قائمة التقييمات" subtitle="لا يوجد مسح محدود لأول 30 مورد؛ المصدر إداري مباشر.">
        {reviews.length === 0 ? (
          <EmptyState title="لا توجد تقييمات مطابقة" message="غير الفلاتر أو ابحث بكلمة أخرى." tone="api" />
        ) : (
          <DataTable
            columns={['العميل', 'المورد', 'النجوم', 'التعليق', 'الحالة', 'التاريخ', 'إجراءات']}
            minWidth={1100}
          >
            {reviews.map((review) => (
              <tr key={review.id}>
                <td>
                  <strong>{review.user.name}</strong>
                  <span className="table-subtle" dir="ltr">
                    {review.user.phone ?? 'لا يوجد رقم'}
                  </span>
                </td>
                <td>
                  {review.provider ? (
                    <Link className="table-strong-link" to={`/providers/${review.provider.id}`}>
                      {review.provider.businessName}
                    </Link>
                  ) : (
                    review.providerId
                  )}
                  <span className="table-subtle">{review.provider?.city?.nameAr ?? ''}</span>
                </td>
                <td>{formatStars(review.rating)}</td>
                <td>{review.comment?.trim() || <span className="table-subtle">بدون تعليق</span>}</td>
                <td>
                  <StatusBadge status={review.status} />
                </td>
                <td>{formatDate(review.createdAt)}</td>
                <td className="actions-cell">
                  {review.status !== 'PUBLISHED' ? (
                    <ActionButton
                      tone="ghost"
                      size="small"
                      onClick={() => setReviewStatus(review, 'PUBLISHED')}
                    >
                      نشر
                    </ActionButton>
                  ) : null}
                  {review.status !== 'PENDING' ? (
                    <ActionButton
                      tone="ghost"
                      size="small"
                      onClick={() => setReviewStatus(review, 'PENDING')}
                    >
                      مراجعة
                    </ActionButton>
                  ) : null}
                  {review.status !== 'HIDDEN' ? (
                    <ActionButton tone="danger" size="small" onClick={() => hide(review)}>
                      إخفاء
                    </ActionButton>
                  ) : null}
                </td>
              </tr>
            ))}
          </DataTable>
        )}
      </SectionCard>
    </section>
  );
}

function formatStars(rating: number) {
  const safeRating = Math.max(0, Math.min(5, Math.round(rating)));
  return `${'★'.repeat(safeRating)}${'☆'.repeat(5 - safeRating)} (${rating})`;
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('ar-YE', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}
