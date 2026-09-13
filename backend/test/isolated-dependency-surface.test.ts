import assert from 'node:assert/strict';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';

import {
  COPY_ATTEMPTS,
  copyWithTransientRetry,
  createDependencySurface,
  isTransientCopyError,
  lockfileClosure,
} from './support/isolated-dependency-surface';

// The isolated dependency surface copies the Nest lockfile closure (~5k
// files) while the rest of the suite runs in parallel. A transient
// operating-system condition during that copy (observed: Windows
// ERROR_NO_SYSTEM_RESOURCES 1450 mid-copy under a full `npm test`) must not
// fail the architecture gates; a real error must surface at once, and a
// failed surface must never leave a half-built temp root behind.

const backendRoot = path.resolve(__dirname, '..');
const windowsNoSystemResources = () => Object.assign(new Error('Insufficient system resources exist to complete the requested service.'), { errno: 1450, code: '', syscall: 'cp' });
const sharingViolation = () => Object.assign(new Error('resource busy or locked'), { errno: -4082, code: 'EBUSY', syscall: 'copyfile' });
const missing = () => Object.assign(new Error('no such file or directory'), { errno: -4058, code: 'ENOENT', syscall: 'copyfile' });

test('transient copy errors are classified by errno or code and nothing else', () => {
  assert.equal(isTransientCopyError(windowsNoSystemResources()), true);
  assert.equal(isTransientCopyError(sharingViolation()), true);
  assert.equal(isTransientCopyError(missing()), false);
  assert.equal(isTransientCopyError(new Error('plain')), false);
  assert.equal(isTransientCopyError(null), false);
});

test('a transient copy failure is retried with backoff and a persistent one fails after the bound', () => {
  const delays: number[] = [];
  const sleep = (milliseconds: number) => { delays.push(milliseconds); };
  let calls = 0;
  const attempt = copyWithTransientRetry('probe', 'from', 'to', {
    sleep,
    copy: () => { calls += 1; if (calls < 3) throw windowsNoSystemResources(); },
  });
  assert.equal(attempt, 3);
  assert.deepEqual(delays, [50, 100], 'exponential backoff between attempts');

  calls = 0;
  assert.throws(
    () => copyWithTransientRetry('probe', 'from', 'to', { sleep, copy: () => { calls += 1; throw windowsNoSystemResources(); } }),
    (error: Error) => /copy of probe failed after 6 attempt\(s\)/u.test(error.message) && (error as { cause?: unknown }).cause instanceof Error,
  );
  assert.equal(calls, COPY_ATTEMPTS);

  calls = 0;
  assert.throws(
    () => copyWithTransientRetry('probe', 'from', 'to', { sleep, copy: () => { calls += 1; throw missing(); } }),
    /copy of probe failed after 1 attempt\(s\)/u,
  );
  assert.equal(calls, 1, 'a real error is not retried');
});

test('the surface survives a transient failure on one package and removes its root when a copy is fatal', () => {
  const closure = lockfileClosure(backendRoot);
  const first = closure[0];
  let firstFailures = 0;
  const copy = (from: string, to: string) => {
    if (from.endsWith(path.join(...first.split('/'))) && firstFailures < 2) {
      firstFailures += 1;
      throw windowsNoSystemResources();
    }
    mkdirSync(to, { recursive: true });
    writeFileSync(path.join(to, 'package.json'), '{}\n');
  };
  const surface = createDependencySurface(backendRoot, 'aarast-surface-retry-', { copy, sleep: () => {} });
  try {
    assert.equal(firstFailures, 2);
    assert.deepEqual([...surface.packages], closure);
    for (const name of closure) assert.equal(existsSync(path.join(surface.nodeModules, ...name.split('/'), 'package.json')), true, name);
  } finally {
    surface.dispose();
  }
  assert.equal(existsSync(surface.root), false);

  let fatalRoot = '';
  assert.throws(() => createDependencySurface(backendRoot, 'aarast-surface-fatal-', {
    sleep: () => {},
    copy: (_from, to) => {
      fatalRoot = to.slice(0, to.indexOf(`${path.sep}node_modules${path.sep}`));
      throw missing();
    },
  }), /copy of .* failed after 1 attempt/u);
  assert.notEqual(fatalRoot, '');
  assert.equal(existsSync(fatalRoot), false, 'a failed surface leaves no temp root behind');
});
