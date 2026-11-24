import { renderHook, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AdminPermission } from '../features/auth/api';
import { getStats } from '../features/dashboard/api';
import {
  getAssistantReports,
  getConversationReports,
  getPortfolioPhotos,
  getReviews,
} from '../features/moderation/api';
import { getDataRequests } from '../features/users/api';
import { useQueueCounts } from './useQueueCounts';

vi.mock('../features/dashboard/api', () => ({ getStats: vi.fn() }));
vi.mock('../features/moderation/api', () => ({
  getConversationReports: vi.fn(),
  getAssistantReports: vi.fn(),
  getPortfolioPhotos: vi.fn(),
  getReviews: vi.fn(),
}));
vi.mock('../features/users/api', () => ({ getDataRequests: vi.fn() }));

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
    // RA-AD-08: «الصندوق» counts what it lists. RA-AD-27: it lists the
    // reported assistant answers too now, so they count (it said 2 while they
    // waited outside it).
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
    // RA-AD-27: the inbox holds the assistant answers, so it cannot read whole.
    expect(result.current.inbox).toBeUndefined();
  });

  it('RA-AD-27: counts the photos waiting, the reported reviews and the failed deletions for whom acts on them', async () => {
    vi.mocked(getPortfolioPhotos).mockResolvedValue(total(4) as never);
    vi.mocked(getReviews).mockResolvedValue(total(1) as never);
    vi.mocked(getDataRequests).mockResolvedValue({
      exports: [],
      deletions: [{ purgeFailedAt: '2026-10-23T10:00:00.000Z' }, { purgeFailedAt: null }],
    } as never);
    const { result } = renderHook(() =>
      useQueueCounts(
        { adminPermissions: [AdminPermission.REVIEWS_WRITE, AdminPermission.USERS_WRITE] },
        'k',
      ),
    );

    await waitFor(() => expect(result.current.inbox).toBe(6));
    expect(getPortfolioPhotos).toHaveBeenCalledWith({ status: 'PENDING', page: 1, limit: 1 });
    expect(getReviews).toHaveBeenCalledWith({ reported: 'true', page: 1, limit: 1 });
    expect(getConversationReports).not.toHaveBeenCalled();
  });
});
