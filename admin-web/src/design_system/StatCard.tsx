import { type ReactNode } from 'react';

type StatCardProps = {
  title: string;
  value: number | string;
  hint?: string;
  trend?: number;
  icon?: ReactNode;
  tone?: 'default' | 'gold' | 'brand' | 'success' | 'warning' | 'danger' | 'info';
};

export function StatCard({
  title,
  value,
  hint,
  trend,
  icon,
  tone = 'default',
}: StatCardProps) {
  const resolvedTone = tone === 'gold' ? 'brand' : tone;

  return (
    <article className={`stat-card stat-card--${resolvedTone}`}>
      <div className="stat-card__top">
        <span>{title}</span>
        {icon ? (
          <span className="stat-card__icon" aria-hidden="true">
            {icon}
          </span>
        ) : null}
      </div>
      <strong>{value}</strong>
      {trend !== undefined ? (
        <div
          className={`stat-card__trend ${trend >= 0 ? 'is-positive' : 'is-negative'}`}
        >
          <span aria-hidden="true">{trend >= 0 ? '↑' : '↓'}</span>
          <bdi>{Math.abs(trend)}%</bdi>
          {hint ? <span>{hint}</span> : null}
        </div>
      ) : hint ? (
        <small>{hint}</small>
      ) : null}
    </article>
  );
}
