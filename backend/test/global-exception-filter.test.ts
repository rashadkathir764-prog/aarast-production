import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import * as exceptionFilter from "../src/platform/http/global-exception.filter";
import { duplicateValueConflict } from "../src/platform/http/duplicate-value";

const shouldReportHttpException = (exceptionFilter as {
  shouldReportHttpException?: (route: string, status: number) => boolean;
}).shouldReportHttpException;

test("expected readiness probe failures do not create error telemetry", () => {
  assert.equal(shouldReportHttpException?.("GET /ready", 503), false);
});

// RA-AD-13: a taken unique value (a city's name, a category's slug) answered
// a bare English 409 that clients read as «the data changed, refresh»;
// refreshing never fixes a duplicate. It carries its own code.
test("a duplicate value is a 409 with the DUPLICATE_VALUE code", () => {
  const { GlobalExceptionFilter } = exceptionFilter;
  let status = 0;
  let body: any;
  const host: any = {
    switchToHttp: () => ({
      getResponse: () => ({
        status(code: number) {
          status = code;
          return this;
        },
        json(value: unknown) {
          body = value;
        },
      }),
      getRequest: () => ({ method: "POST", url: "/admin/cities" }),
    }),
  };
  const duplicate = new Prisma.PrismaClientKnownRequestError("Unique constraint failed", {
    code: "P2002",
    clientVersion: "test",
  });
  new GlobalExceptionFilter().catch(duplicate, host);
  assert.equal(status, 409);
  assert.equal(body.code, "DUPLICATE_VALUE");
});

test("an explicit duplicate refusal carries the same code", () => {
  const response = duplicateValueConflict("Catalog item key exists").getResponse() as any;
  assert.equal(response.statusCode, 409);
  assert.equal(response.code, "DUPLICATE_VALUE");
  assert.equal(response.message, "Catalog item key exists");
});

test("other server failures remain logged and reported", () => {
  assert.equal(shouldReportHttpException?.("GET /api/v1/users/me", 500), true);
  assert.equal(shouldReportHttpException?.("GET /ready", 500), true);
  assert.equal(shouldReportHttpException?.("GET /api/v1/users/me", 503), true);
});

// A body the server cannot read (too large, not JSON) is the client's: it
// was answered as a 500 with no reason, from any route.
test("a body too large or not JSON keeps its 4xx status, an Arabic reason and a code", () => {
  const { GlobalExceptionFilter } = exceptionFilter;
  const answer = (exception: unknown) => {
    let status = 0;
    let body: any;
    const host: any = {
      switchToHttp: () => ({
        getResponse: () => ({
          status(code: number) {
            status = code;
            return this;
          },
          json(value: unknown) {
            body = value;
          },
        }),
        getRequest: () => ({ method: "POST", url: "/api/v1/onboarding/import-local" }),
      }),
    };
    new GlobalExceptionFilter().catch(exception, host);
    return { status, body };
  };
  const tooLarge = answer(Object.assign(new Error("request entity too large"), { status: 413, type: "entity.too.large" }));
  assert.equal(tooLarge.status, 413);
  assert.equal(tooLarge.body.code, "REQUEST_TOO_LARGE");
  assert.match(tooLarge.body.message, /[؀-ۿ]/u);

  const notJson = answer(Object.assign(new SyntaxError("Unexpected token"), { status: 400, type: "entity.parse.failed" }));
  assert.equal(notJson.status, 400);
  assert.equal(notJson.body.code, "REQUEST_BODY_INVALID");

  // Anything else that only looks like it stays a 500.
  assert.equal(answer(Object.assign(new Error("boom"), { status: 413 })).status, 500);
  assert.equal(answer(Object.assign(new Error("boom"), { type: "entity.too.large" })).status, 500);
});
