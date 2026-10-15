import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { SuccessReportSection } from './SuccessReportSection';
import type { AdminSuccessReport } from './api';

// V1 checklist 4.21: success indicators and the anonymous price report.

const report: AdminSuccessReport = {
  generatedAt: '2026-10-15T12:00:00.000Z',
  activeUsers: { windowDays: 7, active: 12, total: 40 },
  costs: { recorded: 25, plansWithCosts: 10, perPlan: 2.5 },
  conversion: { windowDays: 30, quoteRequests: 8, confirmedBookings: 2, rate: 25 },
  visibleProviders: 6,
  prices: [
    {
      cityId: 'sanaa',
      categoryId: 'halls',
      cityName: 'صنعاء',
      categoryName: 'قاعات',
      currency: 'YER',
      providers: 3,
      services: 4,
      min: '100000.00',
      median: '250000.00',
      max: '400000.00',
    },
  ],
};

describe('SuccessReportSection', () => {
  it('shows the four indicators and the price ranges', async () => {
    render(<SuccessReportSection load={async () => report} />);

    expect(await screen.findByText('12 من 40')).toBeTruthy();
    expect(screen.getByText('2.5')).toBeTruthy();
    expect(screen.getByText('25٪ (2 من 8)')).toBeTruthy();
    expect(screen.getByText('6')).toBeTruthy();
    expect(screen.getByText('صنعاء')).toBeTruthy();
    expect(screen.getByText(/٢٥٠٬٠٠٠|250,000|250٬000/)).toBeTruthy();
  });

  it('says when there is not enough price data yet', async () => {
    render(
      <SuccessReportSection
        load={async () => ({ ...report, prices: [], conversion: { ...report.conversion, rate: null } })}
      />,
    );

    expect(await screen.findByText('لا توجد بيانات كافية بعد')).toBeTruthy();
    expect(screen.getAllByText('—').length).toBeGreaterThan(0);
  });
});
