import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { Pagination } from './Pagination';

describe('Pagination', () => {
  it('shows the real result range and requests the adjacent page', () => {
    const onPageChange = vi.fn();
    render(
      <Pagination
        page={2}
        limit={20}
        total={95}
        totalPages={5}
        onPageChange={onPageChange}
      />,
    );

    expect(screen.getByText('21–40 من 95 نتيجة')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'الصفحة 2' })).toHaveAttribute(
      'aria-current',
      'page',
    );

    fireEvent.click(screen.getByRole('button', { name: 'الصفحة التالية' }));
    expect(onPageChange).toHaveBeenCalledWith(3);
  });

  it('disables navigation at the first and last page', () => {
    const { rerender } = render(
      <Pagination
        page={1}
        limit={20}
        total={95}
        totalPages={5}
        onPageChange={() => undefined}
      />,
    );
    expect(screen.getByRole('button', { name: 'الصفحة السابقة' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'الصفحة التالية' })).toBeEnabled();

    rerender(
      <Pagination
        page={5}
        limit={20}
        total={95}
        totalPages={5}
        onPageChange={() => undefined}
      />,
    );
    expect(screen.getByRole('button', { name: 'الصفحة السابقة' })).toBeEnabled();
    expect(screen.getByRole('button', { name: 'الصفحة التالية' })).toBeDisabled();
  });

  it('offers bounded page jumps for a large result set', () => {
    const onPageChange = vi.fn();
    render(
      <Pagination
        page={50}
        limit={20}
        total={2_000}
        totalPages={100}
        onPageChange={onPageChange}
      />,
    );

    expect(screen.getByRole('button', { name: 'الصفحة 1' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'الصفحة 49' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'الصفحة 50' })).toHaveAttribute(
      'aria-current',
      'page',
    );
    expect(screen.getByRole('button', { name: 'الصفحة 51' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'الصفحة 100' })).toBeInTheDocument();
    expect(screen.getAllByText('…')).toHaveLength(2);

    fireEvent.click(screen.getByRole('button', { name: 'الصفحة 100' }));
    expect(onPageChange).toHaveBeenCalledWith(100);
  });
});
