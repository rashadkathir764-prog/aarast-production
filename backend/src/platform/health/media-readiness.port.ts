export const MEDIA_READINESS_PORT = Symbol('MEDIA_READINESS_PORT');

export interface MediaReadinessPort {
  checkReadiness(): Promise<void>;
}
