import { AnchorHTMLAttributes, ButtonHTMLAttributes, ReactNode } from 'react';
import { Link } from 'react-router-dom';

type Tone = 'primary' | 'ghost' | 'danger';

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  tone?: Tone;
  size?: 'default' | 'small';
  icon?: ReactNode;
};

type LinkProps = AnchorHTMLAttributes<HTMLAnchorElement> & {
  to: string;
  tone?: Tone;
  size?: 'default' | 'small';
  icon?: ReactNode;
};

function className(tone: Tone, size: 'default' | 'small', extra?: string) {
  return [
    'button',
    tone === 'ghost' ? 'button--ghost' : '',
    tone === 'danger' ? 'button--danger' : '',
    size === 'small' ? 'button--small' : '',
    extra,
  ]
    .filter(Boolean)
    .join(' ');
}

export function ActionButton({
  tone = 'primary',
  size = 'default',
  icon,
  children,
  className: extra,
  ...props
}: ButtonProps) {
  return (
    <button className={className(tone, size, extra)} {...props}>
      {icon ? <span aria-hidden="true">{icon}</span> : null}
      {children}
    </button>
  );
}

export function ActionLink({
  to,
  tone = 'primary',
  size = 'default',
  icon,
  children,
  className: extra,
  ...props
}: LinkProps) {
  return (
    <Link className={className(tone, size, extra)} to={to} {...props}>
      {icon ? <span aria-hidden="true">{icon}</span> : null}
      {children}
    </Link>
  );
}
