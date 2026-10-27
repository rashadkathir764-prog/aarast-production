// Real app vs approved design: photographs the real screen at the design's
// own frame (390 x 1400 logical, 2x), and records every API call each screen
// makes (method, path, status, ms) -> the live endpoint map.
const { open, texts, tap, type, enableSemantics } = require('./lib.cjs');
const fs = require('fs');
const PW = process.env.DEMO_PASSWORD;
const OUT = process.argv[2];
fs.mkdirSync(OUT, { recursive: true });
const calls = []; let screen = 'login';
const steps = [
  // [design id, actor phone, actions]
];
async function session(phone, plan) {
  const { b, p } = await open({ viewport: { width: 390, height: 1400 } });
  p.on('requestfinished', async (req) => {
    const u = req.url(); if (!u.includes(':3215/')) return;
    const t = req.timing(); const r = await req.response();
    calls.push({ screen, m: req.method(), path: u.replace(/.*:3215/, '').split('?')[0], q: u.includes('?') ? 'q' : '', s: r ? r.status() : 0, ms: Math.round(t.responseEnd) });
  });
  screen = `login:${phone}`;
  await tap(p, 'عندي حساب');
  await type(p, 0, phone); await type(p, 1, PW);
  await tap(p, 'تسجيل الدخول', { exact: true }); await p.waitForTimeout(3000);
  if (plan) { screen = `pick-plan`; try { await tap(p, plan); await p.waitForTimeout(3000); } catch {} }
  return { b, p };
}
async function snap(p, id, label) {
  screen = id;
  await p.waitForTimeout(2500); await enableSemantics(p);
  await p.screenshot({ path: `${OUT}/${id}.png` });
  fs.writeFileSync(`${OUT}/${id}.txt`, (await texts(p)).join('\n'));
  console.log('shot', id, label || '');
}
async function go(p, id, ...labels) {
  screen = id;
  for (const l of labels) { try { await tap(p, l.text ?? l, l.opts ?? {}); } catch (e) { console.log('  miss', id, String(l.text ?? l)); return false; } }
  await snap(p, id); return true;
}
(async () => {
  let { b, p } = await session('777000101', 'عرس محمد');
  await snap(p, 'b02_home_active');
  await go(p, 'c01_money_summary', { text: 'المال', opts: { exact: true } });
  await go(p, 'c02_money_items', { text: 'البنود', opts: { exact: true } });
  await go(p, 'c03_money_payments', { text: 'الدفعات', opts: { exact: true } });
  await go(p, 'c05_money_funding', { text: 'من وين', opts: { exact: true } });
  await go(p, 'd01_tasks', { text: 'المهام', opts: { exact: true } });
  await go(p, 'd04_task_detail', 'اختر المصور');
  await p.goBack().catch(() => {}); 
  await go(p, 'e01_guests_men', { text: 'الضيوف', opts: { exact: true } });
  await go(p, 'f01_prov_requests', { text: 'المزودين', opts: { exact: true } });
  await go(p, 'f02_prov_explore', { text: 'استكشف', opts: { exact: true } });
  await go(p, 'f08_chats', { text: 'المحادثات', opts: { exact: true } });
  await go(p, 'b08_notifications', { text: 'الرئيسية', opts: { exact: true } }, 'التنبيهات');
  await b.close();
  ({ b, p } = await session('777000101', 'عرس محمد'));
  await go(p, 'g02_account', 'حسابي');
  await b.close();
  ({ b, p } = await session('777000103', 'عرس محمد'));
  await snap(p, 'x06_helper_home');
  await b.close();
  ({ b, p } = await session('777000104', 'عرس محمد'));
  await snap(p, 'y10_father_home');
  await b.close();
  fs.writeFileSync(`${OUT}/calls.json`, JSON.stringify(calls, null, 1));
  console.log('calls recorded:', calls.length);
})().catch(e => { console.error(e); process.exit(1); });
