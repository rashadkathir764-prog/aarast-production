/**
 * R4: the starter tasks whose whole point is booking one service, with the
 * words the money's own matcher files that service by. Such a task waits on
 * the plan's item and closes when the item is booked. A task that only
 * mentions a service («ترتيب الزفة والسيارة») is not here: booking one
 * provider does not finish it.
 */
const STARTER_TASK_SERVICES: Readonly<Record<string, string>> = {
  'task-shared-photo': 'التصوير',
  'task-groom-venue': 'القاعة',
  'task-bride-hall': 'القاعة',
  'task-groom-artist': 'الفنان',
  'task-bride-singer': 'الفنان',
  'task-groom-food': 'الضيافة',
  'task-bride-dress': 'الفستان',
  'task-bride-coiffeur': 'الكوافير',
  'task-bride-naqsh': 'النقش',
};

export function starterTaskService(key: string): string | null {
  return STARTER_TASK_SERVICES[key] ?? null;
}
