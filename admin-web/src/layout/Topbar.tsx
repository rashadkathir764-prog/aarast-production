import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';
import { Bell, Mail, Search, BarChart2, Plus, ChevronDown } from 'lucide-react';

type TopbarProps = {
  onMenuClick: () => void;
  onLogout: () => void;
};

export function Topbar({ onMenuClick, onLogout }: TopbarProps) {
  const { user } = useAuth();
  
  // صورة رمزية دائرية نظيفة متناسقة مع ألوان الهوية
  const avatarUrl = 'https://ui-avatars.com/api/?name=Emad+K&background=4A1525&color=ffffff&size=100';

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
        margin: '16px 24px 0 24px', // مسافة هوامش خارجية لتبدو طائرة ومنفصلة بفخامة
        boxSizing: 'border-box'
      }}
      dir="rtl"
    >
      {/* زر الهامبرغر للموبايل (يظهر فقط في الشاشات الصغيرة) */}
      <button 
        className="menu-button" 
        type="button" 
        onClick={onMenuClick}
        style={{
          display: 'none', // مخفي افتراضياً على الديسكتوب لعدم تشويه المظهر
          background: 'none',
          border: 'none',
          fontSize: '20px',
          cursor: 'pointer',
          color: '#4A1525'
        }}
      >
        ☰
      </button>

      {/* 1. اليمين: أزرار الإجراءات واختصارات الإدارة */}
      <div className="topbar__actions" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        <Link 
          to="/providers/new" 
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
            textDecoration: 'none',
            boxShadow: '0px 2px 4px rgba(74, 21, 37, 0.1)'
          }}
        >
          <Plus size={16} strokeWidth={2.5} />
          <span>إضافة جديد</span>
        </Link>

        <Link 
          to="/reports" 
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
            textDecoration: 'none'
          }}
        >
          <BarChart2 size={15} strokeWidth={2} style={{ transform: 'rotate(90deg)' }} />
          <span>تصدير التقارير</span>
        </Link>
      </div>

      {/* 2. المنتصف: صندوق البحث الذكي والواسع بدون أي اختناق للنصوص */}
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
            textAlign: 'right'
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
            pointerEvents: 'none' 
          }} 
        />
      </div>

      {/* 3. اليسار: الأيقونات والملف الشخصي للمدير مرتبة تتابعياً للـ RTL */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '24px' }}>
        
        {/* أيقونات التنبيهات والمراسلات */}
        <div className="topbar__utility" style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
          {/* أيقونة الرسائل */}
          <button style={{ background: 'none', border: 'none', color: '#4A1525', cursor: 'pointer', padding: 4 }}>
            <Mail size={20} strokeWidth={1.8} />
          </button>

          {/* أيقونة التنبيهات مع الشارة الحمراء المطابقة */}
          <button style={{ background: 'none', border: 'none', color: '#4A1525', cursor: 'pointer', padding: 4, position: 'relative' }}>
            <Bell size={20} strokeWidth={1.8} />
            <span style={{ 
              position: 'absolute', 
              top: '1px', 
              right: '1px', 
              width: '15px', 
              height: '15px', 
              background: '#D32F2F', 
              color: '#fff', 
              fontSize: '9px', 
              borderRadius: '50%', 
              display: 'grid', 
              placeItems: 'center', 
              fontWeight: 700, 
              border: '1.5px solid #fff' 
            }}>
              6
            </span>
          </button>
        </div>

        {/* كتل الملف الشخصي (السهم المنسدل ثم الاسم ثم الصورة الدائرية في أقصى اليسار) */}
        <div 
          className="topbar__profile" 
          style={{ 
            display: 'flex', 
            alignItems: 'center', 
            gap: '10px', 
            cursor: 'pointer' 
          }}
        >
          <ChevronDown size={14} color="#8A7A81" />
          
          <div style={{ display: 'flex', flexDirection: 'column', textAlign: 'right' }}>
            <strong style={{ fontSize: '13px', color: '#2B2A2A', fontWeight: 600 }}>
              {user?.name ?? 'عماد كثير'}
            </strong>
            <span style={{ fontSize: '11px', color: '#8A7A81', marginTop: '1px' }}>
              مدير النظام
            </span>
          </div>

          <img 
            src={avatarUrl} 
            alt="Avatar" 
            style={{ 
              width: '38px', 
              height: '38px', 
              borderRadius: '50%', 
              objectFit: 'cover',
              border: '1px solid #EFECE6'
            }} 
          />
        </div>

      </div>

      {/* زر تسجيل الخروج المخفي احتياطياً */}
      <button onClick={onLogout} style={{ display: 'none' }}>خروج</button>
    </header>
  );
}