import { type RefObject } from 'react';
import { Link } from 'react-router-dom';
import { Menu } from 'lucide-react';
import { useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { resolveAdminLocation } from './adminNavigation';

type TopbarProps = {
  isMenuOpen: boolean;
  menuButtonRef: RefObject<HTMLButtonElement>;
  onMenuClick: () => void;
};

export function Topbar({
  isMenuOpen,
  menuButtonRef,
  onMenuClick,
}: TopbarProps) {
  const { user } = useAuth();
  const { pathname } = useLocation();
  const avatarInitial = (user?.name?.trim().charAt(0) || 'A').toUpperCase();
  const location = resolveAdminLocation(pathname);

  return (
    <header className="topbar" dir="rtl">
      <button
        ref={menuButtonRef}
        className="menu-button"
        type="button"
        onClick={onMenuClick}
        aria-label={isMenuOpen ? 'إغلاق القائمة' : 'فتح القائمة'}
        aria-controls="admin-navigation-drawer"
        aria-expanded={isMenuOpen}
      >
        <Menu size={22} strokeWidth={1.8} aria-hidden="true" />
      </button>

      <nav className="topbar__location" aria-label="مسار الصفحة" aria-live="polite">
        <span>لوحة الإدارة / {location.group}</span>
        {location.isDetail ? (
          <div className="topbar__breadcrumb">
            <Link to={location.route}>{location.parentTitle}</Link>
            <span aria-hidden="true">/</span>
            <strong aria-current="page">{location.title}</strong>
          </div>
        ) : (
          <strong aria-current="page">{location.title}</strong>
        )}
      </nav>

      <div className="topbar__profile">
        <div>
          <strong>{user?.name ?? 'مدير النظام'}</strong>
          <span>مدير النظام</span>
        </div>
        <div className="topbar__avatar" role="img" aria-label="صورة مدير النظام">
          {avatarInitial}
        </div>
      </div>
    </header>
  );
}
