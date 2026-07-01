import { useAuth } from '../auth/AuthProvider';
import { Menu } from 'lucide-react';

type TopbarProps = {
  onMenuClick: () => void;
  onLogout: () => void;
};

export function Topbar({ onMenuClick }: TopbarProps) {
  const { user } = useAuth();
  const avatarUrl = 'https://ui-avatars.com/api/?name=Admin&background=4A1525&color=ffffff&size=100';

  return (
    <header
      className="topbar"
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '10px 24px',
        background: '#ffffff',
        borderRadius: '100px',
        border: '1px solid #EFECE6',
        boxShadow: '0px 2px 8px rgba(0, 0, 0, 0.015)',
        margin: '16px 24px 0 24px',
        boxSizing: 'border-box',
      }}
      dir="rtl"
    >
      <button
        className="menu-button"
        type="button"
        onClick={onMenuClick}
        aria-label="فتح القائمة"
        style={{
          background: 'none',
          border: 'none',
          cursor: 'pointer',
          color: '#4A1525',
          padding: 4,
        }}
      >
        <Menu size={22} strokeWidth={1.8} />
      </button>

      <div
        className="topbar__profile"
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          marginInlineStart: 'auto',
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', textAlign: 'right' }}>
          <strong style={{ fontSize: '13px', color: '#2B2A2A', fontWeight: 600 }}>
            {user?.name ?? 'مدير النظام'}
          </strong>
          <span style={{ fontSize: '11px', color: '#8A7A81', marginTop: '1px' }}>
            مدير النظام
          </span>
        </div>

        <img
          src={avatarUrl}
          alt="Admin avatar"
          style={{
            width: '38px',
            height: '38px',
            borderRadius: '50%',
            objectFit: 'cover',
            border: '1px solid #EFECE6',
          }}
        />
      </div>
    </header>
  );
}
