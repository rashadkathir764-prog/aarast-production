import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ReferenceCatalogService } from "../src/catalogs/reference-catalog.service";

// Items seeded after a device cached the catalog must change the bootstrap
// version, or that device keeps answering "unchanged" and never sees them.

function catalogRows(itemKeys: string[]) {
  const updatedAt = new Date("2026-10-01T00:00:00.000Z");
  return [
    [
      {
        key: "money.starter.categories",
        nameAr: "تصنيفات",
        description: null,
        version: 1,
        updatedAt,
        items: itemKeys.map((key) => ({
          key,
          publishedRevision: 1,
          revisions: [{ revision: 1, isActive: true, nameAr: key }],
        })),
      },
    ],
    [],
    [],
    [],
    { _max: { updatedAt: null } },
    { _max: { updatedAt: null } },
  ];
}

function serviceReturning(itemKeys: string[]) {
  const service = new ReferenceCatalogService({} as any, {} as any) as any;
  service.seedPromise = Promise.resolve();
  service.repository = { bootstrapRows: async () => catalogRows(itemKeys) };
  service.toPublishedItem = (key: string) => ({ key });
  return service as ReferenceCatalogService;
}

test("a newly seeded catalog item changes the bootstrap version", async () => {
  const before = await serviceReturning(["groom-mahr"]).getBootstrap();
  const after = await serviceReturning(["groom-mahr", "groom-qat"]).getBootstrap();

  assert.notEqual(after.version, before.version);
  assert.deepEqual(
    await serviceReturning(["groom-mahr", "groom-qat"]).getBootstrap(before.version),
    { ...after, unchanged: false },
  );
  assert.deepEqual(
    await serviceReturning(["groom-mahr"]).getBootstrap(before.version),
    { version: before.version, unchanged: true },
  );
});
