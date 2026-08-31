import { describe, expect, it } from 'vitest';
import conversationReportsSource from '../../features/moderation/ConversationReportsPage.tsx?raw';
import notificationsSource from '../../features/notifications/NotificationsPage.tsx?raw';
import providerApplicationsSource from '../../features/providers/ProviderApplicationsPage.tsx?raw';
import providersSource from '../../features/providers/ProvidersPage.tsx?raw';
import reviewsSource from '../../features/moderation/ReviewsPage.tsx?raw';
import servicesSource from '../../features/catalog/ServicesPage.tsx?raw';
import usersSource from '../../features/users/UsersPage.tsx?raw';

const paginatedPages = [
  ['UsersPage.tsx', usersSource, '../../design_system/Pagination'],
  ['ProviderApplicationsPage.tsx', providerApplicationsSource, '../../design_system/Pagination'],
  ['ProvidersPage.tsx', providersSource, '../../design_system/Pagination'],
  ['ServicesPage.tsx', servicesSource, '../../design_system/Pagination'],
  ['ReviewsPage.tsx', reviewsSource, '../../design_system/Pagination'],
  ['ConversationReportsPage.tsx', conversationReportsSource, '../../design_system/Pagination'],
  ['NotificationsPage.tsx', notificationsSource, '../../design_system/Pagination'],
] as const;

describe('admin list pagination contract', () => {
  for (const [file, source, expectedPaginationImport] of paginatedPages) {
    it(`${file} sends page metadata and renders the shared control`, () => {
      expect(source).toContain(`from '${expectedPaginationImport}'`);
      expect(source).toMatch(/get[A-Za-z]+\(\{[\s\S]*?page,[\s\S]*?limit:/);
      expect(source).toContain('<Pagination');
      expect(source).toContain('totalPages={pagination.totalPages}');
    });
  }

  it('uses server-side provider search instead of a fixed 100-row lookup', () => {
    expect(servicesSource).toContain('providerSearchQuery');
    expect(reviewsSource).toContain('providerSearchQuery');
    expect(servicesSource).not.toContain('getProviders({ limit: 100 })');
    expect(reviewsSource).not.toContain('getProviders({ limit: 100 })');
    expect(servicesSource).toContain('search: providerSearchQuery');
    expect(reviewsSource).toContain('search: providerSearchQuery');
  });
});
