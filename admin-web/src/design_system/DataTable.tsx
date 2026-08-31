import { type CSSProperties, type ReactNode } from 'react';

type DataTableProps = {
  label: string;
  columns: string[];
  children: ReactNode;
  dense?: boolean;
  minWidth?: number;
};

type DataTableStyle = CSSProperties & {
  '--data-table-min-width': string;
};

export function DataTable({
  label,
  columns,
  children,
  dense = false,
  minWidth = 600,
}: DataTableProps) {
  const tableStyle: DataTableStyle = {
    '--data-table-min-width': `${minWidth}px`,
  };

  return (
    <div
      className={`table-wrap ${dense ? 'table-wrap--dense' : ''}`}
      role="region"
      aria-label={`${label}، منطقة جدول قابلة للتمرير أفقيا`}
      tabIndex={0}
      style={tableStyle}
    >
      <table className="data-table">
        <caption className="sr-only">{label}</caption>
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column} scope="col">
                {column}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>{children}</tbody>
      </table>
    </div>
  );
}
