import { NavLink } from 'react-router-dom';

const links = [
  { to: '/', label: 'لوحة التحكم' },
  { to: '/providers/applications', label: 'طلبات الموردين' },
  { to: '/providers', label: 'إدارة الموردين' },
  { to: '/categories', label: 'الفئات' },
  { to: '/cities', label: 'المدن' },
  { to: '/users', label: 'المستخدمون' },
];

export function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="brand">
        <strong>أعّرست</strong>
        <span>لوحة الإدارة</span>
      </div>
      <nav>
        {links.map((link) => (
          <NavLink
            key={link.to}
            to={link.to}
            className={({ isActive }) => (isActive ? 'active' : undefined)}
            end={link.to === '/'}
          >
            {link.label}
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}
