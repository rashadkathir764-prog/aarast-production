import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { NextFunction, Request, Response } from 'express';
import {
  APP_UPDATE_REQUIRED,
  clientContractGate,
  minClientContract,
} from '../src/platform/http/client-contract';

// RA-BE-01: an app older than MIN_CLIENT_CONTRACT is told to update (426)
// before any route runs, so its offline queue pauses instead of dropping a
// write a newer server refuses.

function run(minimum: number, header: string | undefined) {
  let passed = false;
  let status: number | undefined;
  let body: unknown;
  const request = {
    header: (name: string) => (name === 'x-aarast-contract' ? header : undefined),
  } as unknown as Request;
  const response = {
    status(code: number) {
      status = code;
      return this;
    },
    json(value: unknown) {
      body = value;
      return this;
    },
  } as unknown as Response;
  clientContractGate(minimum)(request, response, (() => {
    passed = true;
  }) as NextFunction);
  return { passed, status, body };
}

test('with no minimum every app is served', () => {
  assert.equal(run(0, '1').passed, true);
  assert.equal(run(0, undefined).passed, true);
});

test('an app at or above the minimum is served', () => {
  assert.equal(run(2, '2').passed, true);
  assert.equal(run(2, '3').passed, true);
});

test('an older app is told to update, with a code the app reads', () => {
  for (const header of ['1', '0', 'abc', '1.5', '']) {
    const answer = run(2, header);
    assert.equal(answer.passed, false, header);
    assert.equal(answer.status, 426, header);
    assert.equal((answer.body as { code: string }).code, APP_UPDATE_REQUIRED);
  }
});

test('a request without the header passes: the admin panel, the web, old pilots', () => {
  assert.equal(run(5, undefined).passed, true);
});

test('MIN_CLIENT_CONTRACT is read once and checked', () => {
  assert.equal(minClientContract({}), 0);
  assert.equal(minClientContract({ MIN_CLIENT_CONTRACT: ' 3 ' }), 3);
  assert.throws(() => minClientContract({ MIN_CLIENT_CONTRACT: '-1' }));
  assert.throws(() => minClientContract({ MIN_CLIENT_CONTRACT: 'two' }));
});
