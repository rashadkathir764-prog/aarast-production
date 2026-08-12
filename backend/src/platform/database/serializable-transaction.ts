import { Prisma } from "@prisma/client";
import { PrismaService } from "./prisma.service";

const DEFAULT_ATTEMPTS = 4;

export interface RetryableTransactionOptions {
  maxAttempts?: number;
  maxWait?: number;
  timeout?: number;
  isolationLevel?: Prisma.TransactionIsolationLevel;
}

/**
 * Runs an interactive transaction and retries only PostgreSQL
 * serialization/deadlock failures. Callers that need READ COMMITTED semantics
 * (for example, an advisory-lock snapshot hand-off) can omit isolationLevel.
 */
export async function runRetryableTransaction<T>(
  prisma: PrismaService,
  operation: (tx: Prisma.TransactionClient) => Promise<T>,
  options: RetryableTransactionOptions = {},
): Promise<T> {
  const {
    maxAttempts = DEFAULT_ATTEMPTS,
    maxWait,
    timeout,
    isolationLevel,
  } = options;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await prisma.$transaction(operation, {
        ...(maxWait !== undefined ? { maxWait } : {}),
        ...(timeout !== undefined ? { timeout } : {}),
        ...(isolationLevel !== undefined ? { isolationLevel } : {}),
      });
    } catch (error) {
      if (!isRetryableTransactionError(error) || attempt === maxAttempts) {
        throw error;
      }
      await new Promise<void>((resolve) =>
        setTimeout(resolve, Math.min(15 * attempt, 60)),
      );
    }
  }
  throw new Error("Retryable transaction retry loop exhausted");
}

/**
 * Runs a money-domain transaction at SERIALIZABLE isolation and retries only
 * PostgreSQL serialization/deadlock failures. Business errors are never
 * swallowed or retried.
 */
export async function runSerializableTransaction<T>(
  prisma: PrismaService,
  operation: (tx: Prisma.TransactionClient) => Promise<T>,
  maxAttempts = DEFAULT_ATTEMPTS,
): Promise<T> {
  return runRetryableTransaction(prisma, operation, {
    maxAttempts,
    isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
  });
}

function isRetryableTransactionError(error: unknown): boolean {
  if (!(error instanceof Prisma.PrismaClientKnownRequestError)) return false;
  if (error.code === "P2034") return true;
  if (error.code !== "P2010") return false;
  const databaseCode = String(
    (error.meta as Record<string, unknown> | undefined)?.code ?? "",
  );
  return databaseCode === "40001" || databaseCode === "40P01";
}
