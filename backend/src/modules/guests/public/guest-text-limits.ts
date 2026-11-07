/**
 * RA-BE-15: how long what a person types about a guest may be, counted as
 * the phone counts (`MaxCharacters`, shared-kernel/text/text-length.ts). The
 * phone's fields stop at the same numbers (guest_form_sheet.dart, the groups
 * sheet, the contacts and list imports), so the server never refuses what the
 * phone took, a refusal holding a queued change as «السيرفر رفضه». Public:
 * the plan import (planning) holds its guests to them too.
 */
export const GUEST_NAME_MAX = 120;
export const GUEST_NOTES_MAX = 500;
export const GUEST_GROUP_NAME_MAX = 120;
