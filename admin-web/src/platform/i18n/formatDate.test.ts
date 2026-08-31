import { afterEach, describe, expect, it, vi } from 'vitest';

import { formatDate } from './formatDate';

describe('formatDate', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns the Arabic unknown label for nullish values', () => {
    for (const value of [null, undefined]) {
      expect(formatDate(value)).toBe('غير محدد');
    }
  });

  it('formats a present date with the exact Yemeni Arabic formatter', () => {
    const value = '2026-08-30T10:15:00.000Z';
    const format = vi.fn(() => 'تاريخ منسق');
    const formatter = { format } as unknown as Intl.DateTimeFormat;
    const dateTimeFormat = vi.spyOn(Intl, 'DateTimeFormat')
      .mockImplementation(function DateTimeFormatMock() {
        return formatter;
      });

    expect(formatDate(value)).toBe('تاريخ منسق');
    expect(dateTimeFormat).toHaveBeenCalledWith('ar-YE', {
      year: 'numeric', month: 'short', day: 'numeric',
    });
    expect(format).toHaveBeenCalledTimes(1);
    expect(format).toHaveBeenCalledWith(new Date(value));
  });
});
