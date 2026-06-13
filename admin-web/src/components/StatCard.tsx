import { ReactNode } from 'react';
import { TrendingUp, TrendingDown } from 'lucide-react';

type StatCardProps = {
  title: string;
  value: number | string;
  hint?: string;
  trend?: number; // positive or negative percentage
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
  return (
    <article className={`stat-card tone-${tone}`} style={{ display: 'flex', flexDirection: 'column', gap: '12px', padding: '20px', background: '#fff', borderRadius: '16px', border: '1px solid rgba(74, 7, 31, 0.05)', position: 'relative' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          <span style={{ fontSize: '14px', fontWeight: 700, color: 'var(--color-burgundy-950)' }}>{title}</span>
          <strong style={{ fontSize: '28px', color: 'var(--color-burgundy-950)', lineHeight: 1 }}>{value}</strong>
        </div>
        {icon && (
          <div style={{ 
            width: '42px', height: '42px', borderRadius: '12px', 
            background: 'rgba(199, 155, 63, 0.1)', color: 'var(--color-gold-600)',
            display: 'grid', placeItems: 'center'
          }}>
            {icon}
          </div>
        )}
      </div>
      
      <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', marginTop: 'auto', paddingTop: '12px', borderTop: '1px solid rgba(74, 7, 31, 0.05)' }}>
        {hint && <span style={{ fontSize: '12px', color: 'var(--color-muted)', fontWeight: 600 }}>{hint}</span>}
        {trend !== undefined && (
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '12px', fontWeight: 700, color: trend >= 0 ? 'var(--color-success)' : 'var(--color-danger)' }}>
            {trend >= 0 ? <TrendingUp size={14} strokeWidth={2.5} /> : <TrendingDown size={14} strokeWidth={2.5} />}
            <span>{Math.abs(trend)}% عن الشهر الماضي</span>
          </div>
        )}
      </div>
    </article>
  );
}
