import { describe, expect, it } from 'vitest';
import appSource from '../../App.tsx?raw';
import adminApiSource from '../../features/audit/api.ts?raw';
import authApiSource from '../../features/auth/transport.ts?raw';
import sidebarSource from '../../layout/Sidebar.tsx?raw';
import auditPageSource from '../../features/audit/AuditLogsPage.tsx?raw';
import categoriesSource from '../../features/catalog/CategoriesPage.tsx?raw';
import citiesSource from '../../features/catalog/CitiesPage.tsx?raw';
import conversationReportsSource from '../../features/moderation/ConversationReportsPage.tsx?raw';
import notificationsSource from '../../features/notifications/NotificationsPage.tsx?raw';
import providerHelpersSource from '../../features/providers/providerHelpers.tsx?raw';
import reviewsSource from '../../features/moderation/ReviewsPage.tsx?raw';
import servicesSource from '../../features/catalog/ServicesPage.tsx?raw';
import usersSource from '../../features/users/UsersPage.tsx?raw';
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
    expect(auditPageSource).toContain('<Pagination');
    expect(auditPageSource).toContain('AdminAuditPhase');
    expect(auditPageSource).not.toContain('deleteAdminAudit');
    expect(auditPageSource).not.toContain('updateAdminAudit');
  });

  it('hides write controls from read-only admin roles', () => {
    expect(providerHelpersSource).toContain('AdminPermission.PROVIDERS_WRITE');
    expect(servicesSource).toContain('AdminPermission.SERVICES_WRITE');
    expect(categoriesSource).toContain('AdminPermission.CATALOG_WRITE');
    expect(citiesSource).toContain('AdminPermission.CATALOG_WRITE');
    expect(usersSource).toContain('AdminPermission.USERS_WRITE');
    expect(reviewsSource).toContain('AdminPermission.REVIEWS_WRITE');
    expect(conversationReportsSource).toContain(
      'AdminPermission.CONVERSATION_REPORTS_WRITE',
    );
    expect(notificationsSource).toContain('AdminPermission.NOTIFICATIONS_WRITE');
  });

  it('does not offer admin-account status actions to delegated administrators', () => {
    expect(usersSource).toContain("currentAdmin?.adminRole === 'SUPER_ADMIN'");
    expect(usersSource).toContain("user.role !== 'ADMIN'");
    expect(usersSource).toContain('user.id === currentAdmin?.id');
  });

  it('keeps the admin avatar local to the CSP policy', () => {
    expect(topbarSource).not.toContain('ui-avatars.com');
    expect(topbarSource).toContain('avatarInitial');
  });
});
