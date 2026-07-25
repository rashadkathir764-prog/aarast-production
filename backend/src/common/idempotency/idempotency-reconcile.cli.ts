import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { PrismaClient } from "@prisma/client";
import {
  IdempotencyReconciliationError,
  reconcileAmbiguousIdempotencyKey,
  type ReconciledResponse,
} from "./idempotency-reconciliation";

type Environment = Record<string, string | undefined>;

export type ReconciliationCommand =
  | { action: "list" }
  | { action: "inspect"; id: string }
  | {
      action: "release";
      id: string;
      expectedMethod: string;
      expectedPath: string;
    }
  | {
      action: "complete";
      id: string;
      expectedMethod: string;
      expectedPath: string;
      responseFile: string;
    };

const allowedArguments = new Set([
  "action",
  "id",
  "expected-method",
  "expected-path",
  "proof",
  "response-file",
]);

export function reconciliationConfirmation(id: string): string {
  return `RECONCILE_IDEMPOTENCY_${id}`;
}

export function parseReconciliationCommand(
  args: string[],
  environment: Environment,
): ReconciliationCommand {
  const values = parseArguments(args);
  const action = values.get("action");
  if (action === "list") {
    assertOnlyArguments(values, ["action"]);
    return { action };
  }
  const id = requiredArgument(values, "id");
  if (!/^c[a-z0-9]{15,35}$/.test(id)) {
    throw new Error("--id must be an exact IdempotencyKey cuid.");
  }
  if (action === "inspect") {
    assertOnlyArguments(values, ["action", "id"]);
    return { action, id };
  }
  if (action !== "release" && action !== "complete") {
    throw new Error("--action must be list, inspect, release, or complete.");
  }

  const expectedMethod = requiredArgument(
    values,
    "expected-method",
  ).toUpperCase();
  const expectedPath = requiredArgument(values, "expected-path");
  const expectedProof =
    action === "release" ? "no-domain-commit" : "domain-commit-verified";
  if (values.get("proof") !== expectedProof) {
    throw new Error(
      `--proof must equal ${expectedProof} for ${action}.`,
    );
  }
  if (
    environment.IDEMPOTENCY_RECONCILE_CONFIRM !==
    reconciliationConfirmation(id)
  ) {
    throw new Error(
      `IDEMPOTENCY_RECONCILE_CONFIRM must equal ${reconciliationConfirmation(id)}.`,
    );
  }

  if (action === "release") {
    assertOnlyArguments(values, [
      "action",
      "id",
      "expected-method",
      "expected-path",
      "proof",
    ]);
    return { action, id, expectedMethod, expectedPath };
  }

  assertOnlyArguments(values, [
    "action",
    "id",
    "expected-method",
    "expected-path",
    "proof",
    "response-file",
  ]);
  return {
    action,
    id,
    expectedMethod,
    expectedPath,
    responseFile: requiredArgument(values, "response-file"),
  };
}

function parseArguments(args: string[]): Map<string, string> {
  const values = new Map<string, string>();
  for (const argument of args) {
    const match = /^--([a-z-]+)=(.+)$/.exec(argument);
    if (!match || !allowedArguments.has(match[1])) {
      throw new Error(`Unknown or malformed argument: ${argument}`);
    }
    if (values.has(match[1])) {
      throw new Error(`Duplicate argument: --${match[1]}`);
    }
    values.set(match[1], match[2]);
  }
  return values;
}

function requiredArgument(values: Map<string, string>, name: string): string {
  const value = values.get(name)?.trim();
  if (!value) throw new Error(`--${name} is required.`);
  return value;
}

function assertOnlyArguments(
  values: Map<string, string>,
  allowed: string[],
): void {
  const allowedSet = new Set(allowed);
  const unexpected = [...values.keys()].find((key) => !allowedSet.has(key));
  if (unexpected) {
    throw new Error(`--${unexpected} is not valid for this action.`);
  }
}

function readReconciledResponse(filePath: string): ReconciledResponse {
  const contents = readFileSync(resolve(filePath));
  if (contents.byteLength > 128 * 1_024) {
    throw new Error("Reconciliation response file exceeds 128 KiB.");
  }
  const parsed = JSON.parse(contents.toString("utf8")) as unknown;
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error(
      "Reconciliation response file must contain one JSON object.",
    );
  }
  const record = parsed as Record<string, unknown>;
  return {
    body: record.body,
    statusCode: record.statusCode as number,
    ...(record.headers &&
    typeof record.headers === "object" &&
    !Array.isArray(record.headers)
      ? {
          headers: record.headers as Record<string, string | string[]>,
        }
      : {}),
  };
}

function isSafeRouteTemplate(path: string): boolean {
  return path.startsWith("/") && !path.includes("?") && path.length <= 512;
}

async function execute(command: ReconciliationCommand): Promise<void> {
  if (!process.env.DATABASE_URL) {
    throw new Error("DATABASE_URL is required.");
  }
  const prisma = new PrismaClient();
  try {
    if (command.action === "list") {
      const rows = await prisma.idempotencyKey.findMany({
        where: {
          completedAt: null,
          expiresAt: { lte: new Date() },
        },
        select: {
          id: true,
          method: true,
          path: true,
          createdAt: true,
          expiresAt: true,
        },
        orderBy: [{ expiresAt: "asc" }, { id: "asc" }],
        take: 100,
      });
      console.log(
        JSON.stringify({
          items: rows.map((row) => {
            const safePath = isSafeRouteTemplate(row.path);
            return {
              id: row.id,
              method: row.method,
              path: safePath ? row.path : "[redacted-unsafe-path]",
              reconcilable: safePath,
              createdAt: row.createdAt.toISOString(),
              expiresAt: row.expiresAt.toISOString(),
            };
          }),
          limited: rows.length === 100,
        }),
      );
      return;
    }
    if (command.action === "inspect") {
      const row = await prisma.idempotencyKey.findUnique({
        where: { id: command.id },
        select: {
          id: true,
          method: true,
          path: true,
          completedAt: true,
          expiresAt: true,
          createdAt: true,
        },
      });
      if (!row) {
        throw new IdempotencyReconciliationError(
          "Idempotency key was not found.",
        );
      }
      const safePath = isSafeRouteTemplate(row.path);
      console.log(
        JSON.stringify({
          id: row.id,
          state: row.completedAt
            ? "COMPLETED"
            : row.expiresAt.getTime() > Date.now()
              ? "ACTIVE"
              : "AMBIGUOUS_EXPIRED",
          method: row.method,
          path: safePath ? row.path : "[redacted-unsafe-path]",
          reconcilable: !row.completedAt && safePath,
          createdAt: row.createdAt.toISOString(),
          expiresAt: row.expiresAt.toISOString(),
        }),
      );
      return;
    }

    const resolution =
      command.action === "release"
        ? ({ outcome: "NO_COMMIT" } as const)
        : ({
            outcome: "COMMITTED",
            response: readReconciledResponse(command.responseFile),
          } as const);
    const result = await reconcileAmbiguousIdempotencyKey(prisma as any, {
      id: command.id,
      expectedMethod: command.expectedMethod,
      expectedPath: command.expectedPath,
      resolution,
    });
    console.log(JSON.stringify(result));
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  const command = parseReconciliationCommand(
    process.argv.slice(2),
    process.env,
  );
  execute(command).catch((error) => {
    console.error(error instanceof Error ? error.message : "Reconciliation failed.");
    process.exitCode = 1;
  });
}
