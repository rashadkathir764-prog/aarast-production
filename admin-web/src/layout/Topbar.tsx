import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { Bell, Mail, Search, BarChart2, Plus, ChevronDown } from 'lucide-react';

type TopbarProps = {
  onMenuClick: () => void;
  onLogout: () => void;
};

export function Topbar({ onMenuClick, onLogout }: TopbarProps) {
  const { user } = useAuth();
  // Using a realistic avatar placeholder image
  const avatarUrl = 'https://ui-avatars.com/api/?name=Emad+K&background=fffaf3&color=6f0b31&size=100';

  return (
    <header className="topbar" style={{ borderRadius: '999px', padding: '8px 16px', background: 'rgba(255, 255, 255, 0.95)' }}>
      <button className="menu-button" type="button" onClick={onMenuClick}>
        ☰
      </button>
      <div className="topbar__profile" style={{ border: 'none', cursor: 'pointer', paddingInlineEnd: '20px' }}>
        <img src={avatarUrl} alt="Avatar" style={{ width: '44px', height: '44px', borderRadius: '50%', border: '2px solid #fff', boxShadow: '0 4px 12px rgba(0,0,0,0.05)', objectFit: 'cover' }} />
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <strong style={{ fontSize: '15px' }}>{user?.name ?? 'عماد'}</strong>
            <ChevronDown size={14} color="var(--color-muted)" />
          </div>
          <span style={{ fontSize: '12px', color: 'var(--color-muted)' }}>مدير النظام</span>
        </div>
      </div>
      <div className="topbar__utility">
        <button
          className="icon-button"
          type="button"
          aria-label="التنبيهات"
          style={{ position: 'relative' }}
        >
          <Bell size={20} strokeWidth={1.5} />
          {/* Notification Badge */}
          <span style={{ position: 'absolute', top: '4px', right: '4px', width: '16px', height: '16px', background: '#d7535d', color: '#fff', fontSize: '10px', borderRadius: '50%', display: 'grid', placeItems: 'center', fontWeight: 'bold', border: '2px solid #fff' }}>6</span>
        </button>
        <button
          className="icon-button"
          type="button"
          aria-label="الرسائل"
        >
          <Mail size={20} strokeWidth={1.5} />
        </button>
      </div>
      <label className="topbar__search" style={{ flex: 1, maxWidth: '400px' }}>
        <div style={{ position: 'relative' }}>
          <Search size={18} strokeWidth={1.5} color="var(--color-muted)" style={{ position: 'absolute', top: '50%', right: '14px', transform: 'translateY(-50%)' }} />
          <input placeholder="بحث سريع..." aria-label="بحث سريع" style={{ borderRadius: '999px', paddingInlineStart: '16px', paddingInlineEnd: '42px', background: 'rgba(248, 239, 227, 0.4)', border: '1px solid rgba(74, 7, 31, 0.05)', height: '44px' }} />
        </div>
      </label>
      <div className="topbar__actions" aria-label="اختصارات الإدارة" style={{ gap: '12px' }}>
        <Link className="button button--ghost" to="/reports" style={{ borderRadius: '999px', fontWeight: 700, gap: '8px' }}>
          <BarChart2 size={16} strokeWidth={2} />
          تصدير التقارير
        </Link>
        <Link className="button" to="/providers/new" style={{ borderRadius: '999px', background: 'var(--color-burgundy-900)', border: 'none', gap: '8px' }}>
          <Plus size={18} strokeWidth={2} />
          إضافة جديد
        </Link>
        <button className="topbar__logout" type="button" onClick={onLogout} style={{ display: 'none' }}>
          خروج
        </button>
      </div>
    </header>
  );
}
