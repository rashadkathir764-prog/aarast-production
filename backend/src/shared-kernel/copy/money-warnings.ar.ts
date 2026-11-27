import { countedWords } from '../voice/count-words';

/**
 * D129 (docs/project/LANGUAGE.md): the money warnings the home's summary
 * carries (`financialWarnings`), one catalog. «فوق الميزانية» is said by
 * the expected cost (MONEY_TERMS, D105); a count is said with its noun
 * (LANGUAGE §4.6), the amount stays the warning's data.
 */
export const MONEY_WARNING_COPY = {
  budgetExceeded: 'التكلفة المتوقعة للعرس فوق الميزانية.',
  /** «عندك دفعة متأخرة.», «عندك دفعتان متأخرتان.», «عندك 3 دفعات متأخرة.» */
  paymentsOverdue: (count: number): string =>
    `عندك ${countedWords(count, {
      one: 'دفعة متأخرة',
      two: 'دفعتان متأخرتان',
      few: 'دفعات متأخرة',
      many: 'دفعة متأخرة',
      other: 'دفعة متأخرة',
    })}.`,
  /** «عندك دفعة خلال الأيام السبعة القادمة.», «عندك دفعتان خلال …». */
  paymentsDueSoon: (count: number): string =>
    `عندك ${countedWords(count, {
      one: 'دفعة',
      two: 'دفعتان',
      few: 'دفعات',
      many: 'دفعة',
      other: 'دفعة',
    })} خلال الأيام السبعة القادمة.`,
} as const;
