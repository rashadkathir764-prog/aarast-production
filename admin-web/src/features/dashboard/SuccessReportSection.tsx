import { useEffect, useState } from 'react';
import { DataTable } from '../../design_system/DataTable';
import { EmptyState } from '../../design_system/EmptyState';
import { ErrorState } from '../../design_system/ErrorState';
import { LoadingState } from '../../design_system/LoadingState';
import { SectionCard } from '../../design_system/SectionCard';
import { StatCard } from '../../design_system/StatCard';
import { type AdminSuccessReport, getSuccessReport } from './api';

type SuccessReportSectionProps = {
  load?: () => Promise<AdminSuccessReport>;
};

/**
 * The success indicators and the market price report (V1 checklist 4.21).
 * Prices are aggregates only: a city and category shows once at least three
 * providers price in it, so no single provider's price can be read off.
 */
export function SuccessReportSection({ load = getSuccessReport }: SuccessReportSectionProps) {
  const [report, setReport] = useState<AdminSuccessReport | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function refresh() {
    setError(null);
    try {
      setReport(await load());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل مؤشرات النجاح.');
    }
  }

  useEffect(() => {
    void refresh();
  }, []);

  if (error) return <ErrorState message={error} onRetry={refresh} />;
  if (!report) return <LoadingState title="جاري تحميل مؤشرات النجاح" />;

  const { activeUsers, costs, conversion } = report;
  return (
    <>
      <SectionCard
        title="مؤشرات النجاح"
        subtitle={`نشاط المستخدمين خلال ${activeUsers.windowDays} أيام، والتحويل خلال ${conversion.windowDays} يومًا.`}
      >
        <div className="stats-grid">
          <StatCard
            title="مستخدمون نشطون هذا الأسبوع"
            value={`${activeUsers.active} من ${activeUsers.total}`}
            tone="gold"
          />
          <StatCard
            title="تكاليف مسجلة لكل خطة"
            value={costs.perPlan === null ? '—' : String(costs.perPlan)}
            tone="info"
          />
          <StatCard
            title="طلبات عروض صارت حجزًا"
            value={
              conversion.rate === null
                ? '—'
                : `${conversion.rate}٪ (${conversion.confirmedBookings} من ${conversion.quoteRequests})`
            }
            tone="success"
          />
          <StatCard
            title="مزوّدون يراهم العملاء"
            value={report.visibleProviders}
            tone="warning"
          />
        </div>
      </SectionCard>

      <SectionCard
        title="تقرير أسعار السوق"
        subtitle="مجهول الهوية: يظهر كل بند عندما يسعّر فيه 3 مزوّدين على الأقل، ولا تُخلط العملات."
      >
        {report.prices.length === 0 ? (
          <EmptyState
            title="لا توجد بيانات كافية بعد"
            message="يظهر السعر عندما يضع 3 مزوّدين على الأقل أسعارًا في نفس المدينة والفئة."
          />
        ) : (
          <DataTable
            label="تقرير أسعار السوق"
            columns={['المدينة', 'الفئة', 'المزوّدون', 'أقل سعر', 'الوسيط', 'أعلى سعر']}
            minWidth={720}
          >
            {report.prices.map((group) => (
              <tr key={`${group.cityId}-${group.categoryId}-${group.currency}`}>
                <td>{group.cityName ?? 'غير معروفة'}</td>
                <td>{group.categoryName ?? 'غير معروفة'}</td>
                <td>{group.providers}</td>
                <td>{formatAmount(group.min, group.currency)}</td>
                <td>{formatAmount(group.median, group.currency)}</td>
                <td>{formatAmount(group.max, group.currency)}</td>
              </tr>
            ))}
          </DataTable>
        )}
      </SectionCard>
    </>
  );
}

function formatAmount(amount: string, currency: string): string {
  const value = Number(amount);
  const formatted = Number.isFinite(value)
    ? value.toLocaleString('ar', { maximumFractionDigits: 0 })
    : amount;
  return `${formatted} ${currency === 'YER' ? 'ر.ي' : currency}`;
}
