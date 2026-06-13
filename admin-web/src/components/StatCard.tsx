import { ReactNode } from 'react';

type StatCardProps = {
  title: string;
  value: number | string;
  hint?: string;
  trend?: number;
  icon?: ReactNode;
  tone?: 'default' | 'gold' | 'success' | 'warning' | 'danger' | 'info';
};

export function StatCard({
  title,
  value,
  hint,
  trend,
  icon,
  tone = 'default',
}: StatCardProps) {
  
  let subtext = "";
  if (title.includes("الإيرادات")) subtext = "ر.س";
  if (title.includes("المدن")) subtext = "مدن نشطة";
  if (title.includes("المعلقة")) subtext = "طلب قيد المراجعة";

  const isDanger = tone === 'danger' || trend === -8;
  const iconBg = isDanger ? '#FFF0F2' : '#FFF9E6';
  const iconColor = isDanger ? '#D32F2F' : '#C79B3F';

  return (
    <article 
      style={{ 
        display: 'flex', 
        flexDirection: 'column', 
        alignItems: 'flex-start', // محاذاة العناصر إلى اليمين في بيئة RTL
        justifyContent: 'center',
        padding: '16px', 
        background: '#ffffff', 
        borderRadius: '14px', 
        border: '1px solid #EFECE6', 
        position: 'relative',
        textAlign: 'right',
        minHeight: '140px',
        boxShadow: '0px 1px 3px rgba(0, 0, 0, 0.01)',
        boxSizing: 'border-box'
      }}
    >
      {/* الأيقونة في اليمين العلوي تماماً كما في التصميم المستهدف */}
      {icon && (
        <div style={{ 
          position: 'absolute',
          top: '16px',
          right: '16px',
          width: '32px', 
          height: '32px', 
          borderRadius: '8px', 
          background: iconBg, 
          color: iconColor,
          display: 'grid', 
          placeItems: 'center'
        }}>
          {icon}
        </div>
      )}

      {/* عنوان الكارت - مزاح لليسار قليلاً ليتناسق مع وجود الأيقونة في اليمين */}
      <span style={{ fontSize: '13px', fontWeight: 500, color: '#8A7A81', marginBottom: '4px', paddingRight: icon ? '40px' : '0' }}>
        {title}
      </span>

      {/* الرقم الإجمالي الكبير */}
      <strong style={{ fontSize: '26px', fontWeight: 700, color: '#4A1525', lineHeight: 1.1, paddingRight: icon ? '40px' : '0' }}>
        {value}
      </strong>

      {/* النص المساعد تحت الرقم مباشرة */}
      {subtext && (
        <span style={{ fontSize: '11px', color: '#A1979C', marginTop: '4px', fontWeight: 500, paddingRight: icon ? '40px' : '0' }}>
          {subtext}
        </span>
      )}
      
      {/* السطر السفلي الخاص بنسبة الصعود/الهبوط */}
      <div style={{ marginTop: '12px', width: '100%', display: 'flex', justifyContent: 'flex-start' }}>
        {trend !== undefined ? (
          <div style={{ 
            display: 'flex', 
            alignItems: 'center', 
            gap: '4px', 
            fontSize: '11px', 
            fontWeight: 600, 
            color: trend >= 0 ? '#2D8A5D' : '#D32F2F',
            flexDirection: 'row'
          }}>
            <span>{trend >= 0 ? '▲' : '▼'}</span>
            <span>{Math.abs(trend)}%</span>
            <span style={{ color: '#A1979C', fontWeight: 400 }}>{hint}</span>
          </div>
        ) : (
          <span style={{ color: '#D1C9CC', fontSize: '14px' }}>—</span>
        )}
      </div>
    </article>
  );
}