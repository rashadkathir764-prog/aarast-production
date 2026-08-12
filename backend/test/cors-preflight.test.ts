import assert from 'node:assert/strict';
import { once } from 'node:events';
import test from 'node:test';
import cors from 'cors';
import express from 'express';
import { getCorsOptions } from '../src/platform/config/cors-options';

test('browser preflight allows the canonical PUT money-budget route', async () => {
  const previousNodeEnv = process.env.NODE_ENV;
  const previousCorsOrigins = process.env.CORS_ORIGINS;
  process.env.NODE_ENV = 'production';
  process.env.CORS_ORIGINS = 'https://app.example.test';

  try {
    const app = express();
    app.use(cors(getCorsOptions()));
    app.put(
      '/api/v1/wedding-plans/:weddingPlanId/money-budget',
      (_request, response) => response.sendStatus(204),
    );

    const server = app.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const address = server.address();
    assert.ok(address && typeof address !== 'string');
    const url =
      `http://127.0.0.1:${address.port}` +
      '/api/v1/wedding-plans/00000000-0000-4000-8000-000000000000/money-budget';

    try {
      const response = await fetch(url, {
        method: 'OPTIONS',
        headers: {
          Origin: 'https://app.example.test',
          'Access-Control-Request-Method': 'PUT',
          'Access-Control-Request-Headers':
            'content-type,authorization,x-client-request-id',
        },
      });

      assert.equal(response.status, 204);
      assert.equal(
        response.headers.get('access-control-allow-origin'),
        'https://app.example.test',
      );
      assert.equal(
        response.headers.get('access-control-allow-credentials'),
        'true',
      );
      assert.deepEqual(
        (response.headers.get('access-control-allow-methods') ?? '').split(','),
        ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      );
      assert.equal(
        response.headers.get('access-control-allow-headers'),
        'Content-Type,Authorization,X-Client-Request-Id',
      );

      const foreignOriginResponse = await fetch(url, {
        method: 'OPTIONS',
        headers: {
          Origin: 'https://foreign.example.test',
          'Access-Control-Request-Method': 'PUT',
        },
      });
      assert.equal(
        foreignOriginResponse.headers.get('access-control-allow-origin'),
        null,
      );
    } finally {
      await new Promise<void>((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      });
    }
  } finally {
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousCorsOrigins === undefined) delete process.env.CORS_ORIGINS;
    else process.env.CORS_ORIGINS = previousCorsOrigins;
  }
});
