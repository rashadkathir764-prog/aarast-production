// The admin desk kit: the
// page head, buttons, panels, tables, tags and stats every admin page uses.
import type { ButtonHTMLAttributes, ReactNode } from 'react';
import type { LucideIcon } from 'lucide-react';
import { Pagination } from './Pagination';

export type DeskTone =
  | 'teal'
  | 'soft'
  | 'coral'
  | 'green'
  | 'saffron'
  | 'sky'
  | 'lilac'
  | 'muted'
  | 'white-coral';

export function DeskHeader({
  title,
  sub,
  actions,
}: {
  title: ReactNode;
  sub?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <header className="desk-head">
      <div className="desk-head__text">
        <h1>{title}</h1>
        {sub ? <p>{sub}</p> : null}
      </div>
      {actions ? <div className="desk-head__actions">{actions}</div> : null}
    </header>
  );
}

type DeskButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  tone?: DeskTone;
  icon?: LucideIcon;
  pressed?: boolean;
};

/** akit `aBtn`: 10/18 padding, 16 radius, 14 bold, an 18 icon before the label. */
export function DeskButton({
  tone = 'teal',
  icon: Icon,
  pressed,
  className,
  children,
  type = 'button',
  ...rest
}: DeskButtonProps) {
  return (
    <button
      {...rest}
      type={type}
      aria-pressed={pressed}
      className={`desk-btn desk-btn--${tone}${className ? ` ${className}` : ''}`}
    >
      {Icon ? <Icon size={18} strokeWidth={2} aria-hidden="true" /> : null}
      <span>{children}</span>
    </button>
  );
}

/** kit `softAction`: a small pill button inside rows and panels. */
export function SoftAction({
  tone = 'soft',
  className,
  children,
  type = 'button',
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { tone?: 'soft' | 'coral' | 'green' }) {
  return (
    <button
      {...rest}
      type={type}
      className={`desk-soft desk-soft--${tone}${className ? ` ${className}` : ''}`}
    >
      {children}
    </button>
  );
}

export function Panel({
  children,
  tone,
  border,
  flush,
  className,
}: {
  children: ReactNode;
  tone?: 'soft' | 'coral' | 'bg';
  border?: 'coral' | 'teal';
  flush?: boolean;
  className?: string;
}) {
  const classes = ['desk-panel'];
  if (tone) classes.push(`desk-panel--${tone}`);
  if (border) classes.push(`desk-panel--border-${border}`);
  if (flush) classes.push('desk-panel--flush');
  if (className) classes.push(className);
  return <section className={classes.join(' ')}>{children}</section>;
}

export function Tag({ tone, children }: { tone: Exclude<DeskTone, 'white-coral'>; children: ReactNode }) {
  return <span className={`desk-tag desk-tag--${tone}`}>{children}</span>;
}

/** Bold line over a muted line (akit `t2`). */
export function TwoLine({ main, sub }: { main: ReactNode; sub?: ReactNode }) {
  return (
    <span className="desk-two">
      <strong>{main}</strong>
      {sub ? <small>{sub}</small> : null}
    </span>
  );
}

export function Stat({
  value,
  label,
  sub,
  tone,
}: {
  value: ReactNode;
  label: ReactNode;
  sub?: ReactNode;
  tone?: 'coral' | 'sky' | 'saffron';
}) {
  return (
    <section className="desk-panel desk-stat">
      <strong className={tone ? `desk-stat__value desk-ink--${tone}` : 'desk-stat__value'}>
        {value}
      </strong>
      <span className="desk-stat__label">{label}</span>
      {sub ? <span className="desk-stat__sub">{sub}</span> : null}
    </section>
  );
}

export function StatRow({ children }: { children: ReactNode }) {
  return <div className="desk-stats">{children}</div>;
}

export type DeskColumn = { label: string; flex: number };

/**
 * akit `table`: a white panel, a muted head row, rows split by a line; the
 * columns keep the design's flex weights.
 */
export function DeskTable<T>({
  columns,
  rows,
  rowKey,
  renderRow,
  highlight,
  onRowClick,
  rowLabel,
  caption,
}: {
  columns: DeskColumn[];
  rows: T[];
  rowKey: (row: T) => string;
  renderRow: (row: T) => ReactNode[];
  highlight?: (row: T) => boolean;
  onRowClick?: (row: T) => void;
  rowLabel?: (row: T) => string;
  caption?: string;
}) {
  const total = columns.reduce((sum, column) => sum + column.flex, 0);
  return (
    <div className="desk-panel desk-table">
      <table>
        {caption ? <caption className="desk-sr">{caption}</caption> : null}
        <colgroup>
          {columns.map((column, index) => (
            <col key={index} style={{ width: `${(column.flex / total) * 100}%` }} />
          ))}
        </colgroup>
        <thead>
          <tr>
            {columns.map((column, index) => (
              <th key={index} scope="col">
                {column.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => {
            const cells = renderRow(row);
            const classes = [highlight?.(row) ? 'is-hi' : '', onRowClick ? 'is-link' : '']
              .filter(Boolean)
              .join(' ');
            return (
              <tr
                key={rowKey(row)}
                className={classes || undefined}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                onKeyDown={
                  onRowClick
                    ? (event) => {
                        if (event.target !== event.currentTarget) return;
                        if (event.key === 'Enter' || event.key === ' ') {
                          event.preventDefault();
                          onRowClick(row);
                        }
                      }
                    : undefined
                }
                tabIndex={onRowClick ? 0 : undefined}
                aria-label={onRowClick && rowLabel ? rowLabel(row) : undefined}
              >
                {cells.map((cell, index) => (
                  <td key={index}>{cell}</td>
                ))}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/** Page buttons under a desk table, shown only when there is a next page. */
export function DeskPager({
  page,
  limit,
  total,
  totalPages,
  onPageChange,
}: {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  onPageChange: (page: number) => void;
}) {
  if (totalPages <= 1) return null;
  return (
    <div className="desk-pager">
      <Pagination
        page={page}
        limit={limit}
        total={total}
        totalPages={totalPages}
        onPageChange={onPageChange}
      />
    </div>
  );
}

/** Loading, error and empty lines inside the desk, without replacing the page. */
export function DeskNote({ children, tone }: { children: ReactNode; tone?: 'coral' }) {
  return (
    <p className={tone ? `desk-note desk-ink--${tone}` : 'desk-note'} role={tone ? 'alert' : undefined}>
      {children}
    </p>
  );
}

export function DeskRetry({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="desk-retry" role="alert">
      <span>{message}</span>
      <SoftAction onClick={onRetry}>حاول مرة ثانية</SoftAction>
    </div>
  );
}

/** «★★☆☆☆». */
export function stars(rating: number): string {
  const full = Math.max(0, Math.min(5, Math.round(rating)));
  return '★'.repeat(full) + '☆'.repeat(5 - full);
}

/** «773 210 455»: a Yemeni mobile in threes, as the designs write it. */
export function phoneSpaced(phone: string | null | undefined): string {
  if (!phone) return '—';
  const digits = phone.replace(/\D/g, '');
  const local = digits.length === 12 && digits.startsWith('967') ? digits.slice(3) : digits;
  if (local.length !== 9) return phone;
  return `${local.slice(0, 3)} ${local.slice(3, 6)} ${local.slice(6)}`;
}

/** «550,000» with Latin digits, the way the designs write money and counts. */
export function grouped(value: number | string | null | undefined): string {
  if (value === null || value === undefined || value === '') return '—';
  const number = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(number)) return String(value);
  return new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 }).format(number);
}
