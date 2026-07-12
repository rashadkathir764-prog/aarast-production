export function combineVisibleMoney(
  ...values: Array<number | null>
): number | null {
  const visible = values.filter((value): value is number => value !== null);
  if (visible.length === 0) return null;
  return visible.reduce((sum, value) => sum + value, 0);
}

export function financialExposure(input: {
  standaloneExpenses: number;
  commitments: number;
}): number {
  return input.standaloneExpenses + input.commitments;
}
