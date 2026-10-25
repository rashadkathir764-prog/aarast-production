import { describe, expect, it } from 'vitest';
import conversationReportsSource from '../../features/moderation/ConversationReportsPage.tsx?raw';
import providerApplicationsSource from '../../features/providers/ProviderApplicationsPage.tsx?raw';
import providersSource from '../../features/providers/ProvidersPage.tsx?raw';
import reviewsSource from '../../features/moderation/ReviewsPage.tsx?raw';
import servicesSource from '../../features/catalog/ServicesPage.tsx?raw';
import usersSource from '../../features/users/UsersPage.tsx?raw';
import deskSource from '../../design_system/Desk.tsx?raw';

// Pages rebuilt on the admin desk render the same shared control through
// `DeskPager` (design_system/Desk.tsx), fed by the server's page answer.
const paginatedPages = [
  ['UsersPage.tsx', usersSource, 'desk'],
  ['ProviderApplicationsPage.tsx', providerApplicationsSource, 'desk'],
  ['ProvidersPage.tsx', providersSource, 'desk'],
  ['ServicesPage.tsx', servicesSource, 'desk'],
  ['ReviewsPage.tsx', reviewsSource, 'desk'],
  ['ConversationReportsPage.tsx', conversationReportsSource, 'desk'],
] as const;

describe('admin list pagination contract', () => {
  it('the desk pager renders the shared control', () => {
    expect(deskSource).toContain("from './Pagination'");
    expect(deskSource).toContain('<Pagination');
  });

  for (const [file, source, mode] of paginatedPages) {
    it(`${file} sends page metadata and renders the shared control`, () => {
      expect(source).toMatch(/get[A-Za-z]+\(\{[\s\S]*?page,[\s\S]*?limit:/);
      if (mode === 'desk') {
        expect(source).toContain("from '../../design_system/Desk'");
        expect(source).toContain('<DeskPager');
        expect(source).toContain('totalPages={result.totalPages}');
      } else {
        expect(source).toContain("from '../../design_system/Pagination'");
        expect(source).toContain('<Pagination');
        expect(source).toContain('totalPages={pagination.totalPages}');
      }
    });
  }

  it('uses server-side provider search instead of a fixed 100-row lookup', () => {
    expect(servicesSource).toContain('providerSearchQuery');
    expect(servicesSource).not.toContain('getProviders({ limit: 100 })');
    expect(servicesSource).toContain('search: providerSearchQuery');
    // a10 draws no provider filter, so the reviews page looks up no providers.
    expect(reviewsSource).not.toContain('getProviders(');
  });
});
