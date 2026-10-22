(function () {
  const tabs = [...document.querySelectorAll('.tab')];
  const panels = [...document.querySelectorAll('.panel')];
  function show(key, push) {
    tabs.forEach(t => t.classList.toggle('on', t.dataset.tab === key));
    panels.forEach(p => { p.hidden = p.id !== 'p-' + key; });
    const on = tabs.find(t => t.dataset.tab === key);
    if (on) on.scrollIntoView({ block: 'nearest', inline: 'center' });
    if (push) { try { history.replaceState(null, '', '#' + key); } catch (e) {} }
  }
  function jump(id) {
    const el = document.getElementById(id);
    if (!el) return;
    const p = el.closest('.panel');
    if (p) show(p.id.slice(2), true);
    requestAnimationFrame(() => el.scrollIntoView({ block: 'start' }));
  }
  tabs.forEach(t => t.addEventListener('click', () => { show(t.dataset.tab, true); window.scrollTo(0, 0); }));
  document.addEventListener('click', e => {
    const j = e.target.closest('[data-jump]');
    if (j) { e.preventDefault(); jump(j.dataset.jump); return; }
    const tb = e.target.closest('a[data-tab]');
    if (tb) { e.preventDefault(); show(tb.dataset.tab, true); window.scrollTo(0, 0); return; }
    const f = e.target.closest('.flt');
    if (f) {
      const panel = f.closest('.panel');
      panel.querySelectorAll('.flt').forEach(b => b.classList.toggle('on', b === f));
      panel.querySelectorAll('.scr').forEach(s => { s.hidden = f.dataset.f !== 'all' && s.dataset.status !== f.dataset.f; });
      return;
    }
    const s = e.target.closest('.shot');
    if (s) {
      const d = document.getElementById('zoom'), zi = document.getElementById('zoomImg');
      zi.src = s.dataset.src; zi.alt = s.querySelector('img').alt; d.showModal();
    }
  });
  document.getElementById('zoom').addEventListener('click', e => e.currentTarget.close());
  const h = (location.hash || '').slice(1);
  if (h && document.getElementById('p-' + h)) show(h, false);
})();
