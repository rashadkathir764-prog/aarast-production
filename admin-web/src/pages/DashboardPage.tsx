import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  AdminStats,
  getProviderApplications,
  getStats,
  ProviderApplication,
} from '../api/admin';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';

export function DashboardPage() {
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [pending, setPending] = useState<ProviderApplication[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const [statsResult, pendingResult] = await Promise.all([
        getStats(),
        getProviderApplications({ status: 'PENDING', limit: 5 }),
      ]);
      setStats(statsResult);
      setPending(pendingResult.items);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل لوحة التحكم.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!stats) return <EmptyState title="لا توجد بيانات" message="لم تصل إحصاءات بعد." />;

  return (
    <section className="page-stack">
      <div className="page-heading">
        <div>
          <p>نظرة عامة</p>
          <h2>متابعة طلبات الموردين واعتماد الظهور العام</h2>
        </div>
        <Link className="button" to="/providers/applications">
          مراجعة الطلبات
        </Link>
      </div>

      <div className="stats-grid">
        <StatCard title="إجمالي المستخدمين" value={stats.totalUsers} />
        <StatCard title="إجمالي الموردين" value={stats.totalProviders} />
        <StatCard title="قيد المراجعة" value={stats.pendingProviders} />
        <StatCard title="موردون مقبولون" value={stats.approvedProviders} />
        <StatCard title="موردون مرفوضون" value={stats.rejectedProviders} />
        <StatCard title="يحتاج تعديل" value={stats.needsChangesProviders} />
        <StatCard title="موردون موقوفون" value={stats.suspendedProviders} />
        <StatCard title="طلبات عروض الأسعار" value={stats.totalQuoteRequests} />
        <StatCard title="خطط الزفاف" value={stats.totalWeddingPlans} />
        <StatCard title="المدن" value={stats.totalCities} />
        <StatCard title="الفئات" value={stats.totalProviderCategories} />
      </div>

      <section className="panel">
        <div className="panel-title">
          <h3>أحدث طلبات قيد المراجعة</h3>
          <Link to="/providers/applications">عرض الكل</Link>
        </div>
        {pending.length === 0 ? (
          <EmptyState
            title="لا توجد طلبات معلقة"
            message="طلبات الموردين الجديدة ستظهر هنا للمراجعة."
          />
        ) : (
          <div className="compact-list">
            {pending.map((provider) => (
              <Link
                key={provider.id}
                to={`/providers/applications/${provider.id}`}
                className="compact-row"
              >
                <div>
                  <strong>{provider.businessName}</strong>
                  <span>
                    {provider.user?.name ?? provider.ownerName ?? 'حساب غير محدد'} ·{' '}
                    {provider.city?.nameAr ?? 'مدينة غير محددة'}
                  </span>
                </div>
                <StatusBadge status={provider.status} />
              </Link>
            ))}
          </div>
        )}
      </section>
    </section>
  );
}
