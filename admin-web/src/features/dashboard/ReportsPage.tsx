// a02 «التقارير»: the success numbers and the market price report.
// The success report takes no date range, so «آخر 30 يوم»
// waits for A-05 and the line under the title names the thirty days the
// server counts the conversion over. «تنزيل» saves the same numbers as CSV.
// G41: what plans really agreed per item, anonymous, under the prices.
import { useCallback, useEffect, useState } from 'react';
import { Download } from 'lucide-react';
import { getSuccessReport, type AdminSuccessReport } from './api';
import {
  DeskButton,
  DeskHeader,
  DeskNote,
  DeskRetry,
  DeskTable,
  Panel,
  Stat,
  StatRow,
  grouped,
} from '../../design_system/Desk';
import { dayMonth, PROMISE } from '../../platform/i18n/deskTime';

type PriceRow = AdminSuccessReport['prices'][number];
type SpendingRow = NonNullable<AdminSuccessReport['spending']>['groups'][number];

function amount(value: string, currency: string): string {
  const number = grouped(value);
  return currency === 'YER' ? number : `${number} ${currency}`;
}

function csvCell(value: string | number | null): string {
  const text = value === null ? '' : String(value);
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/** The page's numbers as a CSV the admin can open in a sheet. */
export function successReportCsv(report: AdminSuccessReport): string {
  const lines: Array<Array<string | number | null>> = [
    ['المؤشر', 'القيمة'],
    ['مستخدمون نشطون هذا الأسبوع', `${report.activeUsers.active} من ${report.activeUsers.total}`],
    ['تكاليف مسجلة لكل خطة', report.costs.perPlan],
    [
      'طلبات عروض صارت حجز',
      report.conversion.rate === null
        ? null
        : `${report.conversion.rate}٪ (${report.conversion.confirmedBookings} من ${report.conversion.quoteRequests})`,
    ],
    ['مزودون يراهم العرسان', report.visibleProviders],
    [],
    ['المدينة', 'القسم', 'المزودون', 'أقل سعر', 'الوسيط', 'أعلى سعر', 'العملة'],
    ...report.prices.map((row) => [
      row.cityName,
      row.categoryName,
      row.providers,
      row.min,
      row.median,
      row.max,
      row.currency,
    ]),
    [],
    ['المدينة', 'البند', 'الخطط', 'أقل اتفاق', 'الوسيط', 'أعلى اتفاق', 'العملة'],
    ...(report.spending?.groups ?? []).map((row) => [
      row.city,
      row.itemName,
      row.plans,
      row.min,
      row.median,
      row.max,
      row.currency,
    ]),
  ];
  return `﻿${lines.map((line) => line.map(csvCell).join(',')).join('\n')}\n`;
}

function save(report: AdminSuccessReport) {
  const blob = new Blob([successReportCsv(report)], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `aarast-report-${report.generatedAt.slice(0, 10)}.csv`;
  document.body.append(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

export function ReportsPage() {
  const [report, setReport] = useState<AdminSuccessReport | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      setReport(await getSuccessReport());
    } catch (value) {
      setError(value instanceof Error ? value.message : 'ما قدرنا نحمّل التقارير.');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const end = report ? new Date(report.generatedAt) : null;
  const start = report && end
    ? new Date(end.getTime() - report.conversion.windowDays * PROMISE.DAY)
    : null;

  return (
    <section>
      <DeskHeader
        title="التقارير"
        sub={start && end ? `من ${dayMonth(start, end)} لين ${dayMonth(end, end)}` : undefined}
        actions={
          report ? (
            <DeskButton tone="soft" icon={Download} onClick={() => save(report)}>
              تنزيل
            </DeskButton>
          ) : null
        }
      />
      {error ? <DeskRetry message={error} onRetry={() => void load()} /> : null}
      {report === null && !error ? <DeskNote>لحظة، نحمّل التقارير…</DeskNote> : null}
      {report ? (
        <>
          <StatRow>
            <Stat
              value={`${grouped(report.activeUsers.active)} من ${grouped(report.activeUsers.total)}`}
              label="مستخدمون نشطون هذا الأسبوع"
            />
            <Stat
              value={report.costs.perPlan === null ? '—' : grouped(report.costs.perPlan)}
              label="تكاليف مسجلة لكل خطة"
            />
            <Stat
              value={report.conversion.rate === null ? '—' : `${report.conversion.rate}٪`}
              label="طلبات عروض صارت حجز"
              sub={`${grouped(report.conversion.confirmedBookings)} من ${grouped(report.conversion.quoteRequests)}`}
            />
            <Stat value={grouped(report.visibleProviders)} label="مزودون يراهم العرسان" />
          </StatRow>
          {report.prices.length === 0 ? (
            <Panel>
              <DeskNote>ما عندنا أسعار كافية بعد.</DeskNote>
            </Panel>
          ) : (
            <DeskTable<PriceRow>
              caption="تقرير أسعار السوق"
              columns={[
                { label: 'المدينة', flex: 2 },
                { label: 'القسم', flex: 2 },
                { label: 'المزودون', flex: 1 },
                { label: 'أقل سعر', flex: 2 },
                { label: 'الوسيط', flex: 2 },
                { label: 'أعلى سعر', flex: 2 },
              ]}
              rows={report.prices}
              rowKey={(row) => `${row.cityId}-${row.categoryId}-${row.currency}`}
              renderRow={(row) => [
                row.cityName ?? '—',
                row.categoryName ?? '—',
                grouped(row.providers),
                amount(row.min, row.currency),
                <strong key="m">{amount(row.median, row.currency)}</strong>,
                amount(row.max, row.currency),
              ]}
            />
          )}
          <DeskNote>السعر يظهر لما يكون عندنا 3 مزودين على الأقل. وكل مدينة بعملتها.</DeskNote>
          {report.spending && report.spending.groups.length > 0 ? (
            <DeskTable<SpendingRow>
              caption="اللي اتفق عليه العرسان فعلًا"
              columns={[
                { label: 'المدينة', flex: 2 },
                { label: 'البند', flex: 2 },
                { label: 'الخطط', flex: 1 },
                { label: 'أقل اتفاق', flex: 2 },
                { label: 'الوسيط', flex: 2 },
                { label: 'أعلى اتفاق', flex: 2 },
              ]}
              rows={report.spending.groups}
              rowKey={(row) => `${row.city}-${row.itemName}-${row.currency}`}
              renderRow={(row) => [
                row.city,
                row.itemName,
                grouped(row.plans),
                amount(row.min, row.currency),
                <strong key="m">{amount(row.median, row.currency)}</strong>,
                amount(row.max, row.currency),
              ]}
            />
          ) : null}
          {report.spending ? (
            <DeskNote>
              مجهول الهوية: البند يظهر لما يكون فيه {report.spending.minPlans} خطط على الأقل،
              بدون الاتفاقات الملغية والخاصة والمهر.
            </DeskNote>
          ) : null}
        </>
      ) : null}
    </section>
  );
}
