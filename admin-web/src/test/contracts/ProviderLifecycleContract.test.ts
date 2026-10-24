import { describe, expect, it } from 'vitest';
import applicationsSource from '../../features/providers/ProviderApplicationsPage.tsx?raw';
import providersSource from '../../features/providers/ProvidersPage.tsx?raw';
import reviewsSource from '../../features/moderation/ReviewsPage.tsx?raw';
import servicesSource from '../../features/catalog/ServicesPage.tsx?raw';
import usersSource from '../../features/users/UsersPage.tsx?raw';
import reportsSource from '../../features/moderation/ConversationReportsPage.tsx?raw';
import {
  providerActionVisibility,
  providerVerificationAction,
} from '../../features/providers/providerHelpers';

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

  it('offers verification only on active providers and clearing always', () => {
    expect(providerVerificationAction({ status: 'ACTIVE', verifiedAt: null })).toBe('verify');
    for (const status of ['PENDING', 'NEEDS_CHANGES', 'SUSPENDED', 'REJECTED']) {
      expect(providerVerificationAction({ status, verifiedAt: null })).toBeNull();
      expect(
        providerVerificationAction({ status, verifiedAt: '2026-10-11T00:00:00.000Z' }),
      ).toBe('unverify');
    }
  });

  it('keeps applications and provider directory defaults distinct', () => {
    // a03 opens on the new applications; a05 leaves the status to the
    // server, which lists the active and suspended providers.
    expect(applicationsSource).toContain("useState<Status>('PENDING')");
    expect(applicationsSource).toContain('getProviderApplications');
    expect(providersSource).toContain('getProviders({ page, limit: 20 })');
  });

  it('shows directory totals from the server, never page-local sums', () => {
    expect(providersSource).toContain('counts.totalProviders');
    expect(providersSource).toContain('counts.approvedProviders');
    expect(providersSource).not.toContain('في الصفحة');
    expect(applicationsSource).not.toContain('في الصفحة');
  });

  it('labels page-local aggregates honestly', () => {
    for (const source of [
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
