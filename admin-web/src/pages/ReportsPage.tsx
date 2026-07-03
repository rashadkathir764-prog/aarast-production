import { useEffect, useState } from 'react';
import { AdminReport, getReportOverview } from '../api/admin';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { PageHeader } from '../components/PageHeader';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';

export function ReportsPage() {
  const [report, setReport] = useState<AdminReport | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      setReport(await getReportOverview());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل تقرير الإدارة.');
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  if (isLoading) return <LoadingState title="جاري تحميل تقرير الإدارة" />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!report) {
    return (
      <EmptyState
        title="لا توجد بيانات تقرير"
        message="لم يرجع endpoint التقارير بيانات قابلة للعرض."
        tone="api"
      />
    );
  }

  const providerReviewTotal =
    report.providers.pending +
    report.providers.active +
    report.providers.needsChanges +
    report.providers.suspended +
    report.providers.rejected;

  const rows = [
    ['المستخدمون', 'إجمالي المستخدمين', report.users.total, 'كل الحسابات المسجلة.'],
    ['المستخدمون', 'حسابات نشطة', report.users.active, 'قابلة للاستخدام.'],
    ['المستخدمون', 'حسابات معطلة', report.users.disabled, 'أوقفها الأدمن.'],
    ['الموردون', 'إجمالي الموردين', report.providers.total, 'كل ملفات الموردين.'],
    ['الموردون', 'موردون نشطون', report.providers.active, percent(report.providers.active, providerReviewTotal)],
    ['الخدمات', 'إجمالي الخدمات', report.services.total, 'من جدول ProviderService.'],
    ['الخدمات', 'خدمات نشطة', report.services.active, 'ظاهرة إذا كان المورد مؤهلا.'],
    ['التقييمات', 'إجمالي التقييمات', report.reviews.total, `متوسط ${report.reviews.averageRating}`],
    ['التقييمات', 'منشورة', report.reviews.published, 'تدخل في تقييم المورد.'],
    ['التقييمات', 'مخفية', report.reviews.hidden, 'لا تدخل في التقييم العام.'],
    ['الإشعارات', 'إجمالي الإشعارات', report.notifications.total, 'سجل إشعارات النظام.'],
    ['الإشعارات', 'غير مقروءة', report.notifications.unread, 'غير مؤرشفة وغير مقروءة.'],
    ['التخطيط', 'خطط الزواج', report.weddingPlans.total, 'لا يعرض تفاصيل مالية خاصة.'],
    ['طلبات العروض', 'إجمالي الطلبات', report.quotes.total, 'طلبات غير ملزمة ولا تعني دفع أو حجز مؤكد.'],
  ];

  return (
    <section className="page-stack">
      <PageHeader
        eyebrow="التقارير"
        icon="%"
        title="تقرير تشغيلي حقيقي"
        description="لقطة تشغيلية من /admin/reports/overview تشمل المستخدمين والموردين والخدمات والتقييمات والإشعارات بدون دفع أو عربون."
        meta={
          <>
            <span>آخر توليد: {formatDate(report.generatedAt)}</span>
            <StatusBadge status={report.source === 'admin_operational_database' ? 'OPEN' : 'PENDING'} />
          </>
        }
      />

      <div className="stats-grid">
        <StatCard title="المستخدمون" value={report.users.total} tone="gold" />
        <StatCard title="الموردون" value={report.providers.total} tone="info" />
        <StatCard title="الخدمات" value={report.services.total} tone="success" />
        <StatCard title="التقييمات" value={report.reviews.total} tone="warning" />
        <StatCard title="الإشعارات" value={report.notifications.total} tone="danger" />
      </div>

      <SectionCard
        title="مؤشرات التشغيل"
        subtitle="الأرقام من قاعدة البيانات مباشرة، ولا تشمل دفع أو تأكيد حجز."
      >
        <DataTable columns={['القسم', 'المؤشر', 'القيمة', 'ملاحظة']} minWidth={960}>
          {rows.map(([section, metric, value, note]) => (
            <tr key={`${section}-${metric}`}>
              <td>{section}</td>
              <td>
                <strong>{metric}</strong>
              </td>
              <td>{value}</td>
              <td>
                <span className="table-subtle">{note}</span>
              </td>
            </tr>
          ))}
        </DataTable>
      </SectionCard>

      <SectionCard title="حالات طلبات العروض" subtitle="Planning leads فقط، ليست حجوزات مدفوعة.">
        <DataTable columns={['الحالة', 'العدد', 'النسبة']} minWidth={720} dense>
          {report.quotes.byStatus.map((item) => (
            <tr key={item.status}>
              <td>{item.status}</td>
              <td>{item.count}</td>
              <td>{percent(item.count, report.quotes.total)}</td>
            </tr>
          ))}
        </DataTable>
      </SectionCard>
    </section>
  );
}

function percent(value: number, total: number) {
  if (!total) return '0%';
  return `${Math.round((value / total) * 100)}%`;
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat('ar-YE', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}
