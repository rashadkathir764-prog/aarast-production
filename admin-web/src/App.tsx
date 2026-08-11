import { Navigate, Route, Routes } from 'react-router-dom';
import { RequireAdmin } from './auth/RequireAdmin';
import { RequireAdminPermission } from './auth/RequireAdminPermission';
import { AdminPermission } from './auth/adminPermissions';
import { AdminLayout } from './layout/AdminLayout';
import { LoginPage } from './pages/LoginPage';
import { DashboardPage } from './pages/DashboardPage';
import { ProviderApplicationsPage } from './pages/ProviderApplicationsPage';
import { ProviderApplicationDetailsPage } from './pages/ProviderApplicationDetailsPage';
import { ProvidersPage } from './pages/ProvidersPage';
import { ProviderDetailsPage } from './pages/ProviderDetailsPage';
import { CategoriesPage } from './pages/CategoriesPage';
import { CitiesPage } from './pages/CitiesPage';
import { UsersPage } from './pages/UsersPage';
import { UserDetailsPage } from './pages/UserDetailsPage';
import { ServicesPage } from './pages/ServicesPage';
import { ReviewsPage } from './pages/ReviewsPage';
import { NotificationsPage } from './pages/NotificationsPage';
import { ReportsPage } from './pages/ReportsPage';
import { ConversationReportsPage } from './pages/ConversationReportsPage';
import { NotFoundPage } from './pages/NotFoundPage';
import { AuditLogsPage } from './pages/AuditLogsPage';
import { ReferenceCatalogsPage } from './pages/ReferenceCatalogsPage';
import { AdministrativeAreasPage } from './pages/AdministrativeAreasPage';

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
              <ProviderApplicationsPage />
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
              <ProvidersPage />
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
