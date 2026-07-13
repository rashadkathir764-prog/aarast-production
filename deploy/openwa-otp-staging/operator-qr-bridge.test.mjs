import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import http from 'node:http';
import path from 'node:path';
import test from 'node:test';

const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', 'base64');
const masterKey = 'm'.repeat(32);
const sessionId = 'session-1';
const bridgePath = path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(.:)/, '$1')), 'operator-qr-bridge.mjs');

function requestStatus(port, headers) {
  return new Promise((resolve, reject) => {
    const request = http.request(
      { host: '127.0.0.1', port, path: '/status', headers },
      (response) => {
        response.resume();
        response.once('end', () => resolve(response.statusCode));
      },
    );
    request.once('error', reject);
    request.end();
  });
}

test('rejects a non-loopback OpenWA origin before listening', async () => {
  const child = spawn(process.execPath, [bridgePath], {
    env: {
      ...process.env,
      OPENWA_BASE_URL: 'https://evil.example',
      OPENWA_MASTER_KEY: masterKey,
      OPENWA_SESSION_ID: sessionId,
      QR_BRIDGE_PORT: '0',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const exitCode = await new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('exit', resolve);
  });
  assert.notEqual(exitCode, 0);
});

test('serves a scoped no-store QR page without exposing the master key', async (t) => {
  let upstreamCalls = 0;
  let redirectTarget = null;
  let leakedRequests = 0;
  const leakServer = http.createServer((_request, response) => {
    leakedRequests += 1;
    response.writeHead(200).end();
  });
  await new Promise((resolve) => leakServer.listen(0, '127.0.0.1', resolve));
  const upstream = http.createServer((request, response) => {
    upstreamCalls += 1;
    assert.equal(request.headers['x-api-key'], masterKey);
    if (redirectTarget && request.url === `/api/sessions/${sessionId}`) {
      response.writeHead(302, { location: redirectTarget }).end();
      return;
    }
    if (request.url === `/api/sessions/${sessionId}`) {
      response.writeHead(200, { 'content-type': 'application/json' });
      return response.end(JSON.stringify({ status: 'qr_ready', phone: null }));
    }
    if (request.url === `/api/sessions/${sessionId}/qr`) {
      response.writeHead(200, { 'content-type': 'application/json' });
      return response.end(JSON.stringify({ qrCode: `data:image/png;base64,${png.toString('base64')}` }));
    }
    response.writeHead(404).end();
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));

  const child = spawn(process.execPath, [bridgePath], {
    env: {
      ...process.env,
      OPENWA_BASE_URL: `http://127.0.0.1:${upstream.address().port}`,
      OPENWA_MASTER_KEY: masterKey,
      OPENWA_SESSION_ID: sessionId,
      QR_BRIDGE_PORT: '0',
      QR_BRIDGE_TTL_MS: '60000',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  t.after(() => {
    child.kill('SIGTERM');
    upstream.close();
    leakServer.close();
  });
  const line = await new Promise((resolve, reject) => {
    child.once('error', reject);
    child.stdout.once('data', (chunk) => resolve(chunk.toString('utf8')));
  });
  const port = Number(/:(\d+)/.exec(line)?.[1]);
  assert.ok(port > 0);

  assert.equal(await requestStatus(port, { host: 'evil.example:2788' }), 403);
  assert.equal(await requestStatus(port, { origin: 'https://evil.example' }), 403);
  assert.equal(upstreamCalls, 0);

  const root = await fetch(`http://127.0.0.1:${port}/`);
  assert.equal(root.status, 200);
  assert.match(root.headers.get('content-security-policy'), /frame-ancestors 'none'/);
  assert.equal(root.headers.get('cache-control'), 'no-store, max-age=0');
  assert.doesNotMatch(await root.text(), new RegExp(masterKey));

  const status = await fetch(`http://127.0.0.1:${port}/status`);
  assert.deepEqual(await status.json(), { status: 'qr_ready', linked: false });

  const qr = await fetch(`http://127.0.0.1:${port}/qr.png`);
  assert.equal(qr.headers.get('content-type'), 'image/png');
  assert.deepEqual(Buffer.from(await qr.arrayBuffer()), png);

  const post = await fetch(`http://127.0.0.1:${port}/`, { method: 'POST' });
  assert.equal(post.status, 405);

  redirectTarget = `http://127.0.0.1:${leakServer.address().port}/leak`;
  const redirected = await fetch(`http://127.0.0.1:${port}/status`);
  assert.equal(redirected.status, 503);
  assert.equal(leakedRequests, 0);
});
