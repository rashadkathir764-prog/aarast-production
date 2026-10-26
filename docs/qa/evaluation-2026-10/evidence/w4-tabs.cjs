const { open, texts, tap, type, shot } = require('./lib.cjs');
const PW = process.env.DEMO_PASSWORD;
const [phone, planName, tag] = process.argv.slice(2);
(async () => {
  const { b, p } = await open();
  await tap(p, 'عندي حساب');
  await type(p, 0, phone); await type(p, 1, PW);
  await tap(p, 'تسجيل الدخول', { exact: true }); await p.waitForTimeout(3000);
  try { await tap(p, planName); await p.waitForTimeout(2500); } catch {}
  await shot(p, `${tag}-0-home`);
  console.log(`[${tag}] HOME:`, JSON.stringify(await texts(p)));
  for (const [i, tab] of ['المال', 'المهام', 'الضيوف', 'المزودين'].entries()) {
    try {
      await tap(p, tab, { exact: true }); await p.waitForTimeout(2500);
      await shot(p, `${tag}-${i + 1}-${tab}`);
      console.log(`[${tag}] ${tab}:`, JSON.stringify((await texts(p)).slice(0, 30)));
    } catch (e) { console.log(`[${tag}] ${tab}: NOT REACHABLE (${e.message})`); }
  }
  console.log(`[${tag}] errors:`, JSON.stringify(p.errors));
  await b.close();
})().catch(e => { console.error(e.message); process.exit(1); });
