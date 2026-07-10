import { describe, expect, it } from 'vitest';
import appSource from '../App.tsx?raw';
import adminApiSource from '../api/admin.ts?raw';
import authApiSource from '../api/auth.ts?raw';
import sidebarSource from '../layout/Sidebar.tsx?raw';
import auditPageSource from '../pages/AuditLogsPage.tsx?raw';
import categoriesSource from '../pages/CategoriesPage.tsx?raw';
import citiesSource from '../pages/CitiesPage.tsx?raw';
import conversationReportsSource from '../pages/ConversationReportsPage.tsx?raw';
import notificationsSource from '../pages/NotificationsPage.tsx?raw';
import providerHelpersSource from '../pages/providerHelpers.tsx?raw';
import reviewsSource from '../pages/ReviewsPage.tsx?raw';
import servicesSource from '../pages/ServicesPage.tsx?raw';
import usersSource from '../pages/UsersPage.tsx?raw';

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
});
