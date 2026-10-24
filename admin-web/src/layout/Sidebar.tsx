import { type RefObject } from 'react';
import { LogOut, X } from 'lucide-react';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../features/auth/api';
import { hasAdminPermission } from '../features/auth/api';
import {
  adminNavigationGroups,
  type AdminNavigationItem,
} from './adminNavigation';
import { adminRoleLabel } from './adminRoles';
import { useQueueCounts, type QueueCounts } from './useQueueCounts';

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
  counts,
  onNavigate,
}: {
  link: AdminNavigationItem;
  pathname: string;
  counts: QueueCounts;
  onNavigate: () => void;
}) {
  const Icon = link.icon;
  const isActive = link.isActive(pathname);
  const count = link.count ? counts[link.count] : undefined;

  return (
    <Link
      to={link.route}
      className={`desk-side__link${isActive ? ' is-active' : ''}`}
      aria-current={isActive ? 'page' : undefined}
      onClick={onNavigate}
    >
      <Icon size={17} strokeWidth={2} aria-hidden="true" />
      <span className="desk-side__label">{link.label}</span>
      {count ? (
        <span
          className={`desk-side__count${link.hot ? ' is-hot' : ''}`}
          aria-label={`${count} ينتظر`}
        >
          {count}
        </span>
      ) : null}
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
  const counts = useQueueCounts(user, pathname);
  const name = user?.name?.trim() || 'الإدارة';
  // A local letter, never a remote avatar service (the CSP allows none).
  const avatarInitial = name.charAt(0);

  return (
    <aside
      id="admin-navigation-drawer"
      className={`desk-side${isOpen ? ' is-open' : ''}`}
      aria-label="التنقل الرئيسي"
    >
      <div className="desk-side__brand">
        <span className="desk-wordmark" aria-label="اعّرست">
          اعّرست<span className="desk-wordmark__dot" aria-hidden="true" />
        </span>
        <span className="desk-side__product">لوحة الإدارة</span>
        <button
          ref={closeButtonRef}
          className="desk-side__close"
          type="button"
          aria-label="إغلاق القائمة"
          onClick={onClose}
        >
          <X size={20} aria-hidden="true" />
        </button>
      </div>

      <nav className="desk-side__nav" aria-label="التنقل الرئيسي">
        {adminNavigationGroups.map((group) => {
          const visibleLinks = group.links.filter((link) =>
            hasAdminPermission(user, link.permission),
          );
          if (visibleLinks.length === 0) return null;

          return (
            <div className="desk-side__group" key={group.label}>
              <p className="desk-side__group-label">{group.label}</p>
              {visibleLinks.map((link) => (
                <NavigationLink
                  key={link.route}
                  link={link}
                  pathname={pathname}
                  counts={counts}
                  onNavigate={onNavigate}
                />
              ))}
            </div>
          );
        })}
      </nav>

      <div className="desk-side__me">
        <span className="desk-avatar" aria-hidden="true">
          {avatarInitial}
        </span>
        <strong className="desk-side__name">{name}</strong>
        {user?.adminRole ? (
          <span className="desk-side__role">{adminRoleLabel(user.adminRole)}</span>
        ) : null}
        <button
          className="desk-side__logout"
          type="button"
          aria-label="تسجيل الخروج"
          title="تسجيل الخروج"
          onClick={onLogout}
        >
          <LogOut size={16} aria-hidden="true" />
        </button>
      </div>
    </aside>
  );
}
