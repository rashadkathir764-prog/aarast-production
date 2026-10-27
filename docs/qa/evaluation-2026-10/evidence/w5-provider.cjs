const { open, texts, tap, type, shot } = require('./lib.cjs');
const PW = process.env.DEMO_PASSWORD;
(async () => {
  const { b, p } = await open();
  await tap(p, 'عندي حساب');
  await type(p, 0, '777000201'); await type(p, 1, PW);
  await tap(p, 'تسجيل الدخول', { exact: true }); await p.waitForTimeout(4000);
  await shot(p, 'provider-0');
  const home = await texts(p);
  console.log('PROVIDER HOME:', JSON.stringify(home));
  const tabs = home.filter(t => t.length < 14).slice(-6);
  for (const [i, tab] of tabs.entries()) {
    try { await tap(p, tab, { exact: true }); await p.waitForTimeout(2500); await shot(p, `provider-${i + 1}`);
      console.log(`[${tab}]`, JSON.stringify((await texts(p)).slice(0, 18)));
    } catch (e) { console.log(`[${tab}] skip ${e.message}`); }
  }
  console.log('errors:', JSON.stringify(p.errors));
  await b.close();
})().catch(e => { console.error(e.message); process.exit(1); });
