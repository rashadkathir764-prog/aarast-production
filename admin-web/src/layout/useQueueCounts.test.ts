import { renderHook, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AdminPermission } from '../features/auth/api';
import { getStats } from '../features/dashboard/api';
import { getAssistantReports, getConversationReports } from '../features/moderation/api';
import { useQueueCounts } from './useQueueCounts';

vi.mock('../features/dashboard/api', () => ({ getStats: vi.fn() }));
vi.mock('../features/moderation/api', () => ({
  getConversationReports: vi.fn(),
  getAssistantReports: vi.fn(),
}));

const moderator = {
  adminPermissions: [
    AdminPermission.CONVERSATION_REPORTS_READ,
    AdminPermission.CONVERSATION_REPORTS_WRITE,
  ],
};

const total = (value: number) => ({ items: [], page: 1, limit: 1, total: value, totalPages: value });

afterEach(() => {
  vi.clearAllMocks();
});

describe('useQueueCounts', () => {
  // RA-ST-04 (D95): «البلاغات» holds the chats' and the assistant answers'.
  it('counts the open chat reports and the reported assistant answers together', async () => {
    vi.mocked(getConversationReports).mockResolvedValue(total(2) as never);
    vi.mocked(getAssistantReports).mockResolvedValue(total(3) as never);
    const { result } = renderHook(() => useQueueCounts(moderator, 'k'));

    await waitFor(() => expect(result.current.reports).toBe(5));
    expect(result.current.inbox).toBe(5);
    expect(getAssistantReports).toHaveBeenCalledWith({ status: 'OPEN', page: 1, limit: 1 });
    expect(getStats).not.toHaveBeenCalled();
  });

  it('hides the count it cannot read whole', async () => {
    vi.mocked(getConversationReports).mockResolvedValue(total(2) as never);
    vi.mocked(getAssistantReports).mockRejectedValue(new Error('Cannot GET'));
    const { result } = renderHook(() => useQueueCounts(moderator, 'k'));

    await waitFor(() => expect(getAssistantReports).toHaveBeenCalled());
    await waitFor(() => expect('reports' in result.current).toBe(true));
    expect(result.current.reports).toBeUndefined();
    expect(result.current.inbox).toBeUndefined();
  });
});
