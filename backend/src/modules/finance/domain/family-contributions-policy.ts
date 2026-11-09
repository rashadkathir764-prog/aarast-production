import type { Prisma } from '@prisma/client';

type Amount = Prisma.Decimal;

/** D108: a person's name as it is matched: trimmed, spaces folded, case folded. */
export function contributorKey(name: string | null | undefined): string | null {
  const folded = (name ?? '').trim().replace(/\s+/gu, ' ').toLocaleLowerCase('ar');
  return folded.length > 0 ? folded : null;
}

export interface ContributionCost {
  totalAmount: Amount;
  paid: Amount;
  payer: string | null;
  payerName: string | null;
  /** D59: paid from the owner's own money (then it is not someone's help). */
  ownerMoney: boolean;
}

export interface ContributionSource {
  contributorName: string | null;
  /** What it was recorded as («من مين؟»). */
  sourceName: string;
  amount: Amount;
  status: 'RECEIVED' | 'PLEDGED';
  /** A loan is money he returns, not help. */
  kind: string;
}

export interface Contributor {
  /** The name as first written; null: agreements of one payer with no name («الأهل»). */
  name: string | null;
  /** The payer of their agreements, when they pay any (FAMILY, BRIDE, OTHER). */
  payer: string | null;
  /** Reached the owner (it is in «وصلك»). */
  gave: Amount;
  /** Promised to the owner, not arrived yet. */
  promised: Amount;
  /** Paid straight to the shops on their agreements (never in «وصلك», D59). */
  paid: Amount;
  /** Still on them, on their agreements. */
  left: Amount;
  costsCount: number;
}

/**
 * D108: who a source of money is from. Its contributor when one is named;
 * otherwise family support and gifts are from the one they were recorded
 * as («من مين؟ الوالد»), the way the form asks. Savings, a loan (it goes
 * back), the mahr and anything else are no one's help.
 */
export function sourcePerson(source: {
  contributorName: string | null;
  sourceName: string;
  kind: string;
}): string | null {
  if (source.kind === 'LOAN') return null;
  if (contributorKey(source.contributorName) !== null) return source.contributorName;
  return source.kind === 'FAMILY_SUPPORT' || source.kind === 'GIFT'
    ? contributorKey(source.sourceName) === null
      ? null
      : source.sourceName
    : null;
}

/**
 * D108: the family, person by person. A person is a name: on a source of
 * money (`contributorName`, a loan excluded: it goes back) or on agreements
 * someone else pays for the owner (`payerName`). The same name, folded, is
 * one person; agreements someone else pays with no name are one line per
 * payer. Order: who did most first.
 */
export function familyContributions(input: {
  costs: readonly ContributionCost[];
  sources: readonly ContributionSource[];
  zero: Amount;
}): Contributor[] {
  const ZERO = input.zero;
  const people = new Map<string, Contributor>();
  const personOf = (name: string | null, payer: string | null) => {
    const key = name === null ? `#${payer ?? ''}` : (contributorKey(name) as string);
    const person = people.get(key) ?? {
      name: name === null ? null : name.trim().replace(/\s+/gu, ' '),
      payer: null,
      gave: ZERO,
      promised: ZERO,
      paid: ZERO,
      left: ZERO,
      costsCount: 0,
    };
    people.set(key, person);
    return person;
  };
  for (const source of input.sources) {
    const name = sourcePerson(source);
    if (name === null) continue;
    const person = personOf(name, null);
    if (source.status === 'RECEIVED') person.gave = person.gave.plus(source.amount);
    else person.promised = person.promised.plus(source.amount);
  }
  for (const cost of input.costs) {
    if (cost.ownerMoney) continue;
    const named = contributorKey(cost.payerName) !== null;
    const person = personOf(named ? (cost.payerName as string) : null, cost.payer);
    person.payer = person.payer ?? cost.payer;
    person.paid = person.paid.plus(cost.paid);
    const left = cost.totalAmount.minus(cost.paid);
    if (left.gt(0)) person.left = person.left.plus(left);
    person.costsCount += 1;
  }
  return [...people.values()].sort(
    (a, b) =>
      b.gave.plus(b.paid).comparedTo(a.gave.plus(a.paid)) ||
      (a.name ?? '').localeCompare(b.name ?? '', 'ar'),
  );
}
