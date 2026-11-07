import { useEffect, useRef, useState } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../features/auth/api';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';
import { DeskRetry } from '../design_system/Desk';
import '../styles/desk.css';

export function AdminLayout() {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const menuButtonRef = useRef<HTMLButtonElement>(null);
  const drawerCloseButtonRef = useRef<HTMLButtonElement>(null);
  const adminMainRef = useRef<HTMLElement>(null);
  const shouldRestoreMenuFocusRef = useRef(false);
  const { logout } = useAuth();
  const navigate = useNavigate();

  function openSidebar() {
    shouldRestoreMenuFocusRef.current = true;
    setIsSidebarOpen(true);
  }

  function closeSidebar() {
    setIsSidebarOpen(false);
  }

  useEffect(() => {
    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        closeSidebar();
      }
    }

    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, []);

  useEffect(() => {
    adminMainRef.current?.toggleAttribute('inert', isSidebarOpen);
  }, [isSidebarOpen]);

  useEffect(() => {
    if (isSidebarOpen) {
      const animationFrame = window.requestAnimationFrame(() => {
        drawerCloseButtonRef.current?.focus();
      });
      return () => window.cancelAnimationFrame(animationFrame);
    }

    if (shouldRestoreMenuFocusRef.current) {
      menuButtonRef.current?.focus();
      shouldRestoreMenuFocusRef.current = false;
    }

    return undefined;
  }, [isSidebarOpen]);

  const [logoutError, setLogoutError] = useState<string | null>(null);

  async function handleLogout() {
    setLogoutError(null);
    try {
      await logout();
    } catch (error) {
      // RA-AD-06: the session is still open on this browser; it is said, and
      // the panel stays until a logout goes through.
      const reason = error instanceof Error ? error.message : '';
      setLogoutError(`ما سجّلنا خروجك، والجلسة ما زالت مفتوحة على هذا المتصفح. ${reason}`.trim());
      closeSidebar();
      return;
    }
    navigate('/login', { replace: true });
  }

  return (
    <div className="desk-shell" dir="rtl">
      <Sidebar
        closeButtonRef={drawerCloseButtonRef}
        isOpen={isSidebarOpen}
        onClose={closeSidebar}
        onNavigate={closeSidebar}
        onLogout={handleLogout}
      />

      <button
        className={`desk-scrim${isSidebarOpen ? ' is-visible' : ''}`}
        type="button"
        aria-label="إغلاق القائمة"
        aria-hidden={!isSidebarOpen}
        tabIndex={isSidebarOpen ? 0 : -1}
        onClick={closeSidebar}
      />

      <main
        ref={adminMainRef}
        className="desk-main"
        aria-hidden={isSidebarOpen}
      >
        <Topbar
          isMenuOpen={isSidebarOpen}
          menuButtonRef={menuButtonRef}
          onMenuClick={() => (isSidebarOpen ? closeSidebar() : openSidebar())}
        />
        <div className="desk-content">
          {logoutError ? (
            <DeskRetry message={logoutError} onRetry={() => void handleLogout()} />
          ) : null}
          <Outlet />
        </div>
      </main>
    </div>
  );
}
