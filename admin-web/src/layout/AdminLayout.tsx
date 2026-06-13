import { useState } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';

export function AdminLayout() {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const { logout } = useAuth();
  const navigate = useNavigate();

  function handleLogout() {
    logout();
    navigate('/login', { replace: true });
  }

  return (
    <div className="admin-shell">
      <Sidebar
        isOpen={isSidebarOpen}
        onNavigate={() => setIsSidebarOpen(false)}
        onLogout={handleLogout}
      />
      <button
        className={`sidebar-scrim ${isSidebarOpen ? 'visible' : ''}`}
        type="button"
        aria-label="إغلاق القائمة"
        onClick={() => setIsSidebarOpen(false)}
      />
      <main className="admin-main">
        <Topbar
          onMenuClick={() => setIsSidebarOpen(true)}
          onLogout={handleLogout}
        />
        <div className="content-frame">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
