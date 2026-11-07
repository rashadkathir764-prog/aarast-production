import { render, screen, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { getAdminAuditLogs, type AdminAuditLog } from './api';
import { AuditLogsPage, auditActionWords } from './AuditLogsPage';

vi.mock('./api', () => ({ getAdminAuditLogs: vi.fn() }));

function log(input: Partial<AdminAuditLog> & { id: string; eventId: string }): AdminAuditLog {
  return {
    actorUserId: 'admin-rashad',
    actorAdminRole: 'SUPER_ADMIN',
    action: '',
    method: 'PATCH',
    route: '/admin/providers/:id/request-changes',
    targetId: 'provider-1',
    phase: 'SUCCEEDED',
    statusCode: 200,
    errorType: null,
    requestId: null,
    createdAt: '2026-10-24T07:41:00.000Z',
    ...input,
  };
}

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date('2026-10-24T08:00:00.000Z'));
});

afterEach(() => {
  vi.useRealTimers();
  vi.clearAllMocks();
});

describe('audit words', () => {
  it('names each recorded route in the designs’ words', () => {
    expect(auditActionWords('PATCH', '/admin/providers/:id/request-changes')).toEqual({
      label: 'طلب تعديل',
      target: 'provider',
    });
    expect(auditActionWords('PATCH', '/admin/providers/:id/verify').label).toBe('وثّق');
    expect(auditActionWords('PATCH', '/admin/users/:id/disable').target).toBe('user');
    expect(auditActionWords('DELETE', '/admin/provider-categories/:id')).toEqual({
      label: 'عطّل قسم',
      target: 'قسم',
    });
    expect(auditActionWords('PUT', '/admin/unknown').label).toBe('إجراء آخر');
  });

  // RA-AD-09: the words of the writes added since; every admin write route of
  // the server's table is checked by scripts/audit-words.contract.mjs.
  it('names the ownership claims, the featured periods and the take-back', () => {
    expect(auditActionWords('POST', '/admin/provider-claims/:id/approve').label).toBe('قبل استلام ملف');
    expect(auditActionWords('POST', '/admin/providers/:id/featured-periods').target).toBe('provider');
    expect(auditActionWords('POST', '/admin/data-requests/:id/restore')).toEqual({
      label: 'رجّع حساب بطلبه',
      target: 'user',
    });
  });
});

describe('AuditLogsPage (a15)', () => {
  it('reads who did what to whom, with names and the result', async () => {
    // RA-AD-09: the server sends one line per action, so e1's attempt no
    // longer comes with its result (this reply used to carry both).
    vi.mocked(getAdminAuditLogs).mockResolvedValue({
      items: [
        log({ id: '1', eventId: 'e1' }),
        log({
          id: '3',
          eventId: 'e2',
          actorUserId: 'admin-sara',
          actorAdminRole: 'MODERATOR',
          route: '/admin/providers/:id/suspend',
          targetId: 'provider-2',
          phase: 'FAILED',
          createdAt: '2026-10-23T09:00:00.000Z',
        }),
      ],
      page: 1,
      limit: 40,
      total: 2,
      totalPages: 1,
    });
    const names: Record<string, string> = { 'admin-rashad': 'رشاد', 'admin-sara': 'سارة' };
    const providers: Record<string, string> = {
      'provider-1': 'استوديو ضوء صنعاء',
      'provider-2': 'فرقة الأفراح',
    };

    render(
      <AuditLogsPage
        getUserName={(id) => Promise.resolve(names[id])}
        getProviderName={(id) => Promise.resolve(providers[id])}
      />,
    );

    const table = await screen.findByRole('table', { name: 'سجل التدقيق' });
    const rows = within(table).getAllByRole('row').slice(1);
    expect(rows).toHaveLength(2);
    expect(rows[0]).toHaveTextContent('10:41');
    expect(rows[0]).toHaveTextContent('رشاد · مدير أعلى');
    expect(rows[0]).toHaveTextContent('طلب تعديل');
    expect(rows[0]).toHaveTextContent('استوديو ضوء صنعاء');
    expect(within(rows[0]).getByRole('img', { name: 'نجح' })).toBeInTheDocument();
    expect(rows[1]).toHaveTextContent('أمس');
    expect(rows[1]).toHaveTextContent('سارة · إشراف');
    expect(rows[1]).toHaveTextContent('أوقف');
    expect(rows[1]).toHaveTextContent('فرقة الأفراح');
    expect(within(rows[1]).getByRole('img', { name: 'فشل' })).toBeInTheDocument();
    expect(screen.queryByText('السبب')).not.toBeInTheDocument();
    expect(getAdminAuditLogs).toHaveBeenCalledWith({ page: 1, limit: 40 });
  });

  it('shows the kind of target when it cannot read a name', async () => {
    vi.mocked(getAdminAuditLogs).mockResolvedValue({
      items: [log({ id: '1', eventId: 'e1', route: '/admin/cities/:id', method: 'DELETE', targetId: 'city-1' })],
      page: 1,
      limit: 40,
      total: 1,
      totalPages: 1,
    });
    render(
      <AuditLogsPage
        getUserName={() => Promise.reject(new Error('no'))}
        getProviderName={() => Promise.reject(new Error('no'))}
      />,
    );
    const row = (await screen.findByText('عطّل مدينة')).closest('tr') as HTMLElement;
    expect(row).toHaveTextContent('مدينة');
    expect(row).toHaveTextContent('عضو · مدير أعلى');
  });
});
