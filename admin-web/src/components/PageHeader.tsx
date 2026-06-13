import { ReactNode } from 'react';

type PageHeaderProps = {
  eyebrow?: string;
  title: string;
  description?: string;
  icon?: string;
  actions?: ReactNode;
  meta?: ReactNode;
};

export function PageHeader({
  eyebrow,
  title,
  description,
  icon,
  actions,
  meta,
}: PageHeaderProps) {
  return (
    <header className="page-header">
      <div className="page-header__title">
        {icon ? <span className="page-header__icon">{icon}</span> : null}
        <div>
          {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
          <h1>{title}</h1>
          {description ? <p>{description}</p> : null}
        </div>
      </div>
      {meta ? <div className="page-header__meta">{meta}</div> : null}
      {actions ? <div className="page-header__actions">{actions}</div> : null}
    </header>
  );
}
