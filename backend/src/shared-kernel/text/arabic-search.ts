/**
 * RA-BE-09: one Arabic search folding for the server, the same as the
 * phone's `arabicSearchKey` (mobile/lib/core/utils/arabic_sort.dart). The
 * spelling forms read as their letter (أ إ آ ٱ as ا, ى and ئ as ي, ؤ as و,
 * ة as ه), and the marks, tatweel and spaces are dropped, so «قاعه» finds
 * «قاعة», «احمد» finds «أحمد» and «عبدالله» finds «عبد الله». Without it
 * the phone's copy found a name and the server's answer then lost it.
 *
 * The same two strings drive the key here and the columns in SQL, where a
 * search reads (written out in each query, so the ownership scan can read
 * which tables it touches):
 *
 *     strpos(translate(lower(concat_ws(chr(1), a."x", a."y")),
 *       ${ARABIC_FOLD_FROM}, ${ARABIC_FOLD_TO}), ${key}) > 0
 *
 * `translate` drops every character of FROM past the length of TO, so the
 * two sides cannot fold differently; `concat_ws` skips a missing field, and
 * its chr(1) keeps a key from matching across two fields. Code points are
 * written out because the letters are hard to read in a mixed-direction
 * line.
 */
const FOLDED =
  'آأإٱ' + // آ أ إ ٱ
  'ىؤئة'; //  ى ؤ ئ ة
const FOLDED_TO =
  'اااا' + // ا ا ا ا
  'يويه'; //  ي و ي ه
const MARKS = Array.from({ length: 0x065f - 0x064b + 1 }, (_, index) =>
  String.fromCharCode(0x064b + index),
).join('');
/** Harakat and the other marks, tatweel, the dagger alef and spaces. */
const DROPPED = `${MARKS}ـٰ \t\n\r `;

export const ARABIC_FOLD_FROM = `${FOLDED}${DROPPED}`;
export const ARABIC_FOLD_TO = FOLDED_TO;

/** The key a search is matched by: folded, lowercase, without spaces. */
export function arabicSearchKey(value: string): string {
  let key = '';
  for (const character of value.toLowerCase()) {
    const index = ARABIC_FOLD_FROM.indexOf(character);
    if (index < 0) key += character;
    else if (index < ARABIC_FOLD_TO.length) key += ARABIC_FOLD_TO[index];
  }
  return key;
}
