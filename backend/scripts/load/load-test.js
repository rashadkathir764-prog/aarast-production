'use strict';

/**
 * Zero-dependency load test for the Aarast backend.
 *
 * Registers a throwaway user, creates a wedding plan with real financial
 * data, then hammers a read-heavy endpoint mix (the traffic shape of a
 * planning app) with N keep-alive connections and reports throughput and
 * latency percentiles.
 *
 * Usage:
 *   LOAD_BASE_URL=http://127.0.0.1:3000 node scripts/load/load-test.js
 *
 * Env knobs:
 *   LOAD_BASE_URL      target (default http://127.0.0.1:3115)
 *   LOAD_CONNECTIONS   concurrent keep-alive connections (default 50)
 *   LOAD_DURATION_S    seconds to run (default 30)
 *
 * The global throttler defaults to 1000 req/min per IP; boot the target
 * with THROTTLE_LIMIT=1000000 for load runs or the test measures the
 * rate limiter instead of the API.
 */

const http = require('node:http');
const { URL } = require('node:url');
const {
  registerVerified,
} = require('../smoke/verified-registration');

const baseUrl = new URL(process.env.LOAD_BASE_URL || 'http://127.0.0.1:3115');
const connections = Number(process.env.LOAD_CONNECTIONS || 50);
const durationMs = Number(process.env.LOAD_DURATION_S || 30) * 1000;

const agent = new http.Agent({
  keepAlive: true,
  maxSockets: connections,
});

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request(
      {
        agent,
        method,
        hostname: baseUrl.hostname,
        port: baseUrl.port || 80,
        path,
        headers: {
          ...(payload
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              }
            : {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          const text = Buffer.concat(chunks).toString('utf8');
          let parsed = null;
          try {
            parsed = JSON.parse(text);
          } catch {
            /* non-JSON body is fine for load purposes */
          }
          resolve({ status: res.statusCode, body: parsed });
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function percentile(sorted, p) {
  if (sorted.length === 0) return 0;
  const idx = Math.min(
    sorted.length - 1,
    Math.ceil((p / 100) * sorted.length) - 1,
  );
  return sorted[Math.max(0, idx)];
}

async function setup() {
  const phone = `+9677${String(Date.now()).slice(-8)}`;
  const register = await registerVerified(request, {
    name: 'Load Test User',
    phone,
    password: 'LoadTest#12345',
  });
  if (register.status !== 201) {
    throw new Error(`register failed: HTTP ${register.status}`);
  }
  const token = register.body.accessToken;

  const plan = await request(
    'POST',
    '/api/v1/wedding-plans',
    { title: 'خطة اختبار الحمل', estimatedBudget: '1000000' },
    token,
  );
  if (plan.status !== 201) {
    throw new Error(`plan create failed: HTTP ${plan.status}`);
  }
  const planId = plan.body.id;

  const categories = await request(
    'GET',
    `/api/v1/wedding-plans/${planId}/budget-categories`,
    null,
    token,
  );
  let categoryId = categories.body?.[0]?.id;
  if (!categoryId) {
    const created = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/budget-categories`,
      { name: 'قاعة الأفراح', allocatedAmount: '500000' },
      token,
    );
    categoryId = created.body?.id;
  }
  if (!categoryId) throw new Error('no budget category available');

  for (let i = 0; i < 25; i++) {
    const cost = await request(
      'POST',
      `/api/v1/wedding-plans/${planId}/costs`,
      {
        title: `تكلفة اختبار الحمل ${i}`,
        totalAmount: '1500.50',
        budgetCategoryId: categoryId,
      },
      token,
    );
    if (cost.status !== 201) {
      throw new Error(`cost seed failed: HTTP ${cost.status}`);
    }
  }

  return { token, planId };
}

async function main() {
  console.log(`Load Test — target ${baseUrl.origin}`);
  console.log(`connections=${connections} duration=${durationMs / 1000}s`);

  const health = await request('GET', '/health');
  if (health.status !== 200) {
    throw new Error(`target not healthy: HTTP ${health.status}`);
  }

  const { token, planId } = await setup();

  // Read-heavy mix mirroring real app traffic.
  const paths = [
    `/api/v1/wedding-plans/${planId}/costs`,
    `/api/v1/wedding-plans/${planId}/money-summary`,
    `/api/v1/wedding-plans/${planId}/budget-categories`,
    `/api/v1/wedding-plans/${planId}`,
    '/health',
  ];

  const latencies = [];
  const statuses = new Map();
  let inFlightErrors = 0;
  const deadline = Date.now() + durationMs;

  async function worker(id) {
    let i = id;
    while (Date.now() < deadline) {
      const path = paths[i % paths.length];
      i += 1;
      const started = process.hrtime.bigint();
      try {
        const res = await request('GET', path, null, token);
        const elapsedMs =
          Number(process.hrtime.bigint() - started) / 1_000_000;
        latencies.push(elapsedMs);
        statuses.set(res.status, (statuses.get(res.status) ?? 0) + 1);
      } catch {
        inFlightErrors += 1;
      }
    }
  }

  const startedAt = Date.now();
  await Promise.all(
    Array.from({ length: connections }, (_, id) => worker(id)),
  );
  const elapsedS = (Date.now() - startedAt) / 1000;

  latencies.sort((a, b) => a - b);
  const total = latencies.length;
  const non2xx = [...statuses.entries()]
    .filter(([code]) => code < 200 || code >= 300)
    .reduce((sum, [, count]) => sum + count, 0);

  console.log('');
  console.log('Results');
  console.log(`  requests        ${total}`);
  console.log(`  duration        ${elapsedS.toFixed(1)}s`);
  console.log(`  throughput      ${(total / elapsedS).toFixed(0)} req/s`);
  console.log(`  p50 latency     ${percentile(latencies, 50).toFixed(1)} ms`);
  console.log(`  p95 latency     ${percentile(latencies, 95).toFixed(1)} ms`);
  console.log(`  p99 latency     ${percentile(latencies, 99).toFixed(1)} ms`);
  console.log(`  non-2xx         ${non2xx}`);
  console.log(`  socket errors   ${inFlightErrors}`);
  console.log(
    `  status codes    ${[...statuses.entries()]
      .map(([code, count]) => `${code}:${count}`)
      .join(' ')}`,
  );

  if (non2xx > total * 0.01 || inFlightErrors > 0) {
    console.error('Overall Result: FAIL (errors above 1%)');
    process.exit(1);
  }
  console.log('Overall Result: PASS');
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
