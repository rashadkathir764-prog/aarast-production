import { useState } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';

export function AdminLayout() {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const { logout } = useAuth();
  const navigate = useNavigate();

  async function handleLogout() {
    try {
      await logout();
    } finally {
      navigate('/login', { replace: true });
    }
  }

  return (
    <div 
      className="admin-shell"
      style={{
        display: 'flex',
        minHeight: '100vh', // يضمن أن الصفحة تأخذ كامل ارتفاع الشاشة كأقل تقدير
        width: '100%',
        backgroundColor: '#FCFBF7',
        alignItems: 'stretch', // يضمن تمدد الشريط الجانبي والمحتوى معاً بنفس الطول تماماً
        direction: 'rtl'
      }}
      dir="rtl"
    >
      {/* حقن تنسيق داخلي سريع لحماية الهيكل من أي تضارب ملفات CSS خارجية */}
      <style>{`
        .admin-shell > aside, .admin-shell > div {
          height: auto !important;
          min-height: 100% !important;
        }
      `}</style>

      {/* الشريط الجانبي الأيمن */}
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
        style={{ border: 'none', display: isSidebarOpen ? 'block' : 'none' }}
      />
      
      {/* المنطقة الرئيسية اليسرى */}
      <main 
        className="admin-main"
        style={{
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          minWidth: 0, // تمنع تمدد العناصر أو خروج الجداول عن الشاشة
          backgroundColor: '#FCFBF7'
        }}
      >
        {/* الشريط العلوي */}
        <Topbar
          onMenuClick={() => setIsSidebarOpen(true)}
          onLogout={handleLogout}
        />
        
        {/* إطار محتوى الصفحات الداخلي */}
        <div className="content-frame" style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
          <Outlet />
        </div>
      </main>
    </div>
  );
}
