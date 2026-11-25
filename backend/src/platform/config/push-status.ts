export const PUSH_NOTIFICATIONS_ENABLED_ENV = "PUSH_NOTIFICATIONS_ENABLED";
export const FIREBASE_PROJECT_ID_ENV = "FIREBASE_PROJECT_ID";

/**
 * Whether this server sends pushes, and to which Firebase project. Read by
 * the push client, logged once at boot and reported to the operator by
 * `/ready`; it holds no secret (the project id is not one).
 */
export function pushStatus(
  environment: NodeJS.ProcessEnv = process.env,
): { enabled: boolean; projectId: string | null } {
  const enabled = environment[PUSH_NOTIFICATIONS_ENABLED_ENV]?.trim() === "true";
  return {
    enabled,
    projectId: enabled ? environment[FIREBASE_PROJECT_ID_ENV]?.trim() || null : null,
  };
}
