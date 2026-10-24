import { NavLink } from 'react-router-dom';

/**
 * The four catalog pages behind the one «الكتالوج» link. Not drawn in the
 * designs (a08, a09 show one page each); without it the cities and the
 * administrative areas, which have no design, could not be reached.
 */
const TABS = [
  { to: '/categories', label: 'الأقسام' },
  { to: '/reference-catalogs', label: 'الكتالوجات' },
  { to: '/cities', label: 'المدن' },
  { to: '/administrative-areas', label: 'المحافظات والمديريات' },
];

export function CatalogTabs() {
  return (
    <nav className="desk-subnav" aria-label="صفحات الكتالوج">
      {TABS.map((tab) => (
        <NavLink
          key={tab.to}
          to={tab.to}
          className={({ isActive }) => `desk-subnav__link${isActive ? ' is-active' : ''}`}
        >
          {tab.label}
        </NavLink>
      ))}
    </nav>
  );
}
