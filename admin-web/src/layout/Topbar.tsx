import { useAuth } from '../auth/AuthProvider';
import { Bell, Mail, Search, BarChart2, Plus, ChevronDown } from 'lucide-react';

type TopbarProps = {
  onMenuClick: () => void;
  onLogout: () => void;
};

export function Topbar({ onMenuClick, onLogout }: TopbarProps) {
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
        style={{
          display: 'none',
          background: 'none',
          border: 'none',
          fontSize: '20px',
          cursor: 'pointer',
          color: '#4A1525',
        }}
      >
        ☰
      </button>

      <div className="topbar__actions" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        <button
          type="button"
          disabled
          title="إضافة مورد جديد تحتاج POST /admin/providers قبل التفعيل"
          style={{
            borderRadius: '999px',
            background: '#4A1525',
            color: '#ffffff',
            padding: '8px 20px',
            fontSize: '13px',
            fontWeight: 600,
            display: 'inline-flex',
            alignItems: 'center',
            gap: '6px',
            border: 'none',
            opacity: 0.55,
            cursor: 'not-allowed',
            boxShadow: '0px 2px 4px rgba(74, 21, 37, 0.1)',
          }}
        >
          <Plus size={16} strokeWidth={2.5} />
          <span>إضافة مورد</span>
        </button>

        <button
          type="button"
          disabled
          title="تصدير التقارير يحتاج endpoint إداري حقيقي قبل التفعيل"
          style={{
            borderRadius: '999px',
            background: '#ffffff',
            color: '#4A1525',
            border: '1px solid #EFECE6',
            padding: '8px 20px',
            fontSize: '13px',
            fontWeight: 600,
            display: 'inline-flex',
            alignItems: 'center',
            gap: '6px',
            opacity: 0.55,
            cursor: 'not-allowed',
          }}
        >
          <BarChart2 size={15} strokeWidth={2} style={{ transform: 'rotate(90deg)' }} />
          <span>تصدير التقارير</span>
        </button>
      </div>

      <div className="topbar__search" style={{ flex: 1, maxWidth: '460px', position: 'relative', margin: '0 24px' }}>
        <input
          placeholder="بحث سريع..."
          aria-label="بحث سريع"
          style={{
            width: '100%',
            height: '40px',
            borderRadius: '999px',
            paddingLeft: '16px',
            paddingRight: '42px',
            background: '#F5F4F0',
            border: 'none',
            fontSize: '13px',
            color: '#2B2A2A',
            outline: 'none',
            boxSizing: 'border-box',
            textAlign: 'right',
          }}
        />
        <Search
          size={16}
          color="#8A7A81"
          style={{
            position: 'absolute',
            top: '50%',
            right: '16px',
            transform: 'translateY(-50%)',
            pointerEvents: 'none',
          }}
        />
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '24px' }}>
        <div className="topbar__utility" style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
          <button
            type="button"
            disabled
            aria-label="الرسائل الإدارية غير مفعلة"
            title="لا يوجد نظام رسائل إداري حاليا"
            style={{ background: 'none', border: 'none', color: '#4A1525', padding: 4, opacity: 0.45, cursor: 'not-allowed' }}
          >
            <Mail size={20} strokeWidth={1.8} />
          </button>

          <button
            type="button"
            disabled
            aria-label="الإشعارات الإدارية غير مفعلة"
            title="إرسال وإدارة الإشعارات يحتاج Admin API"
            style={{ background: 'none', border: 'none', color: '#4A1525', padding: 4, opacity: 0.45, cursor: 'not-allowed' }}
          >
            <Bell size={20} strokeWidth={1.8} />
          </button>
        </div>

        <div
          className="topbar__profile"
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
          }}
        >
          <ChevronDown size={14} color="#8A7A81" />

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
      </div>

      <button onClick={onLogout} style={{ display: 'none' }}>
        خروج
      </button>
    </header>
  );
}
