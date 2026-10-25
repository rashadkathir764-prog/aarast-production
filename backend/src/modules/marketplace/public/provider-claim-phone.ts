import { PhoneNormalizer } from '../../../shared-kernel/phone/phone-normalizer';

/**
 * The proof of a claim (V1 checklist 4.18, B-12): the account's verified
 * phone, in every spelling, carries the listing's phone. Sending a claim
 * looks the listing up by these spellings, and approving it checks them
 * again, so a phone changed in between no longer proves the claim.
 */
export function claimPhoneSpellings(
  accountPhone: string | null | undefined,
): string[] {
  return accountPhone ? PhoneNormalizer.lookupVariants(accountPhone) : [];
}

export function claimPhoneMatchesListing(
  accountPhone: string | null | undefined,
  listingPhone: string,
): boolean {
  return claimPhoneSpellings(accountPhone).includes(listingPhone);
}
