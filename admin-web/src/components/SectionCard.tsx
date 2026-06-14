import { ReactNode } from 'react';

type SectionCardProps = {
  title?: string;
  subtitle?: string;
  actions?: ReactNode;
  children: ReactNode;
  className?: string;
};

export function SectionCard({
  title,
  subtitle,
  actions,
  children,
  className,
}: SectionCardProps) {
  return (
    <section 
      className={['section-card', className].filter(Boolean).join(' ')}
      style={{
        background: '#ffffff',
        borderRadius: '14px',
        border: '1px solid #EFECE6',
        padding: '20px',
        display: 'flex',
        flexDirection: 'column',
        gap: '16px',
        boxShadow: '0px 1px 3px rgba(0, 0, 0, 0.01)',
        width: '100%',
        boxSizing: 'border-box'
      }}
    >
      {/* الهيدر الخاص بالكرت: يحتوي على العنوان في اليمين والإجراءات في اليسار */}
      {title || subtitle || actions ? (
        <div 
          className="section-card__header"
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            width: '100%',
            borderBottom: subtitle ? 'none' : '1px solid transparent' // حماية الهيكل
          }}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
            {title && (
              <h2 style={{ 
                fontSize: '15px', 
                fontWeight: 700, 
                color: '#2B2A2A', 
                margin: 0,
                lineHeight: 1.4
              }}>
                {title}
              </h2>
            )}
            {subtitle && (
              <p style={{ 
                fontSize: '12px', 
                color: '#8A7A81', 
                margin: '2px 0 0 0' 
              }}>
                {subtitle}
              </p>
            )}
          </div>

          {/* الأزرار أو القوائم المنسدلة في اليسار */}
          {actions && (
            <div 
              className="section-card__actions"
              style={{
                display: 'flex',
                alignItems: 'center',
                fontSize: '13px',
                color: '#8A7A81'
              }}
            >
              {actions}
            </div>
          )}
        </div>
      ) : null}

      {/* محتوى الكرت الداخلي (الرسومات البيانية أو الجداول) */}
      <div 
        className="section-card__content"
        style={{ 
          width: '100%',
          flex: 1
        }}
      >
        {children}
      </div>
    </section>
  );
}