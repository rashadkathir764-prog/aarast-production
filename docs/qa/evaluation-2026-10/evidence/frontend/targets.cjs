// Tap-target audit: every tappable semantics node (button / link / tab /
// checkbox) on the main screens, its size in logical pixels, flagged < 48.
const { open, tap, type, enableSemantics } = require('./lib.cjs');
const PW = process.env.DEMO_PASSWORD;
(async () => {
  const { b, p } = await open({ viewport: { width: 390, height: 1400 }, deviceScaleFactor: 1 });
  await tap(p, 'عندي حساب'); await type(p, 0, '777000101'); await type(p, 1, PW);
  await tap(p, 'تسجيل الدخول', { exact: true }); await p.waitForTimeout(3000);
  await tap(p, 'عرس محمد'); await p.waitForTimeout(3000);
  const report = {};
  for (const tab of ['الرئيسية', 'المال', 'المهام', 'الضيوف', 'المزودين']) {
    try { await tap(p, tab, { exact: true }); } catch {}
    await p.waitForTimeout(2500); await enableSemantics(p);
    const items = await p.$$eval('flt-semantics[role=button], flt-semantics[role=link], flt-semantics[role=tab], flt-semantics[role=checkbox], flt-semantics[role=switch]', els => els.map(e => {
      const r = e.getBoundingClientRect();
      return { label: (e.getAttribute('aria-label') || e.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 40), w: Math.round(r.width), h: Math.round(r.height) };
    }).filter(x => x.w > 0 && x.h > 0));
    const small = items.filter(x => Math.min(x.w, x.h) < 48);
    report[tab] = { tappables: items.length, under48: small.length, examples: small.slice(0, 8) };
  }
  console.log(JSON.stringify(report, null, 1));
  await b.close();
})().catch(e => { console.error(e.message); process.exit(1); });
