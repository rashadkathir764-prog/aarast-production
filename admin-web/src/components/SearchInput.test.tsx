import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { SearchInput } from './SearchInput';

describe('SearchInput', () => {
  it('labels the search landmark and submits the current filter', () => {
    const onChange = vi.fn();
    const onSubmit = vi.fn();

    render(
      <SearchInput
        label="بحث في الموردين"
        value="قاعة"
        onChange={onChange}
        onSubmit={onSubmit}
        placeholder="بحث باسم المورد أو الهاتف"
      />,
    );

    const search = screen.getByRole('search', { name: 'بحث في الموردين' });
    const input = screen.getByRole('searchbox', { name: 'بحث في الموردين' });

    expect(search).toContainElement(input);
    expect(input).toHaveValue('قاعة');
    fireEvent.change(input, { target: { value: 'تصوير' } });
    expect(onChange).toHaveBeenCalledWith('تصوير');

    fireEvent.submit(search);
    expect(onSubmit).toHaveBeenCalledTimes(1);
  });
});
