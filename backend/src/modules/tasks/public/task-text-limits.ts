/**
 * RA-BE-15: how long what a person types about a task may be, counted as the
 * phone counts (`MaxCharacters`, shared-kernel/text/text-length.ts). The
 * phone's fields stop at the same numbers (create_task_screen.dart, the
 * responsible person's field, the checklist), so the server never refuses
 * what the phone took, a refusal holding a queued change as «السيرفر رفضه».
 * Public: the plan import (planning) holds its tasks to them too.
 */
export const TASK_TITLE_MAX = 200;
export const TASK_DESCRIPTION_MAX = 1000;
export const TASK_PERSON_NAME_MAX = 120;
export const CHECKLIST_TITLE_MAX = 200;
