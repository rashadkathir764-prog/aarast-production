import { describe, expect, it } from 'vitest';
import {
  adminNavigationItems,
  resolveAdminLocation,
} from './adminNavigation';

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
    ).toEqual(['/', '/providers/applications', '/conversation-reports']);
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
    expect(resolveAdminLocation('/notifications')).toMatchObject({
      title: 'الإشعارات',
      crumb: ['النظام'],
    });
    expect(resolveAdminLocation('/providers2')).toMatchObject({
      title: 'صفحة غير معروفة',
      route: '/',
      isDetail: false,
    });
  });
});
