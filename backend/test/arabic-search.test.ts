import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  ARABIC_FOLD_FROM,
  ARABIC_FOLD_TO,
  arabicSearchKey,
} from '../src/shared-kernel/text/arabic-search';

// RA-BE-09: the server finds what the phone's copy finds. These are the
// spellings the phone folds (mobile/test/core/utils/arabic_sort_test.dart).

test('the spelling forms read as their letter, as on the phone', () => {
  const same: Array<[string, string]> = [
    ['أحمد', 'احمد'],
    ['إبراهيم', 'ابراهيم'],
    ['آمنة', 'امنه'],
    ['قاعة', 'قاعه'],
    ['مصطفى', 'مصطفي'],
    ['مؤمن', 'مومن'],
    ['هيئة', 'هييه'],
    ['عبد الله', 'عبدالله'],
    ['مُحَمَّد', 'محمد'],
    ['عـــلي', 'علي'],
    ['Hall Saba', 'hallsaba'],
  ];
  for (const [written, typed] of same) {
    assert.equal(arabicSearchKey(written), arabicSearchKey(typed), written);
  }
  assert.equal(arabicSearchKey('قاعة سبأ'), 'قاعهسبا');
});

test('folding a key again changes nothing, so a folded key can be passed on', () => {
  for (const value of ['أحمد علي', 'قاعة', 'مُحَمَّد', 'هيئة']) {
    const key = arabicSearchKey(value);
    assert.equal(arabicSearchKey(key), key, value);
  }
});

test('only spacing and marks fold to nothing', () => {
  assert.equal(arabicSearchKey('  ـــ  '), '');
  assert.equal(arabicSearchKey('َ ُ'), '');
});

test('the key is what SQL translate() makes of the same text', () => {
  // translate(text, FROM, TO) maps FROM[i] to TO[i] and drops every
  // character of FROM past the length of TO; this is that, character by
  // character, so a key built here equals the column folded in SQL.
  const translate = (text: string) =>
    [...text.toLowerCase()]
      .map((character) => {
        const index = ARABIC_FOLD_FROM.indexOf(character);
        if (index < 0) return character;
        return index < ARABIC_FOLD_TO.length ? ARABIC_FOLD_TO[index] : '';
      })
      .join('');
  assert.equal(ARABIC_FOLD_TO.length, 8);
  assert.equal(new Set(ARABIC_FOLD_FROM).size, ARABIC_FOLD_FROM.length, 'no character twice');
  for (const value of ['قاعة سبأ', 'إبراهيم', 'مُحَمَّد', 'هيئة', 'Hall']) {
    assert.equal(arabicSearchKey(value), translate(value), value);
  }
});
