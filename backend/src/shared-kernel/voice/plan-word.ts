/**
 * A word that follows whose wedding the plan is, not who reads it (LANGUAGE
 * §3, `planWord` on the phone): the bride's plan is the women's wedding, so
 * its guests are «الضيفات» and its place «الصالة»; any other plan's are
 * «الضيوف» and «القاعة». A word the same for both is a plain value.
 */
export interface PlanWord<T> {
  groom: T;
  bride: T;
}

function isPlanWord<T>(word: T | PlanWord<T>): word is PlanWord<T> {
  return (
    typeof word === 'object' &&
    word !== null &&
    'groom' in word &&
    'bride' in word
  );
}

export function planWord<T>(
  planPersona: string | null | undefined,
  word: T | PlanWord<T>,
): T {
  if (!isPlanWord(word)) return word;
  return planPersona === 'BRIDE' ? word.bride : word.groom;
}
