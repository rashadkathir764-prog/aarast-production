// IDOR probe: replays every user-scoped GET/DELETE route that takes an id
// with ids owned by the victim (Mohammed, demo_plan_groom), as other users.
import { execSync } from 'node:child_process';
const BASE = 'http://localhost:3215';
const DB = process.env.DATABASE_URL.replace('?schema=public', '');
const q = (sql) => execSync(`psql "${DB}" -Atc ${JSON.stringify(sql)}`).toString().trim().split('\n')[0] || null;
const PW = process.env.DEMO_PASSWORD;
const login = async (phone) => {
  const r = await fetch(`${BASE}/api/v1/auth/login`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ phone, password: PW }) });
  const j = await r.json(); if (!j.accessToken) throw new Error(phone + ' ' + JSON.stringify(j)); return j.accessToken;
};
const plan = 'demo_plan_groom';
const ids = {
  plan,
  cost: q(`select id from "WeddingCost" where "weddingPlanId"='${plan}' limit 1`),
  privateCost: q(`select id from "WeddingCost" where "weddingPlanId"='${plan}' and "privateToUserId" is not null limit 1`),
  payment: q(`select p.id from "CostPayment" p join "WeddingCost" c on c.id=p."weddingCostId" where c."weddingPlanId"='${plan}' limit 1`),
  schedule: q(`select s.id from "PaymentSchedule" s join "WeddingCost" c on c.id=s."weddingCostId" where c."weddingPlanId"='${plan}' limit 1`),
  receipt: q(`select r.id||'|'||r."weddingCostId" from "CostReceipt" r join "WeddingCost" c on c.id=r."weddingCostId" where c."weddingPlanId"='${plan}' limit 1`),
  category: q(`select id from "BudgetCategory" where "weddingPlanId"='${plan}' limit 1`),
  funding: q(`select id from "FundingSource" where "weddingPlanId"='${plan}' limit 1`),
  loanRepay: q(`select l.id from "LoanRepayment" l join "FundingSource" f on f.id=l."fundingSourceId" where f."weddingPlanId"='${plan}' limit 1`),
  guest: q(`select id from "Guest" where "weddingPlanId"='${plan}' limit 1`),
  guestGroup: q(`select id from "GuestGroup" where "weddingPlanId"='${plan}' limit 1`),
  task: q(`select id from "WeddingTask" where "weddingPlanId"='${plan}' limit 1`),
  notification: q(`select id from "Notification" where "userId"='demo_user_groom' limit 1`),
  conversation: q(`select c.id from "Conversation" c join "ConversationParticipant" p on p."conversationId"=c.id where p."userId"='demo_user_groom' limit 1`),
  quote: q(`select id from "QuoteRequest" where "weddingPlanId"='${plan}' limit 1`),
  booking: q(`select b.id from "Booking" b join "QuoteRequest" r on r.id=b."quoteRequestId" where r."weddingPlanId"='${plan}' limit 1`),
};
console.log('victim ids', JSON.stringify(ids));
const [rid, rcost] = (ids.receipt || '|').split('|');
const routes = [
  ['GET', `/api/v1/wedding-plans/${plan}`, 'plan'],
  ['GET', `/api/v1/wedding-plans/${plan}/dashboard-summary`, 'plan'],
  ['GET', `/api/v1/wedding-plans/${plan}/funding-sources`, 'money'],
  ['GET', `/api/v1/me/wedding-plans/${plan}/bookings`, 'plan'],
  ['GET', `/api/v1/costs/${ids.cost}`, 'money'],
  ['GET', `/api/v1/costs/${ids.cost}/payments`, 'money'],
  ['GET', `/api/v1/costs/${ids.cost}/payment-schedules`, 'money'],
  ['GET', `/api/v1/costs/${rcost}/receipts`, 'money'],
  ['GET', `/api/v1/cost-payments/${ids.payment}`, 'money'],
  ['GET', `/api/v1/guests/${ids.guest}`, 'plan'],
  ['GET', `/api/v1/tasks/${ids.task}`, 'plan'],
  ['GET', `/api/v1/notifications/${ids.notification}`, 'own'],
  ['GET', `/api/v1/conversations/${ids.conversation}`, 'own'],
  ['GET', `/api/v1/conversations/${ids.conversation}/messages`, 'own'],
  ['GET', `/api/v1/conversations/${ids.conversation}/timeline`, 'own'],
  ['GET', `/api/v1/quote-requests/${ids.quote}`, 'plan'],
  ['GET', `/api/v1/me/quote-requests/${ids.quote}`, 'own'],
  // plan-scoped list endpoints that take the plan as a query
  ['GET', `/api/v1/costs?weddingPlanId=${plan}`, 'money'],
  ['GET', `/api/v1/guests?weddingPlanId=${plan}`, 'plan'],
  ['GET', `/api/v1/tasks?weddingPlanId=${plan}`, 'plan'],
  ['GET', `/api/v1/budget-categories?weddingPlanId=${plan}`, 'money'],
  ['GET', `/api/v1/money/summary?weddingPlanId=${plan}`, 'money'],
];
// mutations: a write that would succeed for the owner. Each one is a real attempt.
const mutations = [
  ['PATCH', `/api/v1/costs/${ids.cost}`, { note: 'idor' }, 'money'],
  ['PATCH', `/api/v1/guests/${ids.guest}`, { notes: 'idor' }, 'plan-edit'],
  ['PATCH', `/api/v1/tasks/${ids.task}`, { title: 'idor' }, 'plan-edit'],
  ['PATCH', `/api/v1/budget-categories/${ids.category}`, { name: 'idor' }, 'money'],
  ['PATCH', `/api/v1/funding-sources/${ids.funding}`, { note: 'idor' }, 'owner-money'],
  ['PATCH', `/api/v1/notifications/${ids.notification}/read`, {}, 'own'],
  ['PATCH', `/api/v1/wedding-plans/${plan}`, { title: 'idor' }, 'plan-edit'],
  ['POST', `/api/v1/costs/${ids.cost}/payments`, { amount: 1, paidAt: '2026-10-01' }, 'money'],
  ['DELETE', `/api/v1/payment-schedules/${ids.schedule}`, null, 'money'],
  ['DELETE', `/api/v1/loan-repayments/${ids.loanRepay}`, null, 'owner-money'],
  ['DELETE', `/api/v1/guest-groups/${ids.guestGroup}`, null, 'plan-edit'],
  ['DELETE', `/api/v1/costs/${rcost}/receipts/${rid}`, null, 'money'],
  ['POST', `/api/v1/conversations/${ids.conversation}/messages`, { body: 'idor' }, 'own'],
  ['PATCH', `/api/v1/me/bookings/${ids.booking}/cancel`, {}, 'own'],
];
const actors = {
  owner_mohammed: '+967777000101',
  outsider_adel: '+967777000301',
  family_salma: '+967777000102',
  viewer_father: '+967777000104',
  provider_ali: '+967777000201',
};
const tokens = {};
for (const [k, p] of Object.entries(actors)) tokens[k] = await login(p);
const call = async (m, path, t, body) => {
  const r = await fetch(BASE + path, { method: m, headers: { authorization: `Bearer ${t}`, 'content-type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  const txt = await r.text(); return { s: r.status, n: txt.length, txt };
};
const rows = [];
for (const [m, path, kind] of routes) {
  const row = { m, path: path.replace(/[a-z0-9_-]{20,}/gi, ':id'), kind };
  for (const a of Object.keys(actors)) row[a] = (await call(m, path, tokens[a])).s;
  rows.push(row);
}
console.log('\nREADS (status per actor)');
console.table(rows);
// mutations: outsider + viewer first (never owner, so data stays intact unless a hole exists)
const mrows = [];
for (const [m, path, body, kind] of mutations) {
  const row = { m, path: path.replace(/[a-z0-9_-]{20,}/gi, ':id'), kind };
  for (const a of ['outsider_adel', 'viewer_father', 'family_salma', 'provider_ali']) {
    const r = await call(m, path, tokens[a], body); row[a] = r.s + (r.s < 300 ? '!' : '');
  }
  mrows.push(row);
}
console.log('\nWRITES by non-owners (any 2xx marked !)');
console.table(mrows);
