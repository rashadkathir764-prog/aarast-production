import { Navigate, Route, Routes } from 'react-router-dom';
import { RequireAdmin } from './features/auth/api';
import { RequireAdminPermission } from './features/auth/api';
import { AdminPermission } from './features/auth/api';
import { AdminLayout } from './layout/AdminLayout';
import { LoginPage } from './features/auth/LoginPage';
import { DashboardPage } from './features/dashboard/DashboardPage';
import { getStats } from './features/dashboard/api';
import { getCategories, getCities } from './features/catalog/api';
import { ProviderApplicationsPage } from './features/providers/ProviderApplicationsPage';
import { ProviderApplicationDetailsPage } from './features/providers/ProviderApplicationDetailsPage';
import { ProvidersPage } from './features/providers/ProvidersPage';
import { ProviderDetailsPage } from './features/providers/ProviderDetailsPage';
import { CategoriesPage } from './features/catalog/CategoriesPage';
import { CitiesPage } from './features/catalog/CitiesPage';
import { UsersPage } from './features/users/UsersPage';
import { UserDetailsPage } from './features/users/UserDetailsPage';
import { ServicesPage } from './features/catalog/ServicesPage';
import { ReviewsPage } from './features/moderation/ReviewsPage';
import { NotificationsPage } from './features/notifications/NotificationsPage';
import { ReportsPage } from './features/dashboard/ReportsPage';
import { ConversationReportsPage } from './features/moderation/ConversationReportsPage';
import { NotFoundPage } from './platform/routing/NotFoundPage';
import { AuditLogsPage } from './features/audit/AuditLogsPage';
import { ReferenceCatalogsPage } from './features/catalog/ReferenceCatalogsPage';
import { AdministrativeAreasPage } from './features/catalog/AdministrativeAreasPage';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <RequireAdmin>
            <AdminLayout />
          </RequireAdmin>
        }
      >
        <Route
          index
          element={
            <RequireAdminPermission permission={AdminPermission.DASHBOARD_READ}>
              <DashboardPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="providers/applications"
          element={
            <RequireAdminPermission permission={AdminPermission.PROVIDERS_READ}>
              <ProviderApplicationsPage
                getCategories={getCategories}
                getCities={getCities}
                getStats={getStats}
              />
            </RequireAdminPermission>
          }
        />
        <Route
          path="providers/applications/:id"
          element={
            <RequireAdminPermission permission={AdminPermission.PROVIDERS_READ}>
              <ProviderApplicationDetailsPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="providers"
          element={
            <RequireAdminPermission permission={AdminPermission.PROVIDERS_READ}>
              <ProvidersPage
                getCategories={getCategories}
                getCities={getCities}
              />
            </RequireAdminPermission>
          }
        />
        <Route
          path="providers/new"
          element={
            <RequireAdminPermission permission={AdminPermission.PROVIDERS_READ}>
              <Navigate to="/providers/applications" replace />
            </RequireAdminPermission>
          }
        />
        <Route
          path="providers/:id"
          element={
            <RequireAdminPermission permission={AdminPermission.PROVIDERS_READ}>
              <ProviderDetailsPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="cities"
          element={
            <RequireAdminPermission permission={AdminPermission.CATALOG_READ}>
              <CitiesPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="cities/new"
          element={
            <RequireAdminPermission permission={AdminPermission.CATALOG_READ}>
              <Navigate to="/cities" replace />
            </RequireAdminPermission>
          }
        />
        <Route
          path="categories"
          element={
            <RequireAdminPermission permission={AdminPermission.CATALOG_READ}>
              <CategoriesPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="reference-catalogs"
          element={
            <RequireAdminPermission permission={AdminPermission.CATALOG_READ}>
              <ReferenceCatalogsPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="administrative-areas"
          element={
            <RequireAdminPermission permission={AdminPermission.CATALOG_READ}>
              <AdministrativeAreasPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="users"
          element={
            <RequireAdminPermission permission={AdminPermission.USERS_READ}>
              <UsersPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="users/:id"
          element={
            <RequireAdminPermission permission={AdminPermission.USERS_READ}>
              <UserDetailsPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="services"
          element={
            <RequireAdminPermission permission={AdminPermission.SERVICES_READ}>
              <ServicesPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="services/new"
          element={
            <RequireAdminPermission permission={AdminPermission.SERVICES_READ}>
              <Navigate to="/services" replace />
            </RequireAdminPermission>
          }
        />
        <Route
          path="reviews"
          element={
            <RequireAdminPermission permission={AdminPermission.REVIEWS_READ}>
              <ReviewsPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="conversation-reports"
          element={
            <RequireAdminPermission
              permission={AdminPermission.CONVERSATION_REPORTS_READ}
            >
              <ConversationReportsPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="notifications"
          element={
            <RequireAdminPermission permission={AdminPermission.NOTIFICATIONS_READ}>
              <NotificationsPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="reports"
          element={
            <RequireAdminPermission permission={AdminPermission.REPORTS_READ}>
              <ReportsPage />
            </RequireAdminPermission>
          }
        />
        <Route
          path="audit-logs"
          element={
            <RequireAdminPermission permission={AdminPermission.AUDIT_READ}>
              <AuditLogsPage />
            </RequireAdminPermission>
          }
        />
      </Route>
      <Route path="/admin" element={<Navigate to="/" replace />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}
