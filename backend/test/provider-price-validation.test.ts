import type { ConversationLifecyclePort } from "../src/modules/messaging/public/conversation-lifecycle.port";
import { lockConversationForShare, lockConversationForUpdate } from "../src/conversations/conversation-lifecycle";

const lifecycle: ConversationLifecyclePort = {
  ensureConversationContext: async () => { throw new Error("Unexpected ensureConversationContext"); },
  recordConversationEvent: async () => { throw new Error("Unexpected recordConversationEvent"); },
  lockConversationForUpdateInTransaction: lockConversationForUpdate,
  lockConversationForShareInTransaction: lockConversationForShare,
};
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";
import { BadRequestException } from "@nestjs/common";
import { ProviderStatus } from "@prisma/client";
import { optionalMoneyAmount } from "../src/shared-kernel/money/money";
import { providerDashboardService } from "./support/owner-ports";

test("provider service prices fail at validation before Prisma can round or overflow", async () => {
  let writes = 0;
  const prisma = {
    provider: {
      findUnique: async () => ({
        id: "provider-1",
        userId: "user-1",
        status: ProviderStatus.ACTIVE,
      }),
    },
    providerCategory: {
      findFirst: async () => ({ id: "11111111-1111-4111-8111-111111111111" }),
    },
    providerService: {
      create: async () => {
        writes += 1;
        throw new Error("database write reached");
      },
    },
  };
  const service = providerDashboardService(
    prisma as any,
    {} as any,
    {} as any, lifecycle,
  );

  for (const basePrice of ["9999999999999", "10.999"]) {
    await assert.rejects(
      () =>
        service.createService(
          { id: "user-1" } as any,
          {
            categoryId: "11111111-1111-4111-8111-111111111111",
            title: "Service",
            basePrice,
          },
        ),
      BadRequestException,
      basePrice,
    );
  }
  assert.equal(writes, 0);
});

test("provider catalog prices stay optional while quote offers require positive money", () => {
  assert.equal(optionalMoneyAmount(undefined, "price"), null);
  assert.equal(optionalMoneyAmount(null, "price"), null);
  assert.equal(optionalMoneyAmount("  ", "price"), null);
  assert.equal(optionalMoneyAmount("999.25", "price"), "999.25");
  assert.equal(
    optionalMoneyAmount("999999999999.99", "price"),
    "999999999999.99",
  );

  const source = readFileSync(
    join(
      __dirname,
      "..",
      "src",
      "provider-dashboard",
      "provider-dashboard.service.ts",
    ),
    "utf8",
  );
  const adminSource = readFileSync(
    join(
      __dirname,
      "..",
      "src",
      "admin",
      "admin-mutation-executor.ts",
    ),
    "utf8",
  );
  const marketplaceSource = readFileSync(
    join(
      __dirname,
      "..",
      "src",
      "marketplace",
      "marketplace.presenter.ts",
    ),
    "utf8",
  );
  assert.match(source, /optionalMoneyAmount/);
  assert.ok(
    (source.match(/optionalMoneyAmount\(/g) ?? []).length >= 4,
    "service and package create/update paths use the optional validator",
  );
  assert.ok(
    (source.match(/requiredPositiveMoneyAmount\(/g) ?? []).length >= 3,
    "quote-offer create/update paths require a positive amount",
  );
  assert.doesNotMatch(source, /private optionalDecimal/);
  assert.doesNotMatch(source, /\^\\d\+\\\(\\\.\\d\+\\\)\\\?\$/);
  assert.match(adminSource, /optionalMoneyAmount/);
  assert.doesNotMatch(adminSource, /private optionalDecimal/);
  assert.match(marketplaceSource, /optionalMoneyAmount/);
});
