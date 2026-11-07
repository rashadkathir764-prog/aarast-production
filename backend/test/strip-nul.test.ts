import assert from 'node:assert/strict';
import { test } from 'node:test';
import { StripNulPipe, stripNul } from '../src/platform/http/strip-nul.pipe';

// RA-BE-13: PostgreSQL cannot store U+0000 in text. A NUL anywhere in a
// request reached the database as an unclassified Prisma error, so a 500,
// which the phone's queue retries five times before parking the change
// under a false «check your connection».

test('removes NUL from every string of a body, however deep', () => {
  const body = {
    name: 'Ahmed\u0000 Ali',
    notes: '\u0000x\u0000y\u0000',
    items: [{ name: 'a\u0000b' }, 'c\u0000d'],
    nested: { deeper: { title: 'عرس\u0000' } },
  };
  assert.deepEqual(stripNul(body), {
    name: 'Ahmed Ali',
    notes: 'xy',
    items: [{ name: 'ab' }, 'cd'],
    nested: { deeper: { title: 'عرس' } },
  });
});

test('leaves every other value as it was', () => {
  const date = new Date(0);
  const body = { count: 3, paid: false, none: null, at: date, text: 'كما هو' };
  const result = stripNul(body) as typeof body;
  assert.deepEqual(result, body);
  assert.equal(result.at, date, 'a non-plain object is passed through, not copied');
  assert.equal(stripNul('بلا شي'), 'بلا شي');
  assert.equal(stripNul(undefined), undefined);
});

test('a query object without a prototype is cleaned too', () => {
  const query = Object.assign(Object.create(null) as Record<string, unknown>, { search: 'a\u0000b' });
  assert.deepEqual({ ...(stripNul(query) as object) }, { search: 'ab' });
});

test('the pipe cleans body, query and path values, and leaves custom ones', () => {
  const pipe = new StripNulPipe();
  for (const type of ['body', 'query', 'param'] as const) {
    assert.equal(pipe.transform('x\u0000y', { type }), 'xy');
  }
  const file = { buffer: Buffer.from([0, 1, 2]), originalname: 'a\u0000b' };
  assert.equal(pipe.transform(file, { type: 'custom' }), file);
});
