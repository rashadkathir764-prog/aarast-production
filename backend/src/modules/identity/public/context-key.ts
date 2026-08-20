export type PlanContextKeyRole = "owner" | "contributor";

export function canonicalPlanContextKey(
  weddingPlanId: string,
  role: PlanContextKeyRole,
): string {
  return `plan:${weddingPlanId}:${role}`;
}

export function canonicalProviderContextKey(providerId: string): string {
  return `provider:${providerId}`;
}
