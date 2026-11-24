import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import {
  findProviderIdsMatchingSearch,
  findServiceIdsMatchingSearch,
  likePatternContaining,
  searchActiveProviders,
} from "../src/modules/marketplace/infrastructure/marketplace-core.repository";
import { arabicSearchKey } from "../src/shared-kernel/text/arabic-search";

// RA-BE-181: the marketplace search matched `strpos(translate(lower(...)))`
// on every row, which no index can serve, and the page's total was a second
// pass over the same filter. The text is matched now with LIKE against the
// folded text the trigram indexes hold (migration 20261125130000), and the
// total comes from the ranked candidates the page is cut from.

function recordingClient(rows: unknown[] = []) {
  const statements: Array<{ sql: string; values: unknown[] }> = [];
  const client: any = {
    $queryRaw: async (query: Prisma.Sql) => {
      statements.push({ sql: query.sql, values: query.values });
      return rows;
    },
  };
  return { client, statements };
}

test("the provider search is a LIKE on the indexed folded text, in one statement", async () => {
  const { client, statements } = recordingClient([{ id: "p1" }]);
  const key = arabicSearchKey("قاعة سبأ");
  assert.deepEqual(await findProviderIdsMatchingSearch(client, key), ["p1"]);
  assert.equal(statements.length, 1);
  const { sql, values } = statements[0];
  assert.doesNotMatch(sql, /strpos/);
  assert.match(sql, /"aarast_provider_search_text"\(p\."businessName", p\."ownerName", p\."description", p\."address"\) LIKE/);
  assert.match(sql, /"aarast_service_search_text"\(s\."title", s\."description"\) LIKE/);
  assert.match(sql, /s\."isActive" = true/);
  assert.match(sql, /UNION/);
  assert.ok(values.every((value) => value === `%${key}%`), "the one pattern, bound");
});

test("the service search matches the service's text or its provider's name, each on its own index", async () => {
  const { client, statements } = recordingClient([{ id: "s1" }, { id: "s2" }]);
  assert.deepEqual(await findServiceIdsMatchingSearch(client, "قاعه"), ["s1", "s2"]);
  assert.equal(statements.length, 1);
  const { sql } = statements[0];
  assert.doesNotMatch(sql, /strpos/);
  assert.match(sql, /"aarast_service_search_text"\(s\."title", s\."description"\) LIKE/);
  assert.match(sql, /"aarast_search_fold"\(p\."businessName"\) LIKE/);
  assert.match(sql, /UNION/);
});

test("a key's own % _ and \\ are matched as themselves, not as wildcards", () => {
  assert.equal(likePatternContaining("50%_off"), "%50\\%\\_off%");
  assert.equal(likePatternContaining("a\\b"), "%a\\\\b%");
  assert.equal(likePatternContaining("قاعه"), "%قاعه%");
});

test("the page's total is the ranked candidates, with no second count of the same filter", async () => {
  const day = new Date("2026-01-01T00:00:00.000Z");
  const candidate = (id: string) => ({
    id,
    userId: `u-${id}`,
    ratingAverage: new Prisma.Decimal("4"),
    ratingCount: 3,
    createdAt: day,
    logoUrl: "l",
    coverUrl: "c",
    description: "d",
    address: "a",
    whatsapp: "w",
    socialLinks: null,
    featuredPeriods: [],
  });
  const reads: string[] = [];
  const client: any = {
    $queryRaw: async () => [],
    provider: {
      count: async () => {
        reads.push("count");
        return -1;
      },
      findMany: async (args: any) => {
        if (args.where.id) {
          reads.push("page");
          return args.where.id.in.map((id: string) => ({ id, featuredPeriods: [] }));
        }
        reads.push("candidates");
        return ["a", "b", "c", "d", "e"].map(candidate);
      },
    },
  };
  const result = await searchActiveProviders(
    client,
    { AND: [] } as any,
    { page: 2, limit: 2, skip: 2 },
    new Date("2026-11-24T10:00:00.000Z"),
  );
  assert.equal(result.total, 5);
  assert.equal(result.rows.length, 2);
  assert.deepEqual(reads, ["candidates", "page"], "no count query");

  const past = await searchActiveProviders(
    client,
    { AND: [] } as any,
    { page: 9, limit: 2, skip: 16 },
    new Date("2026-11-24T10:00:00.000Z"),
  );
  assert.deepEqual(past, { total: 5, rows: [] }, "a page past the end still knows the total");
});
