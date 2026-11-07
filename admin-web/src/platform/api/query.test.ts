import { describe, expect, it } from 'vitest';

import { everyPage, pageToShow, toQuery } from './query';

// RA-AD-12: the server answers a page past the end with no rows. After the
// last rows of a later page are handled, the page moves back to the last
// one instead of saying the list is empty while rows still wait.
describe('pageToShow', () => {
  it('moves back to the last page from a page past it', () => {
    expect(pageToShow(2, 1)).toBe(1);
    expect(pageToShow(5, 3)).toBe(3);
  });

  it('keeps a page that still has rows, and the first page', () => {
    expect(pageToShow(2, 2)).toBe(2);
    expect(pageToShow(1, 0)).toBe(1);
  });

  it('goes to the first page when nothing is left', () => {
    expect(pageToShow(3, 0)).toBe(1);
  });
});

describe('everyPage', () => {
  it('reads the pages up to the total, and keeps the server total', async () => {
    const pages: number[] = [];
    const all = await everyPage(async (page, limit) => {
      pages.push(page);
      return { items: Array.from({ length: page === 3 ? 5 : limit }, (_, i) => `${page}:${i}`), total: 205 };
    });
    expect(pages).toEqual([1, 2, 3]);
    expect(all.items).toHaveLength(205);
    expect(all.total).toBe(205);
  });

  it('stops at a thousand rows and on an empty page', async () => {
    let calls = 0;
    const capped = await everyPage(async (_page, limit) => {
      calls++;
      return { items: Array.from({ length: limit }, () => 'x'), total: 5000 };
    });
    expect(calls).toBe(10);
    expect(capped.items).toHaveLength(1000);
    expect(capped.total).toBe(5000);
    const short = await everyPage(async (page) => ({ items: page === 1 ? ['a'] : [], total: 300 }));
    expect(short.items).toEqual(['a']);
  });
});

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
