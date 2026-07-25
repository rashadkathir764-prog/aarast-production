import { randomBytes } from "node:crypto";

export function createStrongRuntimeJwtSecret(): string {
  return randomBytes(48).toString("base64url");
}
