import { describe, expect, it } from 'vitest';
import {
  adminNavigationItems,
  resolveAdminLocation,
} from './adminNavigation';
import { AdminPermission } from '../features/auth/api';

function itemFor(route: string) {
  const item = adminNavigationItems.find((candidate) => candidate.route === route);
  if (!item) throw new Error(`Missing navigation item for ${route}`);
  return item;
}

describe('admin navigation', () => {
  it('keeps the provider directory inactive inside provider applications', () => {
    const providers = itemFor('/providers');
    const applications = itemFor('/providers/applications');

    expect(providers.isActive('/providers/applications')).toBe(false);
    expect(providers.isActive('/providers/applications/provider-1')).toBe(false);
    expect(applications.isActive('/providers/applications')).toBe(true);
    expect(applications.isActive('/providers/applications/provider-1')).toBe(true);
  });

  it('keeps directory links active for their own detail pages', () => {
    expect(itemFor('/providers').isActive('/providers/provider-1')).toBe(true);
    expect(itemFor('/providers').isActive('/providers/provider-1/')).toBe(true);
    expect(itemFor('/users').isActive('/users/user-1')).toBe(true);
    expect(itemFor('/users').isActive('/users-old')).toBe(false);
  });

  it('only counts the queues the server can size', () => {
    expect(
      adminNavigationItems.filter((item) => item.count).map((item) => item.route),
    ).toEqual([
      '/',
      '/providers/applications',
      // B-12: the claims waiting for review.
      '/providers/listed',
      '/conversation-reports',
    ]);
  });

  it('keeps the claims page (a07) apart from the provider directory', () => {
    expect(resolveAdminLocation('/providers/listed')).toMatchObject({
      group: 'المزودين',
      title: 'ملفات بلا حساب',
      route: '/providers/listed',
      isDetail: false,
    });
  });

  it('puts the plans page (a17) under the providers, as drawn', () => {
    expect(resolveAdminLocation('/featured')).toMatchObject({
      group: 'المزودين',
      title: 'الباقات والظهور المميز',
      route: '/featured',
      crumb: ['المزودين'],
      isDetail: false,
    });
    expect(itemFor('/providers').isActive('/featured')).toBe(false);
  });

  it('puts the bookings page (a12) under the moderation, as drawn', () => {
    expect(resolveAdminLocation('/bookings')).toMatchObject({
      group: 'الرقابة',
      title: 'الحجوزات',
      route: '/bookings',
      isDetail: false,
    });
    expect(itemFor('/bookings').permission).toBe(AdminPermission.PROVIDERS_READ);
  });

  it('resolves the crumb the designs draw for list and detail routes', () => {
    expect(resolveAdminLocation('/')).toMatchObject({
      group: 'اليوم',
      title: 'الصندوق',
      crumb: ['اليوم'],
    });
    expect(resolveAdminLocation('/providers/applications')).toMatchObject({
      group: 'المزودين',
      title: 'طلبات الانضمام',
      route: '/providers/applications',
      crumb: ['المزودين'],
    });
    expect(resolveAdminLocation('/providers/applications/provider-1')).toMatchObject({
      title: 'تفاصيل طلب',
      route: '/providers/applications',
      crumb: ['المزودين', 'تفاصيل طلب'],
    });
    expect(resolveAdminLocation('/users/user-1')).toMatchObject({
      group: 'الناس',
      title: 'تفاصيل مستخدم',
      route: '/users',
    });
    expect(resolveAdminLocation('/providers/provider-1/')).toMatchObject({
      title: 'تفاصيل مزود',
      route: '/providers',
      isDetail: true,
      crumb: ['المزودين', 'تفاصيل مزود'],
    });
    expect(resolveAdminLocation('/categories')).toMatchObject({
      crumb: ['النظام', 'الكتالوج'],
    });
    // The old «الإشعارات» page was deleted (no design, D56).
    expect(resolveAdminLocation('/notifications')).toMatchObject({
      title: 'صفحة غير معروفة',
      crumb: [],
    });
    expect(resolveAdminLocation('/providers2')).toMatchObject({
      title: 'صفحة غير معروفة',
      route: '/',
      isDetail: false,
    });
  });
});
