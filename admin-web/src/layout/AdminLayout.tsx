import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';

export function AdminLayout() {
  return (
    <div className="admin-shell">
      <Sidebar />
      <main className="admin-main">
        <Topbar />
        <Outlet />
      </main>
    </div>
  );
}
