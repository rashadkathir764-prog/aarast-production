// Load test: virtual users log in as cloned grooms and replay the requests
// the app sends when it opens (home, plan, money, guests, tasks, notices,
// provider search). Reports throughput and p50/p95/p99 per route.
// Usage: node load-test.mjs <users> <concurrency> <seconds> [fromClone]
const BASE = process.env.BASE ?? 'http://localhost:3215';
const PW = process.env.DEMO_PASSWORD;
const [users = 200, concurrency = 50, seconds = 30, from = 1] = process.argv.slice(2).map(Number);

const ip = (i) => `10.${(i >> 16) & 255}.${(i >> 8) & 255}.${i & 255}`;
async function login(n) {
  const phone = '+9677' + '1' + String(n).padStart(7, '0');
  const t0 = performance.now();
  const r = await fetch(`${BASE}/api/v1/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-forwarded-for': ip(n) },
    body: JSON.stringify({ phone, password: PW }),
  });
  const ms = performance.now() - t0;
  const j = await r.json();
  if (!j.accessToken) throw new Error(`login ${phone}: ${r.status} ${JSON.stringify(j).slice(0, 120)}`);
  return { token: j.accessToken, plan: `demo_plan_groom_s${n}`, n, ms };
}

const SKIP = new Set((process.env.SKIP ?? '').split(',').filter(Boolean));
const routes = (u) => allRoutes(u).filter(([k]) => !SKIP.has(k));
const allRoutes = (u) => [
  ['home', `/api/v1/dashboard/home`],
  ['contexts', `/api/v1/contexts`],
  ['unread', `/api/v1/notifications/unread-count`],
  ['summary', `/api/v1/wedding-plans/${u.plan}/dashboard-summary`],
  ['plan-view', `/api/v1/wedding-plans/${u.plan}/plan-view`],
  ['money', `/api/v1/wedding-plans/${u.plan}/money-summary`],
  ['costs', `/api/v1/wedding-plans/${u.plan}/costs`],
  ['guests', `/api/v1/wedding-plans/${u.plan}/guests`],
  ['tasks', `/api/v1/wedding-plans/${u.plan}/tasks`],
  ['notices', `/api/v1/notifications`],
  ['providers', `/api/v1/providers`],
];

const stats = new Map();
const rec = (k, ms, ok) => {
  const s = stats.get(k) ?? { lat: [], err: 0 };
  s.lat.push(ms); if (!ok) s.err++; stats.set(k, s);
};
const pct = (a, p) => a[Math.min(a.length - 1, Math.floor((p / 100) * a.length))];

// Log in sequentially in small batches (logins are the expensive part).
const vus = [];
const loginMs = [];
for (let i = 0; i < users; i += 10) {
  const batch = await Promise.all(Array.from({ length: Math.min(10, users - i) }, (_, k) => login(from + i + k)));
  for (const b of batch) { vus.push(b); loginMs.push(b.ms); }
}
loginMs.sort((a, b) => a - b);
console.log(`logged in ${vus.length} users; login p50=${pct(loginMs, 50).toFixed(0)}ms p95=${pct(loginMs, 95).toFixed(0)}ms`);

const deadline = Date.now() + seconds * 1000;
let total = 0;
async function worker(w) {
  let i = w;
  while (Date.now() < deadline) {
    const u = vus[i++ % vus.length];
    for (const [k, path] of routes(u)) {
      if (Date.now() >= deadline) return;
      const t0 = performance.now();
      let ok = false;
      try {
        const r = await fetch(BASE + path, { headers: { authorization: `Bearer ${u.token}` } });
        await r.arrayBuffer(); ok = r.status < 400;
        if (!ok && !stats.has('err:' + k)) stats.set('err:' + k, { lat: [], err: r.status });
      } catch { ok = false; }
      rec(k, performance.now() - t0, ok); total++;
    }
  }
}
const t0 = Date.now();
await Promise.all(Array.from({ length: concurrency }, (_, w) => worker(w)));
const secs = (Date.now() - t0) / 1000;
const rows = [];
for (const [k, s] of stats) {
  if (k.startsWith('err:')) { console.log(`first error on ${k.slice(4)}: HTTP ${s.err}`); continue; }
  s.lat.sort((a, b) => a - b);
  rows.push({ route: k, n: s.lat.length, errors: s.err, p50: +pct(s.lat, 50).toFixed(0), p95: +pct(s.lat, 95).toFixed(0), p99: +pct(s.lat, 99).toFixed(0) });
}
console.table(rows);
console.log(`concurrency=${concurrency} duration=${secs.toFixed(1)}s requests=${total} throughput=${(total / secs).toFixed(0)} req/s`);
