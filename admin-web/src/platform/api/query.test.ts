import { describe, expect, it } from 'vitest';

import { toQuery } from './query';

describe('toQuery', () => {
  it('returns an empty string for empty parameters', () => {
    expect(toQuery({})).toBe('');
  });

  it('omits empty null and undefined values', () => {
    expect(toQuery({ status: 'PENDING', empty: '', nil: null, missing: undefined }))
      .toBe('?status=PENDING');
  });

  it('preserves zero false and encoded Arabic search values', () => {
    expect(toQuery({ page: 0, unreadOnly: false, search: 'قاعة & صالة' }))
      .toBe(`?${new URLSearchParams({
        page: '0', unreadOnly: 'false', search: 'قاعة & صالة',
      }).toString()}`);
  });
});
