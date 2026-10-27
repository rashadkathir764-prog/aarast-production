import { render, screen, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { getSuccessReport, type AdminSuccessReport } from './api';
import { ReportsPage, successReportCsv } from './ReportsPage';

// a02 and V1 checklist 4.21: success indicators and the anonymous price report.
vi.mock('./api', () => ({ getSuccessReport: vi.fn() }));

const report: AdminSuccessReport = {
  generatedAt: '2026-09-30T12:00:00.000Z',
  activeUsers: { windowDays: 7, active: 4120, total: 18402 },
  costs: { recorded: 25, plansWithCosts: 10, perPlan: 14 },
  conversion: { windowDays: 30, quoteRequests: 3910, confirmedBookings: 1102, rate: 28 },
  visibleProviders: 388,
  prices: [
    {
      cityId: 'sanaa',
      categoryId: 'photo',
      cityName: 'صنعاء',
      categoryName: 'التصوير',
      currency: 'YER',
      providers: 24,
      services: 30,
      min: '180000.00',
      median: '350000.00',
      max: '900000.00',
    },
  ],
};

afterEach(() => {
  vi.clearAllMocks();
});

describe('ReportsPage (a02)', () => {
  it('G41: shows what plans agreed per item, anonymous, and saves it', async () => {
    const withSpending: AdminSuccessReport = {
      ...report,
      spending: {
        minPlans: 5,
        groups: [
          {
            city: 'صنعاء',
            itemName: 'قاعة',
            currency: 'YER',
            plans: 7,
            min: '300000.00',
            median: '500000.00',
            max: '900000.00',
          },
        ],
      },
    };
    vi.mocked(getSuccessReport).mockResolvedValue(withSpending);
    render(<ReportsPage />);
    const row = within(
      await screen.findByRole('table', { name: 'اللي اتفق عليه العرسان فعلًا' }),
    ).getAllByRole('row')[1];
    expect(row).toHaveTextContent('قاعة');
    expect(row).toHaveTextContent('7');
    expect(within(row).getByText('500,000').tagName).toBe('STRONG');
    expect(screen.getByText(/مجهول الهوية/)).toBeVisible();
    expect(successReportCsv(withSpending)).toContain('صنعاء,قاعة,7,300000.00');
  });

  it('shows the four indicators, the price ranges and the counted window', async () => {
    vi.mocked(getSuccessReport).mockResolvedValue(report);
    render(<ReportsPage />);

    expect(await screen.findByText('4,120 من 18,402')).toBeVisible();
    expect(screen.getByText('14')).toBeVisible();
    expect(screen.getByText('28٪')).toBeVisible();
    expect(screen.getByText('1,102 من 3,910')).toBeVisible();
    expect(screen.getByText('388')).toBeVisible();
    expect(screen.getByText('من 31 أغسطس لين 30 سبتمبر')).toBeVisible();

    const row = within(screen.getByRole('table', { name: 'تقرير أسعار السوق' }))
      .getAllByRole('row')[1];
    expect(row).toHaveTextContent('صنعاء');
    expect(row).toHaveTextContent('180,000');
    expect(within(row).getByText('350,000').tagName).toBe('STRONG');
    expect(screen.getByRole('button', { name: 'تنزيل' })).toBeVisible();
    expect(screen.queryByRole('button', { name: /آخر 30 يوم/ })).not.toBeInTheDocument();
  });

  it('says when there is not enough price data yet', async () => {
    vi.mocked(getSuccessReport).mockResolvedValue({
      ...report,
      prices: [],
      conversion: { ...report.conversion, rate: null },
    });
    render(<ReportsPage />);

    expect(await screen.findByText('ما عندنا أسعار كافية بعد.')).toBeVisible();
    expect(screen.getAllByText('—').length).toBeGreaterThan(0);
  });

  it('writes the same numbers into the download', () => {
    const csv = successReportCsv(report);
    expect(csv).toContain('مستخدمون نشطون هذا الأسبوع,4120 من 18402');
    expect(csv).toContain('طلبات عروض صارت حجز,28٪ (1102 من 3910)');
    expect(csv).toContain('صنعاء,التصوير,24,180000.00,350000.00,900000.00,YER');
  });
});
