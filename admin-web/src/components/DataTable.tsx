import { ReactNode } from 'react';

type DataTableProps = {
  columns: string[];
  children: ReactNode;
  dense?: boolean;
  minWidth?: number;
};

export function DataTable({
  columns,
  children,
  dense = false,
  minWidth = 820,
}: DataTableProps) {
  return (
    <div className={`table-wrap ${dense ? 'table-wrap--dense' : ''}`}>
      <table style={{ minWidth }}>
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column}>{column}</th>
            ))}
          </tr>
        </thead>
        <tbody>{children}</tbody>
      </table>
    </div>
  );
}
