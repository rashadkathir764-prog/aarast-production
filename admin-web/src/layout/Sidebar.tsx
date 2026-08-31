import { type RefObject } from 'react';
import { LogOut, ShieldCheck, X } from 'lucide-react';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../features/auth/api';
import { hasAdminPermission } from '../features/auth/api';
import {
  adminNavigationGroups,
  type AdminNavigationItem,
} from './adminNavigation';

type SidebarProps = {
  closeButtonRef: RefObject<HTMLButtonElement>;
  isOpen: boolean;
  onClose: () => void;
  onNavigate: () => void;
  onLogout: () => void;
};

function NavigationLink({
  link,
  pathname,
  onNavigate,
}: {
  link: AdminNavigationItem;
  pathname: string;
  onNavigate: () => void;
}) {
  const Icon = link.icon;
  const isActive = link.isActive(pathname);

  return (
    <Link
      to={link.route}
      className={isActive ? 'active' : undefined}
      aria-current={isActive ? 'page' : undefined}
      onClick={onNavigate}
    >
      <span className="nav-icon" aria-hidden="true">
        <Icon size={20} strokeWidth={1.8} />
      </span>
      <span>{link.label}</span>
    </Link>
  );
}

export function Sidebar({
  closeButtonRef,
  isOpen,
  onClose,
  onNavigate,
  onLogout,
}: SidebarProps) {
  const { user } = useAuth();
  const { pathname } = useLocation();

  return (
    <aside
      id="admin-navigation-drawer"
      className={`sidebar ${isOpen ? 'open' : ''}`}
      aria-label="التنقل الرئيسي"
    >
      <div className="brand">
        <span className="brand__mark" aria-hidden="true">
          <ShieldCheck size={22} strokeWidth={1.8} />
        </span>
        <div>
          <strong>أعرست</strong>
          <span>لوحة الإدارة</span>
        </div>
        <button
          ref={closeButtonRef}
          className="sidebar__close"
          type="button"
          aria-label="إغلاق القائمة"
          onClick={onClose}
        >
          <X size={20} strokeWidth={1.8} aria-hidden="true" />
        </button>
      </div>

      <nav aria-label="التنقل الرئيسي">
        {adminNavigationGroups.map((group) => {
          const visibleLinks = group.links.filter((link) =>
            hasAdminPermission(user, link.permission),
          );
          if (visibleLinks.length === 0) return null;

          return (
            <div className="sidebar__group" key={group.label}>
              <p className="sidebar__group-label">{group.label}</p>
              {visibleLinks.map((link) => (
                <NavigationLink
                  key={link.route}
                  link={link}
                  pathname={pathname}
                  onNavigate={onNavigate}
                />
              ))}
            </div>
          );
        })}
      </nav>

      <div className="sidebar__bottom">
        <p className="sidebar__note">
          مساحة تشغيلية هادئة لمتابعة الطلبات والكتالوج وسلامة الحسابات.
        </p>
        <button className="sidebar__logout" type="button" onClick={onLogout}>
          <LogOut size={18} aria-hidden="true" />
          تسجيل الخروج
        </button>
      </div>
    </aside>
  );
}
