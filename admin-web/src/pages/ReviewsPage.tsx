import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  getProviderReferences,
  getProviderReviewReferences,
  ProviderReference,
  ProviderReview,
} from '../api/admin';
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

type ReviewRow = ProviderReview & {
  provider: ProviderReference;
};

const REVIEW_PROVIDER_SCAN_LIMIT = 30;

export function ReviewsPage() {
  const [providers, setProviders] = useState<ProviderReference[]>([]);
  const [reviews, setReviews] = useState<ReviewRow[]>([]);
  const [providerId, setProviderId] = useState('');
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const providerPage = await getProviderReferences({
        limit: REVIEW_PROVIDER_SCAN_LIMIT,
      });
      const activeProviders = providerPage.items;
      const providersToRead = providerId
        ? activeProviders.filter((provider) => provider.id === providerId)
        : activeProviders;

      const reviewGroups = await Promise.all(
        providersToRead.map(async (provider) => {
          const providerReviews = await getProviderReviewReferences(provider.id);
          return providerReviews.map((review) => ({ ...review, provider }));
        }),
      );

      setProviders(activeProviders);
      setReviews(reviewGroups.flat());
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : 'تعذر تحميل التقييمات المنشورة.',
      );
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [providerId]);

  if (isLoading) return <LoadingState title="جاري تحميل التقييمات المنشورة" />;
  if (error) return <ErrorState message={error} onRetry={load} />;

  const filteredReviews = reviews.filter((review) => {
    if (!search.trim()) return true;
    const query = search.trim().toLowerCase();
    return [
      review.user.name,
      review.user.phone ?? '',
      review.provider.businessName,
      review.comment ?? '',
      statusLabel(review.status),
    ]
      .join(' ')
      .toLowerCase()
      .includes(query);
  });

  const ratedReviews = filteredReviews.filter((review) =>
    Number.isFinite(review.rating),
  );
  const averageRating =
    ratedReviews.length === 0
      ? '0.0'
      : (
          ratedReviews.reduce((total, review) => total + review.rating, 0) /
          ratedReviews.length
        ).toFixed(1);
  const commentedCount = filteredReviews.filter((review) =>
    review.comment?.trim(),
  ).length;
  const reviewedProvidersCount = new Set(
    filteredReviews.map((review) => review.providerId),
  ).size;

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="الرقابة"
        icon="☆"
        title="التقييمات المنشورة"
        description="عرض مرجعي للتقييمات المنشورة على صفحات الموردين النشطين من مصدر API فعلي."
        meta={
          <>
            <span>{filteredReviews.length} تقييم منشور</span>
            <StatusBadge status="OPEN" />
          </>
        }
      />

      <div className="stats-grid">
        <StatCard title="التقييمات" value={filteredReviews.length} tone="gold" />
        <StatCard title="الموردون" value={reviewedProvidersCount} tone="info" />
        <StatCard title="متوسط النجوم" value={averageRating} tone="success" />
        <StatCard title="بتعليق" value={commentedCount} tone="warning" />
      </div>

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            value={search}
            onChange={setSearch}
            onSubmit={load}
            placeholder="بحث بالعميل أو المورد أو التعليق"
          />
          <FilterSelect
            label="المورد"
            value={providerId}
            onChange={setProviderId}
            options={[
              { value: '', label: 'كل الموردين النشطين' },
              ...providers.map((provider) => ({
                value: provider.id,
                label: provider.businessName,
              })),
            ]}
          />
        </TableToolbar>
      </SectionCard>

      <SectionCard
        title="قائمة التقييمات"
        subtitle="البيانات من endpoint عام يعرض التقييمات المنشورة فقط للموردين النشطين؛ التقييمات المعلقة أو المخفية لا تظهر هنا."
      >
        {filteredReviews.length === 0 ? (
          <EmptyState
            title="لا توجد تقييمات منشورة مطابقة"
            message="غياب النتائج يعني أن المصدر الحالي لم يرجع تقييمات منشورة ضمن الموردين النشطين المقروءين، وليس أن اللوحة أنشأت بيانات بديلة."
            tone="api"
          />
        ) : (
          <DataTable
            columns={[
              'العميل',
              'المورد',
              'النجوم',
              'التعليق',
              'الحالة',
              'تاريخ النشر',
            ]}
            minWidth={980}
          >
            {filteredReviews.map((review) => (
              <tr key={review.id}>
                <td>
                  <strong>{review.user.name}</strong>
                  <span className="table-subtle" dir="ltr">
                    {review.user.phone ?? 'لا يوجد رقم'}
                  </span>
                </td>
                <td>
                  <Link
                    className="table-strong-link"
                    to={`/providers/${review.provider.id}`}
                  >
                    {review.provider.businessName}
                  </Link>
                  <span className="table-subtle">
                    {review.provider.city?.nameAr ?? 'مدينة غير محددة'}
                  </span>
                </td>
                <td>{formatStars(review.rating)}</td>
                <td>
                  {review.comment?.trim() ? (
                    review.comment
                  ) : (
                    <span className="table-subtle">بدون تعليق نصي</span>
                  )}
                </td>
                <td>
                  <StatusBadge status={review.status} />
                </td>
                <td>{formatDate(review.createdAt)}</td>
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
