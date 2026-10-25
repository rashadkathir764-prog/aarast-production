/**
 * Whose money a payment is (D59). A payment names no payer of its own: it is
 * filed under its agreement's payer (G14). The plan owner's own money pays
 * an agreement that names no payer, that names the owner's own party (the
 * groom on his plan, the bride on hers), or that is shared: the owner pays a
 * part of a shared agreement, so its payments are counted as his and «معك»
 * never shows money he may no longer have. The other party, the family or
 * anyone else pays for him: those payments still settle the agreement (what
 * was agreed and what is left count every payment) but never come out of
 * what the owner holds.
 */
export function paidFromOwnerMoney(
  payer: string | null,
  planPersona: string | null,
): boolean {
  if (!payer || payer === 'SHARED') return true;
  return (
    (payer === 'GROOM' && planPersona === 'GROOM') ||
    (payer === 'BRIDE' && planPersona === 'BRIDE')
  );
}
