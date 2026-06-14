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
  minWidth = 600,
}: DataTableProps) {
  return (
    <div 
      className={`table-wrap ${dense ? 'table-wrap--dense' : ''} custom-data-table`}
      style={{ 
        width: '100%', 
        overflowX: 'auto',
        WebkitOverflowScrolling: 'touch'
      }}
    >
      {/* حقن تنسيق ديناميكي لضمان انسيابية وتطابق أسطر الجدول بالملي */}
      <style>{`
        .custom-data-table table {
          width: 100%;
          border-collapse: collapse;
          text-align: right;
          direction: rtl;
        }
        .custom-data-table th {
          color: #8A7A81 !important;
          font-size: 12px !important;
          font-weight: 500 !important;
          white-space: nowrap;
          border-bottom: 1px solid #F5F4F0 !important;
        }
        .custom-data-table td {
          padding: ${dense ? '12px 14px' : '16px 18px'} !important;
          border-bottom: 1px solid #F5F4F0 !important;
          color: #2B2A2A !important;
          font-size: 13px !important;
          vertical-align: middle;
          white-space: nowrap;
        }
        .custom-data-table tr:last-child td {
          border-bottom: none !important;
        }
      `}</style>

      <table style={{ minWidth }}>
        <thead>
          <tr>
            {columns.map((column) => (
              <th 
                key={column}
                style={{
                  padding: dense ? '12px 14px' : '16px 18px',
                }}
              >
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