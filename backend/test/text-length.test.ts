import assert from 'node:assert/strict';
import { test } from 'node:test';
import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { IsString, validate } from 'class-validator';
import { characterCount, MaxCharacters } from '../src/shared-kernel/text/text-length';
import { ReplaceMoneyBudgetDto } from '../src/money/dto/replace-money-budget.dto';
import { parseQuoteOfferLines } from '../src/modules/marketplace/public/quote-offer-versions';
import { PlanEventFieldsDto } from '../src/wedding-plans/plan-events.controller';

// RA-BE-16: the phone's `maxLength` counts a character as the reader sees it
// (Flutter's `characters.length`); class-validator's `@MaxLength` counts code
// points, so a shadda, a vowel mark or a joined emoji counted extra and the
// server refused text the phone had accepted. A queued change then stuck as
// «السيرفر رفضه».

const MUHAMMAD = 'مُحَمَّد'; // 4 characters, 8 code points
const FAMILY = '👨‍👩‍👧'; // 1 character, 5 code points

test('counts characters as the phone does', () => {
  assert.equal(characterCount(MUHAMMAD), 4);
  assert.equal(characterCount(FAMILY), 1);
  assert.equal(characterCount('قاعة الأفراح'), 12);
  assert.equal(characterCount(''), 0);
});

class Named {
  @IsString()
  @MaxCharacters(4)
  name!: string;
}

async function refused(name: string) {
  return (await validate(plainToInstance(Named, { name }))).length > 0;
}

test('takes as many characters as the phone allows, marks and emoji included', async () => {
  assert.equal(await refused(MUHAMMAD), false);
  assert.equal(await refused(`${FAMILY}${FAMILY}${FAMILY}${FAMILY}`), false);
  assert.equal(await refused(`${MUHAMMAD}ا`), true);
});

test('still stops a character padded past any real one', async () => {
  // One base letter under a thousand combining marks is one character on
  // the phone; no real text needs it, and it would otherwise be unbounded.
  assert.equal(await refused(`ا${'ّ'.repeat(1000)}`), true);
});

test('a budget item name with marks, at the phone limit, is taken', async () => {
  const name = MUHAMMAD.repeat(30); // 120 characters on the phone, 240 code points
  const budget = (categoryName: string) =>
    validate(
      plainToInstance(ReplaceMoneyBudgetDto, {
        totalBudget: '1000',
        currency: 'YER',
        categories: [{ name: categoryName, allocatedAmount: '1000' }],
      }),
    );
  assert.deepEqual((await budget(name)).map((error) => error.property), []);
  assert.deepEqual((await budget(`${name}ا`)).map((error) => error.property), ['categories']);
});

test("RA-BE-78: an event's text counts as the phone's event sheet does", async () => {
  // The form is declared in the controller; the phone stops at 60 and 120.
  const event = (fields: Record<string, string>) =>
    validate(plainToInstance(PlanEventFieldsDto, fields));
  const title = MUHAMMAD.repeat(15); // 60 characters, 120 code points
  const place = MUHAMMAD.repeat(30); // 120 characters, 240 code points
  assert.deepEqual(
    (await event({ title, placeLabel: place, responsibleName: title, note: place })).map(
      (error) => error.property,
    ),
    [],
  );
  assert.deepEqual(
    (await event({ title: `${title}ا`, note: `${place}ا` })).map((error) => error.property).sort(),
    ['note', 'title'],
  );
});

test("an offer's line counts as the phone does", () => {
  // It was checked by code units, outside the request form.
  const label = MUHAMMAD.repeat(30); // 120 characters, 240 code units
  assert.equal(
    parseQuoteOfferLines([{ label, kind: 'INCLUDED' }])?.[0]?.label,
    label,
  );
  assert.throws(
    () => parseQuoteOfferLines([{ label: `${label}ا`, kind: 'INCLUDED' }]),
    /120 حرف أو أقل/u,
  );
});
