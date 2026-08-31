import { type ReactNode } from 'react';

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
    <section className={['section-card', className].filter(Boolean).join(' ')}>
      {title || subtitle || actions ? (
        <div className="section-card__header">
          <div className="section-card__heading">
            {title ? <h2>{title}</h2> : null}
            {subtitle ? <p>{subtitle}</p> : null}
          </div>
          {actions ? <div className="section-card__actions">{actions}</div> : null}
        </div>
      ) : null}
      <div className="section-card__content">{children}</div>
    </section>
  );
}
