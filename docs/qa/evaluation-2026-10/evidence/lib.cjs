// Small helpers to drive the Flutter web build through its semantics tree.
const { chromium } = require('playwright');
const DIR = __dirname;
async function open(opts = {}) {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'ar', ...opts });
  const p = await ctx.newPage();
  p.errors = [];
  p.on('console', m => { if (m.type() === 'error') p.errors.push(m.text().slice(0, 200)); });
  p.on('response', r => { if (r.url().includes(':3215') && r.status() >= 400) p.errors.push(`HTTP ${r.status()} ${r.url().replace(/.*:3215/, '')}`); });
  await p.goto('http://localhost:8080/', { waitUntil: 'load' });
  await p.waitForSelector('flutter-view, flt-glass-pane', { timeout: 60000 });
  await p.waitForTimeout(3000);
  await enableSemantics(p);
  return { b, p };
}
async function enableSemantics(p) {
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await p.waitForTimeout(800);
}
async function texts(p) {
  return p.$$eval('flt-semantics', els => {
    const out = [];
    for (const e of els) {
      if (e.querySelector('flt-semantics')) continue; // leaves only
      const t = (e.getAttribute('aria-label') || e.textContent || '').trim();
      if (t) out.push(t.replace(/\s+/g, ' '));
    }
    return [...new Set(out)];
  });
}
async function tap(p, text, { exact = false, nth = 0 } = {}) {
  const handles = await p.$$('flt-semantics');
  const matches = [];
  for (const h of handles) {
    const t = ((await h.getAttribute('aria-label')) || (await h.textContent()) || '').trim();
    const hasChild = await h.$('flt-semantics');
    if (hasChild && !exact) continue;
    if (exact ? t === text : t.includes(text)) matches.push(h);
  }
  if (!matches[nth]) throw new Error(`no tappable "${text}"`);
  const box = await matches[nth].boundingBox();
  await p.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  await p.waitForTimeout(1500);
  await enableSemantics(p);
}
async function type(p, index, value) {
  const inputs = await p.$$('input, textarea');
  if (!inputs[index]) throw new Error(`no input #${index} (have ${inputs.length})`);
  await inputs[index].click();
  await inputs[index].fill(value);
  await p.waitForTimeout(300);
}
async function shot(p, name) { await p.screenshot({ path: `${DIR}/${name}.png` }); }
module.exports = { open, texts, tap, type, shot, enableSemantics };
