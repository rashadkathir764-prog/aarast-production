import "reflect-metadata";

import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { test } from "node:test";
import { plainToInstance } from "class-transformer";
import { validate } from "class-validator";
import {
  ImportLocalPlanDto,
  LOCAL_PLAN_IMPORT_COSTS_MAX,
  LOCAL_PLAN_IMPORT_TASKS_MAX,
} from "../src/onboarding/dto/import-local-plan.dto";
import { PLAN_GUESTS_MAX } from "../src/modules/guests/public/guest-text-limits";
import { largeJsonBody } from "../src/platform/http/large-json-body";
import { localPlanImportHash } from "../src/wedding-plans/wedding-plans.service";

const dto = (value: Record<string, unknown>) =>
  plainToInstance(ImportLocalPlanDto, { clientMigrationId: "guest-plan-1", ...value });

// RA-BE-65: the same plan read again in another order is the same save; any
// change in what it holds is another; the save's id is not part of it.
test("a local plan's fingerprint is its content, in any order, without its id", () => {
  const plan = {
    title: "عرس محمد",
    guests: [{ name: "أبو محمد", phone: "+967771234500" }, { name: "خالد" }],
    tasks: [{ title: "القاعة" }, { title: "الكوشة" }],
  };
  const base = localPlanImportHash(dto(plan));
  assert.equal(
    localPlanImportHash(dto({ ...plan, guests: [...plan.guests].reverse(), tasks: [...plan.tasks].reverse() })),
    base,
  );
  assert.equal(localPlanImportHash(dto({ ...plan, clientMigrationId: "guest-plan-1~2" })), base);
  assert.notEqual(localPlanImportHash(dto({ ...plan, guests: [...plan.guests, { name: "جديد" }] })), base);
  assert.notEqual(localPlanImportHash(dto({ ...plan, title: "عرس أحمد" })), base);
});

// RA-BE-64: one save takes what a plan holds.
test("the import takes as many guests as a plan holds, and bounded tasks and agreements", async () => {
  const errors = async (value: Record<string, unknown>) =>
    (await validate(dto(value))).map((error) => error.property);
  const many = (count: number, item: (index: number) => object) =>
    Array.from({ length: count }, (_, index) => item(index));

  assert.equal(PLAN_GUESTS_MAX, 5000);
  assert.deepEqual(await errors({ guests: many(PLAN_GUESTS_MAX, (i) => ({ name: `ضيف ${i}` })) }), []);
  assert.deepEqual(await errors({ guests: many(PLAN_GUESTS_MAX + 1, (i) => ({ name: `ضيف ${i}` })) }), ["guests"]);
  assert.deepEqual(await errors({ tasks: many(LOCAL_PLAN_IMPORT_TASKS_MAX, (i) => ({ title: `مهمة ${i}` })) }), []);
  assert.deepEqual(await errors({ tasks: many(LOCAL_PLAN_IMPORT_TASKS_MAX + 1, (i) => ({ title: `مهمة ${i}` })) }), ["tasks"]);
  const cost = (i: number) => ({ title: `اتفاق ${i}`, totalAmount: "1000", categoryName: "القاعة" });
  assert.deepEqual(await errors({ costs: many(LOCAL_PLAN_IMPORT_COSTS_MAX, cost) }), []);
  assert.deepEqual(await errors({ costs: many(LOCAL_PLAN_IMPORT_COSTS_MAX + 1, cost) }), ["costs"]);
});

/** A request as Node's HTTP server hands it, its body streamed in [chunks]. */
function request(headers: Record<string, string>, chunks: string[]) {
  const emitter = new EventEmitter() as EventEmitter & {
    headers: Record<string, string>;
    body?: unknown;
    resume: () => void;
  };
  emitter.headers = headers;
  emitter.resume = () => undefined;
  setImmediate(() => {
    for (const chunk of chunks) emitter.emit("data", Buffer.from(chunk));
    emitter.emit("end");
  });
  return emitter;
}

function run(limit: number, req: ReturnType<typeof request>) {
  return new Promise<{ error?: any; req: typeof req }>((resolve) => {
    largeJsonBody(limit)(req as never, {} as never, (error?: unknown) => resolve({ error, req }));
  });
}

const signedIn = { authorization: "Bearer token", "content-type": "application/json" };

test("the import's body is read up to its own limit for a signed-in JSON request", async () => {
  const body = JSON.stringify({ guests: [{ name: "ضيف" }] });
  const read = await run(1024, request(signedIn, [body.slice(0, 5), body.slice(5)]));
  assert.equal(read.error, undefined);
  assert.deepEqual(read.req.body, { guests: [{ name: "ضيف" }] });

  const tooLarge = await run(8, request(signedIn, ['{"a":"0123456789"}']));
  assert.equal(tooLarge.error?.status, 413);
  assert.equal(tooLarge.error?.type, "entity.too.large");

  const declared = await run(8, request({ ...signedIn, "content-length": "9000" }, []));
  assert.equal(declared.error?.status, 413);

  const broken = await run(1024, request(signedIn, ["{not json"]));
  assert.equal(broken.error?.status, 400);
  assert.equal(broken.error?.type, "entity.parse.failed");
});

test("without a session, or not plain JSON, the request goes on to the default parser untouched", async () => {
  for (const headers of [
    { "content-type": "application/json" },
    { ...signedIn, "content-encoding": "gzip" },
    { ...signedIn, "content-type": "application/json; charset=utf-16" },
    { authorization: "Bearer token", "content-type": "text/plain" },
  ]) {
    const passed = await run(1024, request(headers, ['{"a":1}']));
    assert.equal(passed.error, undefined);
    assert.equal(passed.req.body, undefined);
  }
});
