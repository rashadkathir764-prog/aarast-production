import { describe, expect, it } from 'vitest';
import applicationsSource from './ProviderApplicationsPage.tsx?raw';
import providersSource from './ProvidersPage.tsx?raw';
import reviewsSource from './ReviewsPage.tsx?raw';
import servicesSource from './ServicesPage.tsx?raw';
import usersSource from './UsersPage.tsx?raw';
import reportsSource from './ConversationReportsPage.tsx?raw';
import { providerActionVisibility } from './providerHelpers';

describe('provider administration lifecycle', () => {
  it('does not show approve and activate together for suspended providers', () => {
    expect(providerActionVisibility('SUSPENDED')).toEqual({
      approve: false,
      activate: true,
      requestChanges: false,
      reject: false,
      suspend: false,
    });
    expect(providerActionVisibility('ACTIVE')).toEqual({
      approve: false,
      activate: false,
      requestChanges: false,
      reject: false,
      suspend: true,
    });
  });

  it('keeps applications and provider directory defaults distinct', () => {
    expect(applicationsSource).toContain('الطلبات غير المعتمدة');
    expect(providersSource).toContain('النشطون والموقوفون');
  });

  it('labels page-local aggregates honestly', () => {
    for (const source of [
      providersSource,
      reviewsSource,
      servicesSource,
      usersSource,
      reportsSource,
    ]) {
      expect(source).toContain('value={pagination.total}');
      expect(source).toContain('في الصفحة');
    }
  });
});
