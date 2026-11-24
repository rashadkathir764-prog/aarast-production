/**
 * RA-BE-168: the one way a provider reads a customer's name, in the request,
 * the booking, the chat, the plan's header and every notice: the first name
 * and the family's initial («محمد ح.»), never the surname whole. A single
 * name stays as it is. Writing it twice gives the same answer, so a name a
 * layer already shortened is not shortened again.
 */
export function customerNameForProvider(
  name: string | null | undefined,
): string | null {
  const parts = name?.trim().split(/\s+/u).filter(Boolean) ?? [];
  if (parts.length === 0) return null;
  if (parts.length === 1) return parts[0];
  return `${parts[0]} ${familyInitial(parts[parts.length - 1])}.`;
}

/** «ح» from «الحمدي» (the article is no part of the family's letter) and from «ح.». */
function familyInitial(family: string): string {
  const bare = family.length > 3 && family.startsWith("ال") ? family.slice(2) : family;
  return Array.from(bare)[0] ?? "";
}
