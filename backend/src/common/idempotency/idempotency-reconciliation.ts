import { Prisma } from "@prisma/client";
import { PrismaService } from "../../prisma/prisma.service";
import {
  encodeStoredResponse,
  type ReplayMetadata,
} from "./idempotency.interceptor";

const DEFAULT_REPLAY_RETENTION_HOURS = 168;
const MIN_REPLAY_RETENTION_HOURS = 1;
const MAX_REPLAY_RETENTION_HOURS = 720;
const SAFE_REPLAY_HEADER_NAMES = new Set([
  "location",
  "content-type",
  "content-language",
]);

export interface ReconciledResponse extends ReplayMetadata {
  body: unknown;
  statusCode: number;
}

export type IdempotencyReconciliationResolution =
  | { outcome: "NO_COMMIT" }
  | { outcome: "COMMITTED"; response: ReconciledResponse };

export interface IdempotencyReconciliationInput {
  id: string;
  expectedMethod: string;
  expectedPath: string;
  resolution: IdempotencyReconciliationResolution;
}

export interface IdempotencyReconciliationResult {
  id: string;
  state: "RELEASED_FOR_RETRY" | "COMPLETED_FOR_REPLAY";
}

export class IdempotencyReconciliationError extends Error {}

export async function reconcileAmbiguousIdempotencyKey(
  prisma: PrismaService,
  input: IdempotencyReconciliationInput,
  now = new Date(),
): Promise<IdempotencyReconciliationResult> {
  validateTarget(input);
  const response =
    input.resolution.outcome === "COMMITTED"
      ? validateReconciledResponse(input.resolution.response)
      : null;

  return prisma.$transaction(
    async (tx) => {
      const locked = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "IdempotencyKey"
          WHERE "id" = ${input.id}
          FOR UPDATE
        `,
      );
      if (locked.length !== 1) {
        throw new IdempotencyReconciliationError(
          "Idempotency tombstone was not found.",
        );
      }

      const row = await tx.idempotencyKey.findUnique({
        where: { id: input.id },
        select: {
          id: true,
          method: true,
          path: true,
          completedAt: true,
          expiresAt: true,
        },
      });
      if (!row) {
        throw new IdempotencyReconciliationError(
          "Idempotency tombstone was not found.",
        );
      }
      if (row.completedAt) {
        throw new IdempotencyReconciliationError(
          "Idempotency key is already completed.",
        );
      }
      if (row.expiresAt.getTime() > now.getTime()) {
        throw new IdempotencyReconciliationError(
          "Idempotency reservation is still active.",
        );
      }
      if (
        row.method !== input.expectedMethod ||
        row.path !== input.expectedPath
      ) {
        throw new IdempotencyReconciliationError(
          "Idempotency tombstone does not match the expected method and path.",
        );
      }

      if (input.resolution.outcome === "NO_COMMIT") {
        const released = await tx.idempotencyKey.deleteMany({
          where: {
            id: input.id,
            completedAt: null,
            expiresAt: { lte: now },
          },
        });
        if (released.count !== 1) {
          throw new IdempotencyReconciliationError(
            "Idempotency tombstone changed before release.",
          );
        }
        return { id: input.id, state: "RELEASED_FOR_RETRY" };
      }

      const completed = await tx.idempotencyKey.updateMany({
        where: {
          id: input.id,
          completedAt: null,
          expiresAt: { lte: now },
        },
        data: {
          response: encodeStoredResponse(response?.body, response ?? {}),
          completedAt: now,
          expiresAt: reconciliationReplayExpiry(now),
        },
      });
      if (completed.count !== 1) {
        throw new IdempotencyReconciliationError(
          "Idempotency tombstone changed before completion.",
        );
      }
      return { id: input.id, state: "COMPLETED_FOR_REPLAY" };
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
  );
}

function validateTarget(input: IdempotencyReconciliationInput): void {
  if (!/^c[a-z0-9]{15,35}$/.test(input.id)) {
    throw new IdempotencyReconciliationError(
      "Idempotency tombstone id is invalid.",
    );
  }
  if (!["POST", "PATCH", "PUT", "DELETE"].includes(input.expectedMethod)) {
    throw new IdempotencyReconciliationError(
      "Expected method must be a mutating HTTP method.",
    );
  }
  if (
    !input.expectedPath.startsWith("/") ||
    input.expectedPath.includes("?") ||
    input.expectedPath.length > 512
  ) {
    throw new IdempotencyReconciliationError(
      "Expected path must be a safe route template.",
    );
  }
}

function validateReconciledResponse(
  response: ReconciledResponse,
): ReconciledResponse {
  if (response.body === undefined) {
    throw new IdempotencyReconciliationError(
      "A committed reconciliation requires the exact response body.",
    );
  }
  if (
    !Number.isInteger(response.statusCode) ||
    response.statusCode < 200 ||
    response.statusCode > 299
  ) {
    throw new IdempotencyReconciliationError(
      "A committed reconciliation requires the exact 2xx status.",
    );
  }
  try {
    JSON.stringify(response.body);
  } catch {
    throw new IdempotencyReconciliationError(
      "Reconciled response body must be valid JSON.",
    );
  }

  const headers = Object.fromEntries(
    Object.entries(response.headers ?? {}).map(([rawName, rawValue]) => {
      const name = rawName.toLowerCase();
      if (!SAFE_REPLAY_HEADER_NAMES.has(name)) {
        throw new IdempotencyReconciliationError(
          `Reconciled response header is not replay-safe: ${name}`,
        );
      }
      const values = Array.isArray(rawValue) ? rawValue : [rawValue];
      if (
        values.length === 0 ||
        values.some(
          (value) =>
            typeof value !== "string" ||
            value.length > 2_048 ||
            /[\r\n]/.test(value),
        )
      ) {
        throw new IdempotencyReconciliationError(
          `Reconciled response header is invalid: ${name}`,
        );
      }
      return [name, Array.isArray(rawValue) ? values : values[0]];
    }),
  );

  return {
    body: response.body,
    statusCode: response.statusCode,
    ...(Object.keys(headers).length > 0 ? { headers } : {}),
  };
}

function reconciliationReplayExpiry(now: Date): Date {
  const configured = Number(process.env.IDEMPOTENCY_TTL_HOURS);
  const hours =
    Number.isFinite(configured) &&
    configured >= MIN_REPLAY_RETENTION_HOURS &&
    configured <= MAX_REPLAY_RETENTION_HOURS
      ? configured
      : DEFAULT_REPLAY_RETENTION_HOURS;
  return new Date(now.getTime() + hours * 60 * 60 * 1_000);
}
