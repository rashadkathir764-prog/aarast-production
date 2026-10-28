import assert from 'node:assert/strict';
import test from 'node:test';
import { PortfolioItemStatus } from '@prisma/client';
import {
  isPortfolioItemVisibleTo,
  normalizePortfolioItems,
  normalizeSocialLink,
  normalizeSocialLinks,
  PORTFOLIO_MAX_ITEMS,
  portfolioItemNeedsReview,
  readSocialLinks,
  WOMEN_ALBUM,
} from '../src/modules/marketplace/public/provider-portfolio';
import { portfolioDecisionNotice } from '../src/admin/admin-portfolio-review';

const code = (expected: string) => (error: any) => error?.response?.code === expected;

test('B-16: social links are https profiles on their own network, written in one form', () => {
  assert.equal(normalizeSocialLink('tiktok', ' https://tiktok.com/@daw.sanaa '), 'https://www.tiktok.com/@daw.sanaa');
  assert.equal(normalizeSocialLink('instagram', 'https://www.instagram.com/daw_sanaa/'), 'https://www.instagram.com/daw_sanaa');
  assert.equal(normalizeSocialLink('facebook', 'https://m.facebook.com/daw.sanaa'), 'https://www.facebook.com/daw.sanaa');
  assert.equal(
    normalizeSocialLink('facebook', 'https://www.facebook.com/profile.php?id=100012345678'),
    'https://www.facebook.com/profile.php?id=100012345678',
  );
  for (const [network, value] of [
    ['tiktok', 'http://www.tiktok.com/@daw'],
    ['tiktok', 'https://vm.tiktok.com/ZS123/'],
    ['tiktok', 'https://www.tiktok.com/daw'],
    ['tiktok', 'https://www.tiktok.com.evil.example/@daw'],
    ['instagram', 'https://www.instagram.com/p/Cx123/'],
    ['instagram', 'https://user:pw@instagram.com/daw'],
    ['instagram', 'https://instagram.com:8443/daw'],
    ['instagram', 'https://www.tiktok.com/@daw'],
    ['facebook', 'https://www.facebook.com/groups/12345'],
    ['facebook', 'https://www.facebook.com/daw?ref=share'],
    ['facebook', 'javascript:alert(1)'],
    ['facebook', 'not a link'],
  ] as const) {
    assert.throws(() => normalizeSocialLink(network, value), code('PORTFOLIO_SOCIAL_LINK_INVALID'), value);
  }
  assert.deepEqual(normalizeSocialLinks({ tiktok: 'https://tiktok.com/@daw', instagram: '  ', facebook: null }), {
    tiktok: 'https://www.tiktok.com/@daw',
  });
  assert.deepEqual(readSocialLinks({ tiktok: 'https://www.tiktok.com/@daw', other: 'x', instagram: 3 }), {
    tiktok: 'https://www.tiktok.com/@daw',
  });
  assert.deepEqual(readSocialLinks(null), {});
});

test('B-16: the list keeps its order, each photo once, at most the limit', () => {
  const items = normalizePortfolioItems(
    [{ key: 'a', album: '  الزفة ' }, { key: 'b' }, { key: 'c', album: 'الدرون', noFaces: true }],
    false,
  );
  assert.deepEqual(items.map((item) => [item.key, item.album, item.sortOrder, item.forWomen]), [
    ['a', 'الزفة', 0, false],
    ['b', null, 1, false],
    ['c', 'الدرون', 2, false],
  ]);
  assert.throws(() => normalizePortfolioItems([{ key: 'a' }, { key: 'a' }], false), /once/);
  assert.throws(
    () => normalizePortfolioItems(Array.from({ length: PORTFOLIO_MAX_ITEMS + 1 }, (_, i) => ({ key: `k${i}` })), true),
    code('PORTFOLIO_TOO_MANY_ITEMS'),
  );
  assert.throws(() => normalizePortfolioItems([{ key: 'a', album: 'ا'.repeat(31) }], false), /30/);
});

test('B-16: the women\'s album needs a provider who serves women and «بدون وجوه»', () => {
  assert.throws(
    () => normalizePortfolioItems([{ key: 'a', album: WOMEN_ALBUM, noFaces: true }], false),
    code('PORTFOLIO_WOMEN_ALBUM_NOT_SERVED'),
  );
  assert.throws(
    () => normalizePortfolioItems([{ key: 'a', album: WOMEN_ALBUM }], true),
    code('PORTFOLIO_WOMEN_PHOTO_NEEDS_NO_FACES'),
  );
  const [item] = normalizePortfolioItems([{ key: 'a', album: WOMEN_ALBUM, noFaces: true }], true);
  assert.equal(item.forWomen, true);
});

test('B-16: a kept photo is reviewed again only when its album or «بدون وجوه» changed', () => {
  const approved = { album: 'الزفة', noFaces: false, status: PortfolioItemStatus.APPROVED };
  assert.equal(portfolioItemNeedsReview(approved, { album: 'الزفة', noFaces: false }), false);
  assert.equal(portfolioItemNeedsReview(approved, { album: WOMEN_ALBUM, noFaces: true }), true);
  assert.equal(
    portfolioItemNeedsReview({ ...approved, status: PortfolioItemStatus.REJECTED }, { album: 'x', noFaces: true }),
    false,
  );
});

test('B-16: customers see approved photos; the women\'s album brides only', () => {
  const approved = { status: PortfolioItemStatus.APPROVED, forWomen: false };
  const women = { status: PortfolioItemStatus.APPROVED, forWomen: true };
  assert.equal(isPortfolioItemVisibleTo(approved, false), true);
  assert.equal(isPortfolioItemVisibleTo({ ...approved, status: PortfolioItemStatus.PENDING }, true), false);
  assert.equal(isPortfolioItemVisibleTo({ ...approved, status: PortfolioItemStatus.REJECTED }, true), false);
  assert.equal(isPortfolioItemVisibleTo(women, false), false);
  assert.equal(isPortfolioItemVisibleTo(women, true), true);
});

test('B-16: the provider reads the decision and the reason, in the portal\'s voice', () => {
  const base = {
    id: 'p1',
    album: 'الزفة',
    forWomen: false,
    rejectionReason: null,
    provider: { id: 'v', businessName: 'استوديو', userId: 'u', status: 'ACTIVE' },
  } as any;
  assert.deepEqual(portfolioDecisionNotice({ ...base, status: PortfolioItemStatus.APPROVED }), {
    title: 'انقبلت صورة من معرضك',
    body: 'صورتك في «الزفة» تظهر الحين للعرسان.',
  });
  assert.equal(
    portfolioDecisionNotice({ ...base, album: WOMEN_ALBUM, forWomen: true, status: PortfolioItemStatus.APPROVED }).body,
    'صورتك في «حفلات النساء» تظهر الحين للعرائس.',
  );
  assert.deepEqual(
    portfolioDecisionNotice({ ...base, album: null, status: PortfolioItemStatus.REJECTED, rejectionReason: 'فيها وجه واضح' }),
    { title: 'ما قبلنا صورة من معرضك', body: 'صورتك في معرض الشغل ما تظهر. السبب: فيها وجه واضح' },
  );
});
