#!/usr/bin/env python3
"""Builds full/index.html from full/data/*.json. Run: python3 -I build.py"""
import html, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
JOURNEYS = {
    "groom": {
        "order": ["onboarding", "home", "money", "tasks", "guests", "providers", "account", "participants"],
        "title": "مسار العريس: قبل وبعد",
        "h2": "مسار العريس كامل: قبل وبعد",
        "who": "مسار العريس",
        "life": "lifecycle.json",
        "top": "top.json",
        "out": "index.html",
    },
    "provider": {
        "order": ["provider"],
        "title": "مسار المزود: قبل وبعد",
        "h2": "مسار المزود كامل: قبل وبعد",
        "who": "مسار المزود",
        "life": "lifecycle_provider.json",
        "top": "top_provider.json",
        "out": "provider.html",
    },
}
J = JOURNEYS[sys.argv[1] if len(sys.argv) > 1 else "groom"]
ORDER = J["order"]
STATUS = {
    "build": ("يُبنى الآن", "st-build"),
    "backend": ("يحتاج سيرفر", "st-backend"),
    "frozen": ("مجمّد للنسخة الأولى", "st-frozen"),
}
SAFE_TAG = re.compile(r"</?b>")


def t(s):
    """Escape text but keep <b> tags."""
    s = html.escape(str(s or ""), quote=False)
    return s.replace("&lt;b&gt;", "<b>").replace("&lt;/b&gt;", "</b>")


def a(s):
    return html.escape(str(s or ""), quote=True)


def load():
    domains = []
    for key in ORDER:
        p = os.path.join(HERE, "data", key + ".json")
        if os.path.exists(p):
            with open(p, encoding="utf-8") as f:
                d = json.load(f)
            d["domain"] = key
            domains.append(d)
    life = None
    p = os.path.join(HERE, "data", J["life"])
    if os.path.exists(p):
        with open(p, encoding="utf-8") as f:
            life = json.load(f)
    return domains, life


def img_ok(src):
    return os.path.exists(os.path.join(HERE, src))


def shots(lst, alt):
    out = []
    for i in lst or []:
        src = i.get("src", "")
        if not src or not img_ok(src):
            continue
        cap = i.get("cap", "")
        out.append(
            f'<figure><button type="button" class="shot" data-src="{a(src)}">'
            f'<img loading="lazy" src="{a(src)}" alt="{a(cap or alt)}"></button>'
            + (f"<figcaption>{t(cap)}</figcaption>" if cap else "")
            + "</figure>"
        )
    return out


def ul(items, cls, title):
    items = [x for x in (items or []) if str(x).strip()]
    if not items:
        return ""
    lis = "".join(f"<li>{t(x)}</li>" for x in items)
    return f'<div class="box {cls}"><h4>{title}</h4><ul>{lis}</ul></div>'


def design_ids(e):
    ids = {str(e.get("id", "")).split("_")[0]}
    for i in e.get("new") or []:
        b = os.path.basename(i.get("src", "")).split(".")[0]
        if b:
            ids.add(b.split("_")[0])
    return {x for x in ids if x}


def screen(d, n, e):
    st_label, st_cls = STATUS.get(e.get("status"), ("", ""))
    old = shots(e.get("old"), "الحالي")
    new = shots(e.get("new"), "الجديد")
    old_html = (
        f'<div class="shots{" many" if len(old) > 1 else ""}">{"".join(old)}</div>' if old else ""
    )
    if e.get("oldNote"):
        old_html += f'<p class="{"cap" if old else "empty"}">{t(e["oldNote"])}</p>'
    if not old_html:
        old_html = '<p class="empty">ما في شاشة حالية.</p>'
    new_html = f'<div class="shots{" many" if len(new) > 1 else ""}">{"".join(new)}</div>' if new else '<p class="empty">ما في تصميم.</p>'
    if e.get("newNote"):
        new_html += f'<p class="cap">{t(e["newNote"])}</p>'
    fix = e.get("fix") or []
    fix_html = ""
    if [x for x in fix if str(x).strip()]:
        fix_html = '<div class="fixd"><h4>تصحيح على التصميم</h4><ul>' + "".join(f"<li>{t(x)}</li>" for x in fix if str(x).strip()) + "</ul></div>"
    anchors = " ".join(sorted(design_ids(e)))
    return f"""
<section class="scr" id="{a(d)}-{n}" data-status="{a(e.get('status',''))}" data-ids="{a(anchors)}">
  <div class="head"><span class="num">{n}</span><h3>{t(e.get('name'))}</h3>
    <span class="pill {st_cls}">{st_label}</span><span class="sub">{t(e.get('sub'))}</span></div>
  <div class="pair">
    <div class="col"><span class="tag old">الحالي</span>{old_html}</div>
    <div class="col"><span class="tag new">الجديد</span>{new_html}</div>
  </div>
  <div class="lists">{ul(e.get('changed'),'chg','إيش تغيّر')}{ul(e.get('have'),'have','الموجود')}{ul(e.get('left'),'left','الباقي')}</div>
  {fix_html}
</section>"""


def domain_panel(d):
    key = d["domain"]
    screens = d.get("screens", [])
    counts = {k: sum(1 for e in screens if e.get("status") == k) for k in STATUS}
    idx = "".join(
        f'<a href="#" data-jump="{key}-{i+1}" class="ix {STATUS.get(e.get("status"),("",""))[1]}">{i+1} {t(e.get("name"))}</a>'
        for i, e in enumerate(screens)
    )
    notes = "".join(f"<li>{t(x)}</li>" for x in d.get("notes") or [])
    body = "".join(screen(key, i + 1, e) for i, e in enumerate(screens))
    filt = "".join(
        f'<button type="button" class="flt" data-f="{k}">{lbl} <span>{counts[k]}</span></button>'
        for k, (lbl, _) in STATUS.items() if counts[k]
    )
    return f"""
<div class="panel" id="p-{key}" hidden>
  <div class="dhead"><h2>{t(d.get('title'))}</h2><p class="lede">{t(d.get('intro'))}</p>
    {'<ul class="notes">'+notes+'</ul>' if notes else ''}
    <div class="filters"><button type="button" class="flt on" data-f="all">الكل <span>{len(screens)}</span></button>{filt}</div>
    <nav class="index" aria-label="شاشات القسم">{idx}</nav></div>
  {body}
</div>"""


def life_panel(life, id_map):
    if not life:
        return '<div class="panel" id="p-life" hidden><p class="empty">ما جهزت بعد.</p></div>'
    ents = life.get("entities", [])
    tabs = "".join(f'<a href="#" data-jump="life-{i}" class="ix">{t(e.get("name"))}</a>' for i, e in enumerate(ents))
    parts = []
    for i, e in enumerate(ents):
        states = []
        for s in e.get("states", []):
            ds = []
            for x in s.get("design") or []:
                k = str(x).split("_")[0]
                tgt = id_map.get(k)
                ds.append(f'<a href="#" data-jump="{tgt}" class="did">{a(k)}</a>' if tgt else f'<span class="did">{a(k)}</span>')
            states.append(
                f'<li class="state{" ghost" if s.get("exists") is False else ""}">'
                f'<span class="sname">{t(s.get("name"))}</span>'
                + (f'<code>{a(s.get("code"))}</code>' if s.get("code") else "")
                + (f'<span class="ghostlbl">في التصميم فقط</span>' if s.get("exists") is False else "")
                + f'<span class="smean">{t(s.get("meaning"))}</span>'
                + (f'<span class="stoday"><b>اليوم:</b> {t(s.get("appToday"))}</span>' if s.get("appToday") else "")
                + (f'<span class="sdes">في التصميم: {" ".join(ds)}</span>' if ds else "")
                + "</li>"
            )
        names = {str(s.get("code")): s.get("name") for s in e.get("states", []) if s.get("code")}
        nm = lambda c: names.get(str(c), c)
        rows = "".join(
            f'<tr class="{"" if tr.get("exists", True) else "no"}"><td>{t(nm(tr.get("from")))}</td><td>{t(nm(tr.get("to")))}</td>'
            f'<td>{t(tr.get("who"))}</td><td>{t(tr.get("how"))}</td>'
            f'<td>{"موجود" if tr.get("exists", True) else "غير موجود"}</td></tr>'
            for tr in e.get("transitions", [])
        )
        parts.append(f"""
<section class="ent" id="life-{i}">
  <div class="head"><h3>{t(e.get('name'))}</h3></div>
  <p class="lede">{t(e.get('summary'))}</p>
  <ol class="flow">{''.join(states)}</ol>
  {'<div class="tbl"><table><thead><tr><th>من</th><th>إلى</th><th>مين</th><th>كيف</th><th>اليوم</th></tr></thead><tbody>'+rows+'</tbody></table></div>' if rows else ''}
  <div class="lists">{ul(e.get('designOnly'),'left','في التصميم وما له وجود في السيرفر')}{ul(e.get('serverOnly'),'have','في السيرفر والتصميم نسيه')}</div>
  {ul(e.get('decisions'),'dec','يحتاج قرارك')}
</section>""")
    return f"""
<div class="panel" id="p-life" hidden>
  <div class="dhead"><h2>دورة حياة كل شيء</h2>
  <p class="lede">كل شيء يمر عليه العريس، من أول ما ينشأ إلى آخره: حالاته في السيرفر بالترتيب، مين ينقله من حالة لحالة وكيف، وإيش يظهر منه في التطبيق اليوم وفي التصميم الجديد. الحالة المنقطة موجودة في التصميم فقط.</p>
  <nav class="index">{tabs}</nav></div>
  {''.join(parts)}
</div>"""


def summary_panel(domains, life):
    rows, tot = [], {k: 0 for k in STATUS}
    decs, fixes = [], 0
    for d in domains:
        sc = d.get("screens", [])
        c = {k: sum(1 for e in sc if e.get("status") == k) for k in STATUS}
        for k in STATUS:
            tot[k] += c[k]
        nimg = sum(len(e.get("new") or []) for e in sc)
        nold = sum(1 for e in sc if e.get("old"))
        f = sum(len([x for x in (e.get("fix") or []) if str(x).strip()]) for e in sc)
        fixes += f
        rows.append(
            f'<tr><td><a href="#" data-tab="{d["domain"]}">{t(d.get("title"))}</a></td><td>{len(sc)}</td><td>{c["build"]}</td>'
            f'<td>{c["backend"]}</td><td>{c["frozen"]}</td><td>{nold}</td><td>{nimg}</td><td>{f}</td></tr>'
        )
        for i, e in enumerate(sc):
            for x in e.get("left") or []:
                if "قرار:" in str(x):
                    decs.append((d, i + 1, e.get("name"), x))
    total = sum(len(d.get("screens", [])) for d in domains)
    dec_html = "".join(
        f'<li><a href="#" data-jump="{d["domain"]}-{n}">{t(d.get("title"))} · {t(nm)}</a>: {t(x)}</li>'
        for d, n, nm, x in decs
    )
    life_dec = ""
    if life:
        ld = [(e.get("name"), x) for e in life.get("entities", []) for x in e.get("decisions") or []]
        life_dec = "".join(f"<li>{t(n)}: {t(x)}</li>" for n, x in ld)
    return f"""
<div class="panel" id="p-sum">
  <div class="dhead"><h2>{J["h2"]}</h2>
  <p class="lede">كل شاشة في {J["who"]}: صورتها الحالية من التطبيق الحقيقي (مصوّرة من الكود)، وصورتها في التصميم الجديد، وإيش تغيّر، وإيش موجود له في السيرفر، وإيش باقي. الشاشة الواحدة تجمع حالاتها (فاضية، خطأ، أوراق منبثقة). الصور الجديدة بالفيروزي لأنها رُسمت هكذا، واللون ما تقرر بعد.</p>
  <div class="key"><span><i class="dot b"></i>يُبنى الآن: السيرفر جاهز له</span><span><i class="dot k"></i>يحتاج سيرفر قبل</span><span><i class="dot f"></i>مجمّد: اتفقنا نؤجله بعد النسخة الأولى</span><span><i class="dot x"></i>تصحيح: الصورة الجديدة فيها شيء غلط</span></div>
  </div>
  <div class="tbl"><table class="sum"><thead><tr><th>القسم</th><th>شاشات</th><th>يُبنى الآن</th><th>يحتاج سيرفر</th><th>مجمّد</th><th>لها صورة حالية</th><th>صور التصميم</th><th>تصحيحات</th></tr></thead>
  <tbody>{''.join(rows)}<tr class="tot"><td>المجموع</td><td>{total}</td><td>{tot['build']}</td><td>{tot['backend']}</td><td>{tot['frozen']}</td><td></td><td></td><td>{fixes}</td></tr></tbody></table></div>
  {top_html()}
  <section class="plain"><h3>القرارات اللي تحتاجها الشاشات ({len(decs)})</h3><ol class="decs">{dec_html}</ol></section>
  {'<section class="plain"><h3>قرارات من دورة الحياة</h3><ol class="decs">'+life_dec+'</ol></section>' if life_dec else ''}
</div>"""


def top_html():
    p = os.path.join(HERE, "data", J["top"])
    if not os.path.exists(p):
        return ""
    top = json.load(open(p, encoding="utf-8"))
    lis = "".join(f"<li>{t(x)}</li>" for x in top)
    return f'<section class="plain"><h3>أهم الأشياء الغلط في التصميم الجديد</h3><p class="lede">تأكدنا منها في كود السيرفر. البناء يمشي على الصحيح، مو على الصورة.</p><ol class="decs">{lis}</ol></section>'


CSS = open(os.path.join(HERE, "style.css"), encoding="utf-8").read()
JS = open(os.path.join(HERE, "app.js"), encoding="utf-8").read()


def main():
    domains, life = load()
    id_map = {}
    for d in domains:
        for i, e in enumerate(d.get("screens", [])):
            for k in design_ids(e):
                id_map.setdefault(k, f'{d["domain"]}-{i+1}')
    tabs = '<button type="button" class="tab on" data-tab="sum">الخلاصة</button>' + "".join(
        f'<button type="button" class="tab" data-tab="{d["domain"]}">{t(d.get("title"))} <span>{len(d.get("screens", []))}</span></button>'
        for d in domains
    ) + '<button type="button" class="tab" data-tab="life">دورة الحياة</button>'
    page = f"""<title>{J["title"]}</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800&display=swap">
<style>{CSS}</style>
<header class="top"><div class="tabs" role="tablist">{tabs}</div></header>
<main class="wrap">
{summary_panel(domains, life)}
{''.join(domain_panel(d) for d in domains)}
{life_panel(life, id_map)}
</main>
<dialog id="zoom" aria-label="الصورة مكبرة"><img id="zoomImg" alt=""></dialog>
<script>{JS}</script>"""
    with open(os.path.join(HERE, J["out"]), "w", encoding="utf-8") as f:
        f.write(page)
    imgs = sorted(set(re.findall(r'src="(img/[^"]+)"', page)))
    with open(os.path.join(HERE, "files_" + J["out"].split(".")[0] + ".json"), "w") as f:
        json.dump(imgs, f)
    print("domains", [d["domain"] for d in domains], "screens", sum(len(d.get("screens", [])) for d in domains), "images", len(imgs), "life", bool(life))


main()
