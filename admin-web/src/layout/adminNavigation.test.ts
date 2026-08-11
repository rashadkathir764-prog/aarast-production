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

  it('resolves a concise location for list and detail routes', () => {
    expect(resolveAdminLocation('/providers/applications')).toMatchObject({
      group: 'السوق والكتالوج',
      title: 'طلبات الموردين',
      route: '/providers/applications',
    });
    expect(resolveAdminLocation('/providers/applications/provider-1')).toMatchObject({
      group: 'السوق والكتالوج',
      title: 'تفاصيل طلب مورد',
      route: '/providers/applications',
    });
    expect(resolveAdminLocation('/users/user-1')).toMatchObject({
      group: 'الحسابات والرقابة',
      title: 'تفاصيل مستخدم',
      route: '/users',
    });
    expect(resolveAdminLocation('/providers/provider-1/')).toMatchObject({
      title: 'تفاصيل مورد',
      route: '/providers',
      isDetail: true,
    });
    expect(resolveAdminLocation('/providers2')).toMatchObject({
      title: 'صفحة غير معروفة',
      route: '/',
      isDetail: false,
    });
  });
});
