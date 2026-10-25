import { describe, expect, it } from 'vitest';
import appSource from '../../App.tsx?raw';
import adminApiSource from '../../features/audit/api.ts?raw';
import authApiSource from '../../features/auth/transport.ts?raw';
import sidebarSource from '../../layout/Sidebar.tsx?raw';
import auditPageSource from '../../features/audit/AuditLogsPage.tsx?raw';
import categoriesSource from '../../features/catalog/CategoriesPage.tsx?raw';
import citiesSource from '../../features/catalog/CitiesPage.tsx?raw';
import conversationReportsSource from '../../features/moderation/ConversationReportsPage.tsx?raw';
import providerHelpersSource from '../../features/providers/providerHelpers.tsx?raw';
import reviewsSource from '../../features/moderation/ReviewsPage.tsx?raw';
import servicesSource from '../../features/catalog/ServicesPage.tsx?raw';
import usersSource from '../../features/users/UsersPage.tsx?raw';
import userDetailsSource from '../../features/users/UserDetailsPage.tsx?raw';
import topbarSource from '../../layout/Topbar.tsx?raw';

describe('admin RBAC and audit UI contract', () => {
  it('carries server permissions through the admin session', () => {
    expect(authApiSource).toContain('adminRole');
    expect(authApiSource).toContain('adminPermissions');
  });

  it('gates routes and navigation by explicit permissions', () => {
    expect(appSource).toContain('RequireAdminPermission');
    expect(appSource).toContain("permission=" + '{AdminPermission.AUDIT_READ}');
    expect(sidebarSource).toContain('link.permission');
    expect(sidebarSource).toContain('hasAdminPermission');
  });

  it('exposes a paginated read-only audit surface', () => {
    expect(adminApiSource).toContain('/admin/audit-logs');
    // a15 pages through the desk pager, which renders the shared control.
    expect(auditPageSource).toContain('<DeskPager');
    expect(auditPageSource).toContain('AdminAuditPhase');
    expect(auditPageSource).not.toContain('deleteAdminAudit');
    expect(auditPageSource).not.toContain('updateAdminAudit');
  });

  it('hides write controls from read-only admin roles', () => {
    expect(providerHelpersSource).toContain('AdminPermission.PROVIDERS_WRITE');
    expect(servicesSource).toContain('AdminPermission.SERVICES_WRITE');
    expect(categoriesSource).toContain('AdminPermission.CATALOG_WRITE');
    expect(citiesSource).toContain('AdminPermission.CATALOG_WRITE');
    // An account is disabled or enabled on a13 only; the list changes nothing (D56).
    expect(userDetailsSource).toContain('AdminPermission.USERS_WRITE');
    expect(usersSource).not.toContain('disableUser');
    expect(usersSource).not.toContain('activateUser');
    expect(reviewsSource).toContain('AdminPermission.REVIEWS_WRITE');
    expect(conversationReportsSource).toContain(
      'AdminPermission.CONVERSATION_REPORTS_WRITE',
    );
  });

  it('does not offer admin-account status actions to delegated administrators', () => {
    expect(userDetailsSource).toContain("currentAdmin?.adminRole === 'SUPER_ADMIN'");
    expect(userDetailsSource).toContain("user.role !== 'ADMIN'");
    expect(userDetailsSource).toContain('user.id !== currentAdmin?.id');
  });

  it('keeps the admin avatar local to the CSP policy', () => {
    // The admin's letter moved to the sidebar foot (akit `desk`).
    expect(topbarSource).not.toContain('ui-avatars.com');
    expect(sidebarSource).not.toContain('ui-avatars.com');
    expect(sidebarSource).toContain('avatarInitial');
  });
});
