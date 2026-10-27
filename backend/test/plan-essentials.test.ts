import assert from 'node:assert/strict';
import { test } from 'node:test';
import { planEssentials } from '../src/dashboard/plan-essentials';

// G23: «ايش ناقص» for the six essentials the owner named.

const item = (categoryId: string, name: string, costsCount = 0, kind = 'WEDDING') => ({
  categoryId,
  name,
  kind,
  costsCount,
});

test('the groom reads each essential from his own items', () => {
  const result = planEssentials({
    persona: 'GROOM',
    categories: [
      item('venue', 'قاعة أو مخدرة الرجال', 1),
      item('suit', 'بدلة العريس'),
      item('photo', 'التصوير والفيديو', 1),
      item('mahr', 'المهر والاتفاقات', 1, 'MAHR'),
      item('gold', 'الذهب والشبكة'),
      item('home', 'تجهيز المنزل', 2),
    ],
    bookedCategoryIds: ['photo'],
    venueSecured: true,
  });
  assert.deepEqual(
    result.map((essential) => [essential.key, essential.status, essential.budgetCategoryId]),
    [
      ['VENUE', 'AGREED', 'venue'],
      ['DRESS', 'MISSING', 'suit'],
      ['PHOTO', 'BOOKED', 'photo'],
      ['GOLD', 'MISSING', 'gold'],
      ['HOME', 'AGREED', 'home'],
      ['HONEYMOON', 'NONE', null],
    ],
  );
});

test('the bride reads her dress; a confirmed venue booking without an agreement is booked', () => {
  const result = planEssentials({
    persona: 'BRIDE',
    categories: [item('hall', 'قاعة النساء'), item('dress', 'فستان الزفاف', 1), item('trip', 'شهر العسل')],
    bookedCategoryIds: [],
    venueSecured: true,
  });
  const byKey = Object.fromEntries(result.map((essential) => [essential.key, essential.status]));
  assert.equal(byKey.VENUE, 'BOOKED');
  assert.equal(byKey.DRESS, 'AGREED');
  assert.equal(byKey.HONEYMOON, 'MISSING');
  assert.equal(byKey.GOLD, 'NONE');
});
