import assert from "node:assert/strict";
import { test } from "node:test";
import * as exceptionFilter from "../src/common/filters/global-exception.filter";

const shouldReportHttpException = (exceptionFilter as {
  shouldReportHttpException?: (route: string, status: number) => boolean;
}).shouldReportHttpException;

test("expected readiness probe failures do not create error telemetry", () => {
  assert.equal(shouldReportHttpException?.("GET /ready", 503), false);
});

test("other server failures remain logged and reported", () => {
  assert.equal(shouldReportHttpException?.("GET /api/v1/users/me", 500), true);
  assert.equal(shouldReportHttpException?.("GET /ready", 500), true);
  assert.equal(shouldReportHttpException?.("GET /api/v1/users/me", 503), true);
});
