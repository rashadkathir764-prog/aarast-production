import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { getReviews, hideReview, ProviderReview, updateReviewStatus } from './api';
import { getProviders, type ProviderApplication } from '../providers/api';
import { ActionButton } from '../../design_system/ActionButton';
import { DataTable } from '../../design_system/DataTable';
import { EmptyState } from '../../design_system/EmptyState';
import { ErrorState } from '../../design_system/ErrorState';
import { FilterSelect } from '../../design_system/FilterSelect';
import { LoadingState } from '../../design_system/LoadingState';
import { PageHeader } from '../../design_system/PageHeader';
import { Pagination } from '../../design_system/Pagination';
import { SearchInput } from '../../design_system/SearchInput';
import { SectionCard } from '../../design_system/SectionCard';
import { StatCard } from '../../design_system/StatCard';
import { StatusBadge, statusLabel } from '../../design_system/StatusBadge';
import { TableToolbar } from '../../design_system/TableToolbar';
import { Can } from '../auth/api';
import { AdminPermission } from '../auth/api';

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
  const [providerSearch, setProviderSearch] = useState('');
  const [providerSearchQuery, setProviderSearchQuery] = useState('');
  const [status, setStatus] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [pagination, setPagination] = useState({
    page: 1,
    limit: 20,
    total: 0,
    totalPages: 1,
  });
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const [reviewPage, providerPage] = await Promise.all([
        getReviews({ search, providerId, status, page, limit: 20 }),
        getProviders({ search: providerSearchQuery, page: 1, limit: 20 }),
      ]);
      if (page > reviewPage.totalPages) {
        setPage(reviewPage.totalPages);
        return;
      }
      setReviews(reviewPage.items);
      setPagination({
        page: reviewPage.page,
        limit: reviewPage.limit,
        total: reviewPage.total,
        totalPages: reviewPage.totalPages,
      });
      setProviders(providerPage.items);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل التقييمات.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [providerId, status, page, providerSearchQuery]);

  function submitSearch() {
    if (page === 1) void load();
    else setPage(1);
  }

  async function setReviewStatus(review: ProviderReview, nextStatus: string) {
    setError(null);
    try {
      await updateReviewStatus(review.id, nextStatus);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحديث حالة التقييم.');
    }
  }

  async function hide(review: ProviderReview) {
    setError(null);
    try {
      await hideReview(review.id);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر إخفاء التقييم.');
    }
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
        meta={<span>{pagination.total} تقييم مطابق</span>}
      />

      <div className="stats-grid">
        <StatCard title="كل النتائج" value={pagination.total} tone="gold" />
        <StatCard title="منشورة في الصفحة" value={publishedCount} tone="success" />
        <StatCard title="قيد المراجعة في الصفحة" value={pendingCount} tone="warning" />
        <StatCard title="مخفية في الصفحة" value={hiddenCount} tone="danger" />
        <StatCard title="متوسط الصفحة" value={averageRating} tone="info" />
      </div>

      <SectionCard className="filters-card">
        <TableToolbar>
          <SearchInput
            label="بحث في التقييمات"
            value={search}
            onChange={setSearch}
            onSubmit={submitSearch}
            placeholder="بحث بالعميل أو المورد أو التعليق"
          />
          <SearchInput
            label="بحث عن مورد للتصفية"
            value={providerSearch}
            onChange={setProviderSearch}
            onSubmit={() => {
              setProviderSearchQuery(providerSearch);
              setProviderId('');
              setPage(1);
            }}
            placeholder="بحث المورد للاختيار"
          />
          <FilterSelect
            label="الحالة"
            value={status}
            onChange={(value) => {
              setStatus(value);
              setPage(1);
            }}
            options={statuses}
          />
          <FilterSelect
            label="المورد"
            value={providerId}
            onChange={(value) => {
              setProviderId(value);
              setPage(1);
            }}
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
            label="قائمة تقييمات الموردين"
            columns={['العميل', 'المورد', 'النجوم', 'التعليق', 'الحالة', 'التاريخ', 'إجراءات']}
            minWidth={1100}
          >
            {reviews.map((review) => (
              <tr key={review.id}>
                <td>
                  <strong>{review.user.name}</strong>
                  <span className="table-subtle">بيانات الاتصال خاصة</span>
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
                  <Can permission={AdminPermission.REVIEWS_WRITE}>
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
                  </Can>
                </td>
              </tr>
            ))}
          </DataTable>
        )}
        <Pagination
          page={pagination.page}
          limit={pagination.limit}
          total={pagination.total}
          totalPages={pagination.totalPages}
          onPageChange={setPage}
        />
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
