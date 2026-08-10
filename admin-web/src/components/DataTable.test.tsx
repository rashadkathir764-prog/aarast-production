import { render, screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { DataTable } from './DataTable';

describe('DataTable', () => {
  it('provides an accessible name and semantic column headers', () => {
    const { container } = render(
      <DataTable
        label="قائمة الموردين"
        columns={['المورد', 'الحالة']}
        minWidth={920}
        dense
      >
        <tr>
          <td>قاعة السعادة</td>
          <td>نشط</td>
        </tr>
      </DataTable>,
    );

    const region = screen.getByRole('region', {
      name: 'قائمة الموردين، منطقة جدول قابلة للتمرير أفقيا',
    });
    const table = within(region).getByRole('table', {
      name: 'قائمة الموردين',
    });
    const headers = within(table).getAllByRole('columnheader');

    expect(region).toHaveAttribute('tabindex', '0');
    expect(region).toHaveClass('table-wrap--dense');
    expect(region).toHaveStyle('--data-table-min-width: 920px');
    expect(headers).toHaveLength(2);
    expect(headers[0]).toHaveAttribute('scope', 'col');
    expect(container.querySelector('style')).not.toBeInTheDocument();
  });
});
