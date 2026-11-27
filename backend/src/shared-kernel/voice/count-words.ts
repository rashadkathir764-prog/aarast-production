/**
 * A number beside the noun it counts (LANGUAGE.md §4.6), the server's one
 * rule, as `arabicCount` is the phone's: the category is read from the last
 * two digits. One and two are said by the word alone («عرض», «عرضان»), and
 * each line passes its forms in its own case («يومان» before a verb,
 * «يومين» after «بعد»), so one line never serves two places.
 */
export interface CountForms {
  /** 1, said without the number: «دفعة متأخرة». */
  one: string;
  /** 2, the dual in the line's own case: «دفعتان متأخرتان». */
  two: string;
  /** Last two digits 3 to 10, after the number: «3 دفعات». */
  few: string;
  /** Last two digits 11 to 99, after the number: «11 دفعة». */
  many: string;
  /** 100 and up when the last two digits are 00, 01 or 02: «100 دفعة». */
  other: string;
}

/** «دفعة», «دفعتان», «3 دفعات», «11 دفعة», «103 دفعات», «100 دفعة». */
export function countedWords(count: number, forms: CountForms): string {
  if (count === 1) return forms.one;
  if (count === 2) return forms.two;
  const lastTwo = Math.abs(count) % 100;
  if (lastTwo >= 3 && lastTwo <= 10) return `${count} ${forms.few}`;
  if (lastTwo >= 11 && lastTwo <= 99) return `${count} ${forms.many}`;
  return `${count} ${forms.other}`;
}
