import { NavLink } from 'react-router-dom';
import {
  Crown,
  Inbox,
  LayoutGrid,
  LogOut,
  MapPin,
  Tag,
  UserCircle,
  Users,
} from 'lucide-react';

const links = [
  { to: '/', label: 'لوحة التحكم', icon: <LayoutGrid size={20} strokeWidth={1.5} />, end: true },
  { to: '/users', label: 'المستخدمون', icon: <UserCircle size={20} strokeWidth={1.5} /> },
  { to: '/providers', label: 'الموردون', icon: <Users size={20} strokeWidth={1.5} /> },
  { to: '/providers/applications', label: 'طلبات الموردين', icon: <Inbox size={20} strokeWidth={1.5} /> },
  { to: '/categories', label: 'فئات الموردين', icon: <Tag size={20} strokeWidth={1.5} /> },
  { to: '/cities', label: 'المدن والمناطق', icon: <MapPin size={20} strokeWidth={1.5} /> },
];

type SidebarProps = {
  isOpen: boolean;
  onNavigate: () => void;
  onLogout: () => void;
};

export function Sidebar({ isOpen, onNavigate, onLogout }: SidebarProps) {
  return (
    <aside className={`sidebar ${isOpen ? 'open' : ''}`}>
      <div className="brand" style={{ flexDirection: 'column', padding: '20px 0', gap: '8px' }}>
        <Crown size={36} color="var(--color-gold-200)" strokeWidth={1.5} />
        <div style={{ textAlign: 'center' }}>
          <strong style={{ fontSize: '38px', fontFamily: 'var(--font-family)' }}>أعرست</strong>
          <span style={{ fontSize: '13px', letterSpacing: '0.5px', marginTop: '2px' }}>لوحة الإدارة</span>
        </div>
      </div>
      <nav aria-label="التنقل الرئيسي" style={{ marginTop: '10px' }}>
        {links.map((link, index) => (
          <NavLink
            key={`${link.to}-${index}`}
            to={link.to}
            className={({ isActive }) => (isActive ? 'active' : undefined)}
            end={link.end ?? link.to === '/'}
            onClick={onNavigate}
            style={{ minHeight: '48px', padding: '0 16px', borderRadius: '10px' }}
          >
            <span className="nav-icon" aria-hidden="true" style={{ background: 'transparent', width: 'auto', marginRight: '-4px' }}>
              {link.icon}
            </span>
            <span style={{ fontWeight: 600, fontSize: '15px' }}>{link.label}</span>
          </NavLink>
        ))}
      </nav>
      <div className="sidebar__bottom">
        <div className="sidebar__note" style={{ minHeight: '130px', border: '1px solid rgba(199, 155, 63, 0.3)', backgroundImage: 'url("data:image/svg+xml,%3Csvg width=\'60\' height=\'60\' viewBox=\'0 0 60 60\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cpath d=\'M54.627 0l.83.83-54.627 54.627-.83-.83L54.627 0zm-5.858 0l.83.83-48.77 48.77-.83-.83L48.77 0zm-5.858 0l.83.83-42.91 42.91-.83-.83L42.91 0zm-5.858 0l.83.83-37.053 37.053-.83-.83L37.053 0z\' fill=\'%23c79b3f\' fill-opacity=\'0.1\' fill-rule=\'evenodd\'/%3E%3C/svg%3E")' }}>
          <Crown size={28} color="var(--color-gold-500)" style={{ marginBottom: '4px' }} strokeWidth={1.5} />
          <span style={{ fontSize: '18px', fontWeight: 900, color: 'var(--color-gold-200)' }}>أعرست</span>
          <strong style={{ fontSize: '14px', color: '#fff', maxWidth: '140px', lineHeight: 1.6 }}>نجعل مناسباتكم أكثر تميزاً</strong>
        </div>
        <button className="sidebar__logout" type="button" onClick={onLogout} style={{ fontWeight: 600, color: 'rgba(255, 248, 234, 0.78)', background: 'transparent', border: 'none', display: 'flex', gap: '8px', padding: '12px', justifyContent: 'center', transition: 'color 0.2s' }}>
          <LogOut size={18} />
          تسجيل الخروج
        </button>
      </div>
    </aside>
  );
}
