import { Navigate, Route, Routes } from 'react-router-dom';
import { RequireAdmin } from './auth/RequireAdmin';
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
import { NotFoundPage } from './pages/NotFoundPage';

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
        <Route index element={<DashboardPage />} />
        <Route
          path="providers/applications"
          element={<ProviderApplicationsPage />}
        />
        <Route
          path="providers/applications/:id"
          element={<ProviderApplicationDetailsPage />}
        />
        <Route path="providers" element={<ProvidersPage />} />
        <Route path="providers/new" element={<Navigate to="/providers/applications" replace />} />
        <Route path="providers/:id" element={<ProviderDetailsPage />} />
        <Route path="cities" element={<CitiesPage />} />
        <Route path="cities/new" element={<Navigate to="/cities" replace />} />
        <Route path="categories" element={<CategoriesPage />} />
        <Route path="users" element={<UsersPage />} />
        <Route path="users/:id" element={<UserDetailsPage />} />
        <Route path="services" element={<ServicesPage />} />
        <Route path="services/new" element={<Navigate to="/services" replace />} />
        <Route path="reviews" element={<ReviewsPage />} />
        <Route path="notifications" element={<NotificationsPage />} />
        <Route path="reports" element={<ReportsPage />} />
      </Route>
      <Route path="/admin" element={<Navigate to="/" replace />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  );
}
