import { describe, expect, it } from 'vitest';
import conversationReportsSource from './ConversationReportsPage.tsx?raw';
import notificationsSource from './NotificationsPage.tsx?raw';
import providerApplicationsSource from './ProviderApplicationsPage.tsx?raw';
import providersSource from './ProvidersPage.tsx?raw';
import reviewsSource from './ReviewsPage.tsx?raw';
import servicesSource from './ServicesPage.tsx?raw';
import usersSource from './UsersPage.tsx?raw';

const paginatedPages = [
  ['UsersPage.tsx', usersSource],
  ['ProviderApplicationsPage.tsx', providerApplicationsSource],
  ['ProvidersPage.tsx', providersSource],
  ['ServicesPage.tsx', servicesSource],
  ['ReviewsPage.tsx', reviewsSource],
  ['ConversationReportsPage.tsx', conversationReportsSource],
  ['NotificationsPage.tsx', notificationsSource],
] as const;

describe('admin list pagination contract', () => {
  for (const [file, source] of paginatedPages) {
    it(`${file} sends page metadata and renders the shared control`, () => {
      expect(source).toContain("from '../components/Pagination'");
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
