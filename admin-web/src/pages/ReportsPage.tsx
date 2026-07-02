import { useEffect, useState } from 'react';
import { AdminStats, getStats } from '../api/admin';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { PageHeader } from '../components/PageHeader';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';

export function ReportsPage() {
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      setStats(await getStats());
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'تعذر تحميل تقرير الحالة.',
      );
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  if (isLoading) return <LoadingState title="جاري تحميل تقرير الحالة" />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!stats) {
    return (
      <EmptyState
        title="لا توجد إحصاءات"
        message="لم يرجع endpoint الإحصاءات بيانات قابلة للعرض."
        tone="api"
      />
    );
  }

  const totalProviderReviews =
    stats.pendingProviders +
    stats.approvedProviders +
    stats.rejectedProviders +
    stats.needsChangesProviders +
    stats.suspendedProviders;
  const activeProviderShare = percent(
    stats.approvedProviders,
    totalProviderReviews,
  );
  const pendingProviderShare = percent(
    stats.pendingProviders + stats.needsChangesProviders,
    totalProviderReviews,
  );

  const reportRows = [
    {
      section: 'الحسابات',
      metric: 'إجمالي المستخدمين',
      value: stats.totalUsers,
      note: 'عدد آمن من Admin stats بدون بيانات شخصية تفصيلية.',
    },
    {
      section: 'الموردون',
      metric: 'إجمالي الموردين',
      value: stats.totalProviders,
      note: 'يشمل كل حالات الموردين في مصدر الإدارة.',
    },
    {
      section: 'الموردون',
      metric: 'موردون نشطون',
      value: stats.approvedProviders,
      note: `${activeProviderShare} من حالات مراجعة الموردين المحسوبة.`,
    },
    {
      section: 'الموردون',
      metric: 'طلبات تحتاج مراجعة',
      value: stats.pendingProviders + stats.needsChangesProviders,
      note: `${pendingProviderShare} بين قيد المراجعة ويحتاج تعديل.`,
    },
    {
      section: 'التخطيط',
      metric: 'خطط الزواج',
      value: stats.totalWeddingPlans,
      note: 'عداد عام فقط، لا يعرض تفاصيل مالية أو خصوصية خطط.',
    },
    {
      section: 'التخطيط',
      metric: 'طلبات العروض',
      value: stats.totalQuoteRequests,
      note: 'طلبات غير ملزمة ولا تعني حجزا مؤكدا أو دفعا.',
    },
    {
      section: 'الكتالوج',
      metric: 'المدن',
      value: stats.totalCities,
      note: 'مرجع إدارة المدن اليمنية.',
    },
    {
      section: 'الكتالوج',
      metric: 'الفئات',
      value: stats.totalProviderCategories,
      note: 'مرجع فئات الموردين والخدمات.',
    },
  ];

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="التقارير"
        icon="%"
        title="تقرير حالة إداري محدود"
        description="لقطة قراءة من إحصاءات الإدارة المتاحة حاليا من مصدر API فعلي."
        meta={
          <>
            <span>مصدر واحد: Admin stats</span>
            <StatusBadge status="OPEN" />
          </>
        }
      />

      <div className="stats-grid">
        <StatCard title="المستخدمون" value={stats.totalUsers} tone="gold" />
        <StatCard title="الموردون" value={stats.totalProviders} tone="info" />
        <StatCard
          title="طلبات مراجعة"
          value={stats.pendingProviders + stats.needsChangesProviders}
          tone="warning"
        />
        <StatCard
          title="طلبات العروض"
          value={stats.totalQuoteRequests}
          tone="success"
        />
        <StatCard
          title="خطط الزواج"
          value={stats.totalWeddingPlans}
          tone="gold"
        />
      </div>

      <SectionCard
        title="مؤشرات المصدر الحالي"
        subtitle="هذه أرقام إجمالية مباشرة من /admin/dashboard/stats وليست تقريرا زمنيا."
      >
        <DataTable
          columns={['القسم', 'المؤشر', 'القيمة', 'ملاحظة المصدر']}
          minWidth={960}
        >
          {reportRows.map((row) => (
            <tr key={`${row.section}-${row.metric}`}>
              <td>{row.section}</td>
              <td>
                <strong>{row.metric}</strong>
              </td>
              <td>{row.value}</td>
              <td>
                <span className="table-subtle">{row.note}</span>
              </td>
            </tr>
          ))}
        </DataTable>
      </SectionCard>

      <SectionCard
        title="توزيع مراجعة الموردين"
        subtitle="التوزيع من عدادات حالة الموردين الموجودة في الإحصاءات الإدارية."
      >
        <DataTable columns={['الحالة', 'العدد', 'النسبة']} minWidth={720} dense>
          <tr>
            <td>نشط</td>
            <td>{stats.approvedProviders}</td>
            <td>{percent(stats.approvedProviders, totalProviderReviews)}</td>
          </tr>
          <tr>
            <td>قيد المراجعة</td>
            <td>{stats.pendingProviders}</td>
            <td>{percent(stats.pendingProviders, totalProviderReviews)}</td>
          </tr>
          <tr>
            <td>يحتاج تعديل</td>
            <td>{stats.needsChangesProviders}</td>
            <td>{percent(stats.needsChangesProviders, totalProviderReviews)}</td>
          </tr>
          <tr>
            <td>مرفوض</td>
            <td>{stats.rejectedProviders}</td>
            <td>{percent(stats.rejectedProviders, totalProviderReviews)}</td>
          </tr>
          <tr>
            <td>موقوف</td>
            <td>{stats.suspendedProviders}</td>
            <td>{percent(stats.suspendedProviders, totalProviderReviews)}</td>
          </tr>
        </DataTable>
      </SectionCard>
    </section>
  );
}

function percent(value: number, total: number) {
  if (!total) return '0%';
  return `${Math.round((value / total) * 100)}%`;
}
