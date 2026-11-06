import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import { NotFoundException, UnauthorizedException } from '@nestjs/common';
import { MetricsController } from '../src/platform/observability/metrics.controller';

// RA-BE-05: the scrape endpoint shows internal topology, and the backend port
// sits behind the public proxy. Without a token it is open only where the
// code runs on a developer's machine (development, test); any other
// environment, staging included, hides it.

const saved = { token: process.env.METRICS_TOKEN, env: process.env.NODE_ENV };

afterEach(() => {
  if (saved.token === undefined) delete process.env.METRICS_TOKEN;
  else process.env.METRICS_TOKEN = saved.token;
  if (saved.env === undefined) delete process.env.NODE_ENV;
  else process.env.NODE_ENV = saved.env;
});

function withEnv(nodeEnv: string | undefined, token: string | undefined) {
  if (nodeEnv === undefined) delete process.env.NODE_ENV;
  else process.env.NODE_ENV = nodeEnv;
  if (token === undefined) delete process.env.METRICS_TOKEN;
  else process.env.METRICS_TOKEN = token;
  return new MetricsController();
}

for (const nodeEnv of ['production', 'staging', 'preview', undefined]) {
  test(`without a token the metrics do not exist in ${nodeEnv ?? 'an unset environment'}`, async () => {
    await assert.rejects(withEnv(nodeEnv, undefined).metrics(), NotFoundException);
  });
}

for (const nodeEnv of ['development', 'test']) {
  test(`without a token a developer reads the metrics in ${nodeEnv}`, async () => {
    const body = await withEnv(nodeEnv, undefined).metrics();
    assert.equal(typeof body, 'string');
  });
}

test('with a token only the matching bearer reads the metrics', async () => {
  const controller = withEnv('production', 'scrape-secret-for-test');
  await assert.rejects(controller.metrics(), UnauthorizedException);
  await assert.rejects(controller.metrics('Bearer wrong'), UnauthorizedException);
  assert.equal(typeof (await controller.metrics('Bearer scrape-secret-for-test')), 'string');
});
