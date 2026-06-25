export interface PrioritizedDashboardAction {
  priority: 'URGENT' | 'HIGH' | 'NORMAL' | 'LOW';
  dueDate: Date | null;
}

export function selectTopDashboardActions<
  T extends PrioritizedDashboardAction,
>(items: T[], limit = 3): T[] {
  const rank = { URGENT: 0, HIGH: 1, NORMAL: 2, LOW: 3 } as const;
  return [...items]
    .sort((left, right) => {
      const priority = rank[left.priority] - rank[right.priority];
      if (priority !== 0) return priority;
      const leftDue = left.dueDate?.getTime() ?? Number.MAX_SAFE_INTEGER;
      const rightDue = right.dueDate?.getTime() ?? Number.MAX_SAFE_INTEGER;
      return leftDue - rightDue;
    })
    .slice(0, limit);
}
