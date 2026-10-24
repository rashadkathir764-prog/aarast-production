import { type FormEvent, type RefObject, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { Menu, Search } from 'lucide-react';
import { AdminPermission, hasAdminPermission, useAuth } from '../features/auth/api';
import { resolveAdminLocation } from './adminNavigation';

type TopbarProps = {
  isMenuOpen: boolean;
  menuButtonRef: RefObject<HTMLButtonElement>;
  onMenuClick: () => void;
};

/**
 * akit `desk` top row: «لوحة الإدارة / …» and the search box. The search
 * opens the users list by name or number until «ابحث برقم» (n05) is built.
 */
export function Topbar({
  isMenuOpen,
  menuButtonRef,
  onMenuClick,
}: TopbarProps) {
  const { user } = useAuth();
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const [query, setQuery] = useState('');
  const location = resolveAdminLocation(pathname);
  const canSearch = hasAdminPermission(user, AdminPermission.USERS_READ);
  const last = location.crumb.length - 1;

  function search(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const term = query.trim();
    if (!term) return;
    navigate(`/users?search=${encodeURIComponent(term)}`);
  }

  return (
    <header className="desk-top" dir="rtl">
      <button
        ref={menuButtonRef}
        className="desk-top__menu"
        type="button"
        onClick={onMenuClick}
        aria-label={isMenuOpen ? 'إغلاق القائمة' : 'فتح القائمة'}
        aria-controls="admin-navigation-drawer"
        aria-expanded={isMenuOpen}
      >
        <Menu size={22} aria-hidden="true" />
      </button>

      <nav className="desk-top__crumb" aria-label="مسار الصفحة" aria-live="polite">
        <span>لوحة الإدارة</span>
        {location.crumb.map((part, index) => (
          <span key={`${part}-${index}`}>
            {' / '}
            {location.isDetail && index === last - 1 ? (
              <Link to={location.route}>{part}</Link>
            ) : (
              <span aria-current={index === last ? 'page' : undefined}>{part}</span>
            )}
          </span>
        ))}
      </nav>

      {canSearch ? (
        <form className="desk-search" role="search" onSubmit={search}>
          <Search size={16} aria-hidden="true" />
          <input
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="ابحث برقم أو اسم…"
            aria-label="ابحث برقم أو اسم"
          />
        </form>
      ) : null}
    </header>
  );
}
