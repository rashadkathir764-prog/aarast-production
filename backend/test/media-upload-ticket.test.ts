import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import {
  HttpException,
  HttpStatus,
  NotFoundException,
} from "@nestjs/common";
import { MediaUploadStatus } from "@prisma/client";
import { MediaUploadCleanupScheduler } from "../src/media/media-upload-cleanup.scheduler";
import { MediaUploadTicketService } from "../src/modules/media/infrastructure/media-upload-ticket.service";

type Ticket = {
  key: string;
  userId: string;
  purpose: string;
  contentType: string;
  declaredByteSize: number;
  verifiedByteSize: number | null;
  status: MediaUploadStatus;
  expiresAt: Date;
  verifiedAt: Date | null;
  consumedAt: Date | null;
  consumedByType: string | null;
  consumedById: string | null;
  deletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

function ticketHarness() {
  const records = new Map<string, Ticket>();
  let advisoryLocks = 0;
  const mediaUploadTicket = {
    count: async ({ where }: any) =>
      [...records.values()].filter(
        (item) =>
          item.userId === where.userId &&
          item.createdAt.getTime() >= where.createdAt.gte.getTime(),
      ).length,
    aggregate: async ({ where }: any) => ({
      _sum: {
        declaredByteSize: [...records.values()]
          .filter(
            (item) =>
              item.userId === where.userId &&
              item.createdAt.getTime() >= where.createdAt.gte.getTime(),
          )
          .reduce((sum, item) => sum + item.declaredByteSize, 0),
      },
    }),
    create: async ({ data }: any) => {
      const now = new Date();
      const row: Ticket = {
        ...data,
        verifiedByteSize: null,
        status: MediaUploadStatus.PENDING,
        verifiedAt: null,
        consumedAt: null,
        consumedByType: null,
        consumedById: null,
        deletedAt: null,
        createdAt: now,
        updatedAt: now,
      };
      records.set(row.key, row);
      return row;
    },
    findUnique: async ({ where, select }: any) => {
      const row = records.get(where.key);
      if (!row) return null;
      if (!select) return { ...row };
      return Object.fromEntries(
        Object.keys(select).map((key) => [key, (row as any)[key]]),
      );
    },
    updateMany: async ({ where, data }: any) => {
      const rows = [...records.values()].filter((row) => {
        if (where.key && typeof where.key === "string" && row.key !== where.key)
          return false;
        if (where.key?.in && !where.key.in.includes(row.key)) return false;
        if (where.userId && row.userId !== where.userId) return false;
        if (where.purpose && row.purpose !== where.purpose) return false;
        if (typeof where.status === "string" && row.status !== where.status)
          return false;
        if (where.status?.not && row.status === where.status.not) return false;
        if (where.consumedByType && row.consumedByType !== where.consumedByType)
          return false;
        if (where.consumedById && row.consumedById !== where.consumedById)
          return false;
        if (
          where.OR &&
          !where.OR.some((option: any) =>
            option.consumedAt === null
              ? row.consumedAt === null
              : row.consumedByType === option.consumedByType &&
                row.consumedById === option.consumedById,
          )
        )
          return false;
        if (
          where.expiresAt?.gt &&
          row.expiresAt.getTime() <= where.expiresAt.gt.getTime()
        )
          return false;
        return true;
      });
      for (const row of rows) {
        Object.assign(row, data, { updatedAt: new Date() });
      }
      return { count: rows.length };
    },
    deleteMany: async ({ where }: any) => {
      let count = 0;
      for (const row of [...records.values()]) {
        if (where.key && row.key !== where.key) continue;
        if (where.userId && row.userId !== where.userId) continue;
        if (where.status && row.status !== where.status) continue;
        records.delete(row.key);
        count += 1;
      }
      return { count };
    },
  };
  const prisma = {
    mediaUploadTicket,
    $transaction: async (operation: any) =>
      operation({
        mediaUploadTicket,
        $queryRaw: async (query: any) => {
          const text = Array.isArray(query)
            ? query.join("")
            : (query?.strings?.join("") ?? "");
          if (text.includes('FROM "User"')) {
            return [{ id: "u1", status: "ACTIVE" }];
          }
          advisoryLocks += 1;
          return [{ locked: true }];
        },
      }),
  };
  return {
    service: new MediaUploadTicketService(prisma as any),
    records,
    advisoryLockCount: () => advisoryLocks,
  };
}

test("upload reservations are durable and quota accounting is serialized", async () => {
  const { service, records, advisoryLockCount } = ticketHarness();
  await service.reserveUpload({
    key: "service-image/u1/550e8400-e29b-41d4-a716-446655440000.webp",
    userId: "u1",
    purpose: "service-image",
    contentType: "image/webp",
    declaredByteSize: 2_048,
  });

  assert.equal(advisoryLockCount(), 1);
  assert.equal(records.size, 1);
  const [ticket] = records.values();
  assert.equal(ticket.status, MediaUploadStatus.PENDING);
  assert.ok(ticket.expiresAt.getTime() > Date.now());
});

test("application identity deletion preserves the administrator avatar ticket", async () => {
  let whereSeen: unknown;
  let updatedKeys: string[] = [];
  const service = new MediaUploadTicketService({} as any);
  const tx = {
    $queryRaw: async () => [{ locked: true }],
    mediaUploadTicket: {
      findMany: async ({ where }: any) => {
        whereSeen = where;
        return [{ key: "app-avatar" }, { key: "chat-image" }];
      },
      updateMany: async ({ where }: any) => {
        updatedKeys = where.key.in;
        return { count: updatedKeys.length };
      },
    },
  };

  assert.deepEqual(
    await service.scheduleApplicationIdentityDeletion("admin-user", tx as any),
    ["app-avatar", "chat-image"],
  );
  assert.deepEqual(whereSeen, {
    userId: "admin-user",
    status: { not: MediaUploadStatus.DELETED },
    NOT: { consumedByType: "USER_AVATAR" },
  });
  assert.deepEqual(updatedKeys, ["app-avatar", "chat-image"]);
});

test("rolling daily upload count is enforced before another ticket is created", async () => {
  let creates = 0;
  const service = new MediaUploadTicketService({
    $transaction: async (operation: any) =>
      operation({
        $queryRaw: async () => [
          { locked: true, id: "u1", status: "ACTIVE" },
        ],
        mediaUploadTicket: {
          count: async () =>
            MediaUploadTicketService.maximumUploadsPerRollingDay,
          aggregate: async () => ({ _sum: { declaredByteSize: 0 } }),
          create: async () => {
            creates += 1;
          },
        },
      }),
  } as any);

  await assert.rejects(
    () =>
      service.reserveUpload({
        key: "user-avatar/u1/550e8400-e29b-41d4-a716-446655440000.webp",
        userId: "u1",
        purpose: "user-avatar",
        contentType: "image/webp",
        declaredByteSize: 1,
      }),
    (error: unknown) =>
      error instanceof HttpException &&
      error.getStatus() === HttpStatus.TOO_MANY_REQUESTS,
  );
  assert.equal(creates, 0);
});

test("rolling daily declared-byte quota is enforced even below the count cap", async () => {
  let creates = 0;
  const service = new MediaUploadTicketService({
    $transaction: async (operation: any) =>
      operation({
        $queryRaw: async () => [
          { locked: true, id: "u1", status: "ACTIVE" },
        ],
        mediaUploadTicket: {
          count: async () => 1,
          aggregate: async () => ({
            _sum: {
              declaredByteSize:
                MediaUploadTicketService.maximumDeclaredBytesPerRollingDay,
            },
          }),
          create: async () => {
            creates += 1;
          },
        },
      }),
  } as any);

  await assert.rejects(
    () =>
      service.reserveUpload({
        key: "user-avatar/u1/550e8400-e29b-41d4-a716-446655440000.webp",
        userId: "u1",
        purpose: "user-avatar",
        contentType: "image/webp",
        declaredByteSize: 1,
      }),
    (error: unknown) =>
      error instanceof HttpException &&
      error.getStatus() === HttpStatus.TOO_MANY_REQUESTS,
  );
  assert.equal(creates, 0);
});

test("a disabled account cannot reserve a new media upload", async () => {
  let creates = 0;
  const service = new MediaUploadTicketService({
    $transaction: async (operation: any) =>
      operation({
        $queryRaw: async () => [
          { locked: true, id: "u1", status: "DISABLED" },
        ],
        mediaUploadTicket: {
          count: async () => 0,
          aggregate: async () => ({ _sum: { declaredByteSize: 0 } }),
          create: async () => {
            creates += 1;
          },
        },
      }),
  } as any);

  await assert.rejects(
    () =>
      service.reserveUpload({
        key: "user-avatar/u1/550e8400-e29b-41d4-a716-446655440000.webp",
        userId: "u1",
        purpose: "user-avatar",
        contentType: "image/webp",
        declaredByteSize: 1,
      }),
    NotFoundException,
  );
  assert.equal(creates, 0);
});

test("a disabled account cannot claim an upload for verification", async () => {
  const key =
    "chat-image/u1/550e8400-e29b-41d4-a716-446655440000.webp";
  let transactionCalls = 0;
  let ticketReads = 0;
  let ticketWrites = 0;
  const lockOrder: string[] = [];
  const mediaUploadTicket = {
    findUnique: async () => {
      ticketReads += 1;
      return {
        userId: "u1",
        purpose: "chat-image",
        status: MediaUploadStatus.PENDING,
        expiresAt: new Date(Date.now() + 60_000),
      };
    },
    updateMany: async () => {
      ticketWrites += 1;
      return { count: 1 };
    },
  };
  const service = new MediaUploadTicketService({
    mediaUploadTicket,
    $transaction: async (operation: any) => {
      transactionCalls += 1;
      return operation({
        mediaUploadTicket,
        $queryRaw: async (query: any) => {
          const text = Array.isArray(query)
            ? query.join("")
            : (query?.strings?.join("") ?? "");
          if (text.includes("pg_advisory_xact_lock")) {
            lockOrder.push("account");
            return [{ locked: true }];
          }
          if (text.includes('FROM "User"')) {
            lockOrder.push("user");
            return [{ id: "u1", status: "DISABLED" }];
          }
          throw new Error(`Unexpected lock query: ${text}`);
        },
      });
    },
  } as any);

  await assert.rejects(
    () => service.claimForVerification(key, "u1", "chat-image"),
    NotFoundException,
  );
  assert.equal(transactionCalls, 1);
  assert.deepEqual(lockOrder, ["account", "user"]);
  assert.equal(ticketReads, 0);
  assert.equal(ticketWrites, 0);
});

test("verification claim, verified state and consumption are explicit", async () => {
  const { service, records } = ticketHarness();
  const key =
    "chat-image/u1/550e8400-e29b-41d4-a716-446655440000.webp";
  await service.reserveUpload({
    key,
    userId: "u1",
    purpose: "chat-image",
    contentType: "image/webp",
    declaredByteSize: 2_048,
  });

  assert.deepEqual(await service.claimForVerification(key, "u1", "chat-image"), {
    alreadyVerified: false,
  });
  assert.equal(records.get(key)?.status, MediaUploadStatus.VERIFYING);
  await service.markVerified(key, 1_024);
  assert.equal(records.get(key)?.verifiedByteSize, 1_024);
  assert.deepEqual(await service.claimForVerification(key, "u1", "chat-image"), {
    alreadyVerified: true,
  });
  await service.consume(
    key,
    "u1",
    { type: "CHAT_ATTACHMENT", id: "attachment-1" },
    {
      mediaUploadTicket: (service as any).prisma.mediaUploadTicket,
      $queryRaw: async () => [{ locked: true }],
    } as any,
  );
  assert.ok(records.get(key)?.consumedAt instanceof Date);
  assert.equal(records.get(key)?.consumedById, "attachment-1");
  await assert.rejects(() =>
    service.consume(
      key,
      "u1",
      { type: "CHAT_ATTACHMENT", id: "attachment-2" },
      {
        mediaUploadTicket: (service as any).prisma.mediaUploadTicket,
        $queryRaw: async () => [{ locked: true }],
      } as any,
    ),
  );
  await assert.rejects(() =>
    service.claimForVerification(key, "u2", "chat-image"),
  );
});

test("cleanup confirms successful object deletion and retains failures for retry", async () => {
  const scheduler = new MediaUploadCleanupScheduler(
    {
      claimCleanupBatch: async () => ["delete-me", "retry-me"],
      countCleanupBacklog: async () => 0,
    } as any,
    {
      deleteScheduledObjects: async () => ({ deleted: 1, failed: 1 }),
    } as any,
  );

  assert.deepEqual(await scheduler.removeAbandonedUploads(), {
    claimed: 2,
    deleted: 1,
    failed: 1,
  });
});

test("database migration enforces one live verified upload per domain target", () => {
  const migration = readFileSync(
    join(
      process.cwd(),
      "prisma/migrations/20260712003000_enforce_unique_media_target/migration.sql",
    ),
    "utf8",
  );
  assert.match(migration, /CREATE UNIQUE INDEX/);
  assert.match(migration, /"consumedByType", "consumedById"/);
  assert.match(migration, /WHERE "status" = 'VERIFIED'/);
  assert.match(migration, /"consumedAt" IS NOT NULL/);
});

test("GitHub media fixture runs the shared least-privilege initializer", () => {
  const workflow = readFileSync(
    join(process.cwd(), "../.github/workflows/ci.yml"),
    "utf8",
  );
  const compose = readFileSync(
    join(process.cwd(), "../docker-compose.yml"),
    "utf8",
  );

  assert.match(
    workflow,
    /docker compose run --rm --no-deps media-init/,
  );
  // The initializer is still MinIO's own client at one pinned release, with
  // the shared script and policy. Its image is built here from that
  // release's source: `minio/mc` is no longer served by any registry
  // (RA-OP-15), so the published name this test pinned cannot be pulled.
  assert.match(
    compose,
    /  media-init:\r?\n    image: aarast-media-client:RELEASE\.[^\s]+\r?\n    build:\r?\n      context: \.\/deploy\/media\r?\n      target: mc\r?\n[\s\S]*?source: media_init_script[\s\S]*?source: media_backend_policy[\s\S]*?entrypoint: \["\/bin\/sh", "\/opt\/aarast\/media\/init\.sh"\]/,
  );
  const mediaImages = readFileSync(
    join(process.cwd(), "../deploy/media/Dockerfile"),
    "utf8",
  );
  assert.match(
    mediaImages,
    /^RUN go install [^\n]*github\.com\/minio\/mc@RELEASE\.\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}Z$/m,
  );
  assert.match(mediaImages, /^FROM alpine:[^\s]+@sha256:[0-9a-f]{64} AS mc$/m);
});

test("cleanup skips when another replica owns the lock", async () => {
  let rawCalls = 0;
  const service = new MediaUploadTicketService({
    $transaction: async (operation: any) =>
      operation({
        $queryRaw: async () => {
          rawCalls += 1;
          return [{ locked: false }];
        },
        mediaUploadTicket: { deleteMany: async () => ({ count: 0 }) },
      }),
  } as any);

  assert.equal(await service.claimCleanupBatch(), null);
  assert.equal(rawCalls, 1);
});

test("cleanup claim is atomic, race-safe, and retains quota tombstones", async () => {
  const source = readFileSync(
    join(process.cwd(), "src/modules/media/infrastructure/media-upload-ticket.service.ts"),
    "utf8",
  );
  for (const required of [
    "FOR UPDATE SKIP LOCKED",
    'ticket."status" = \'PENDING\'',
    'ticket."status" = \'VERIFYING\'',
    'ticket."status" = \'VERIFIED\'',
    'ticket."consumedAt" IS NULL',
    'ticket."status" = \'DELETE_PENDING\'',
    'ticket."expiresAt" < ${now}',
    'SET "status" = \'DELETE_PENDING\'',
  ]) {
    assert.ok(source.includes(required), `cleanup SQL must include ${required}`);
  }
  assert.match(source, /status:\s*MediaUploadStatus\.DELETED/);
  assert.doesNotMatch(
    source,
    /confirmCleanupMany[\s\S]{0,350}mediaUploadTicket\.deleteMany/,
  );
});
