import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { findWeddingCostIdsMatchingSearch } from "../src/modules/finance/infrastructure/wedding-costs.repository";
import {
  arabicSearchKey,
  likePatternContaining,
} from "../src/shared-kernel/text/arabic-search";

// RA-BE-181: the admin's account, listing and review searches and the plan's
// agreement search matched `strpos(translate(lower(...)))`, which no index
// serves. They match the folded text with LIKE now, as the marketplace does
// (migration 20261125130000), on trigram indexes for the tables the admin
// reads whole (migration 20261125160000). The agreements are read within one
// plan, which its own index narrows to a few rows.

const root = join(__dirname, "..");
const read = (path: string) => readFileSync(join(root, path), "utf8");
const migration = read("prisma/migrations/20261125160000_admin_search_indexes/migration.sql");

const SEARCH_SOURCES = [
  "src/modules/identity/infrastructure/identity-admin.service.ts",
  "src/modules/marketplace/infrastructure/marketplace-admin.repository.ts",
  "src/modules/marketplace/infrastructure/provider-read.service.ts",
  "src/modules/finance/infrastructure/wedding-costs.repository.ts",
];

test("no search is left on strpos", () => {
  for (const path of SEARCH_SOURCES) {
    assert.doesNotMatch(read(path), /strpos\(/, path);
  }
});

test("each admin search matches the folded text with LIKE, on its own index", () => {
  const identity = read(SEARCH_SOURCES[0]);
  assert.match(identity, /WHERE "aarast_search_fold"\(u\."name"\) LIKE \$\{pattern\}/);
  const admin = read(SEARCH_SOURCES[1]);
  assert.match(admin, /"aarast_search_fold"\(p\."businessName"\) LIKE \$\{pattern\}\s+OR "aarast_search_fold"\(p\."ownerName"\) LIKE \$\{pattern\}/);
  assert.match(admin, /WHERE "aarast_search_fold"\(r\."comment"\) LIKE \$\{pattern\}\s+UNION/);
  const read_ = read(SEARCH_SOURCES[2]);
  assert.match(read_, /AND "aarast_search_fold"\(p\."businessName"\) LIKE \$\{pattern\}/);
  for (const [index, expression] of [
    ["User_name_trgm_idx", /ON "User" USING gin \(\s*"aarast_search_fold"\("name"\) gin_trgm_ops\)/],
    ["Provider_ownerName_trgm_idx", /ON "Provider" USING gin \(\s*"aarast_search_fold"\("ownerName"\) gin_trgm_ops\)/],
    ["ProviderReview_comment_trgm_idx", /ON "ProviderReview" USING gin \(\s*"aarast_search_fold"\("comment"\) gin_trgm_ops\)/],
  ] as const) {
    assert.match(migration, new RegExp(`CREATE INDEX "${index}"`));
    assert.match(migration, expression);
  }
});

test("the plan's agreement search is a LIKE on the folded title, party and item name", async () => {
  const statements: Array<{ sql: string; values: unknown[] }> = [];
  const tx: any = {
    $queryRaw: async (query: Prisma.Sql) => {
      statements.push({ sql: query.sql, values: query.values });
      return [{ id: "cost-1" }];
    },
  };
  const key = arabicSearchKey("قاعة 50%");
  assert.deepEqual(await findWeddingCostIdsMatchingSearch(tx, "plan-1", key, ["provider-1"]), ["cost-1"]);
  const { sql, values } = statements[0];
  assert.match(sql, /"aarast_search_fold"\(concat_ws\(chr\(1\), c\."title", c\."partyName", b\."name"\)\) LIKE/);
  assert.ok(values.includes(likePatternContaining(key)), "the key's own % is matched as itself");
  assert.ok(values.includes("plan-1"));
});
