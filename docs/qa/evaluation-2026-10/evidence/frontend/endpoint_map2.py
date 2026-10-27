"""Exact endpoint map. Mobile: every ApiClient call (getJson/getJsonList/
postJson*/patchJson/putJson/deleteJson) with its literal or interpolated path,
and the feature that makes it. Server: the route table from the Nest boot log.
Output: markdown tables (feature -> endpoints, broken calls, unused routes)."""
import re, os, sys, collections, json
MOBILE = '/home/user/aarast-production/mobile/lib'
ADMIN = '/home/user/aarast-production/admin-web/src'
routes_file, out_md = sys.argv[1], sys.argv[2]
server = collections.defaultdict(set)
for line in open(routes_file):
    m = re.match(r'(\S+), (GET|POST|PATCH|PUT|DELETE)', line.strip())
    if m: server[re.sub(r':\w+', ':p', m.group(1))].add(m.group(2))
METHOD = {'getJson': 'GET', 'getJsonList': 'GET', 'postJson': 'POST', 'postJsonWithReceiveTimeout': 'POST',
          'postJsonWithBearer': 'POST', 'patchJson': 'PATCH', 'putJson': 'PUT', 'deleteJson': 'DELETE'}
call = re.compile(r'\.(getJsonList|getJson|postJsonWithReceiveTimeout|postJsonWithBearer|postJson|patchJson|putJson|deleteJson)\(\s*((?:\'[^\']*\'|"[^"]*"|\s|\+|\w+)+?)\s*[,)]', re.S)
def norm(expr):
    parts = re.findall(r"'([^']*)'|\"([^\"]*)\"", expr)
    p = ''.join(a or b for a, b in parts)
    if not p: return None
    p = re.sub(r'\$\{[^}]*\}|\$[A-Za-z_]\w*', ':p', p).split('?')[0].rstrip('/')
    return p
def match(method, p):
    if p in server: return method in server[p], p
    # allow a trailing interpolated query or path segment built from a variable
    rx = '^' + re.escape(p).replace(':p', '[^/]+') + '$'
    for sp, ms in server.items():
        if re.match(rx, sp.replace(':p', 'X')) or re.match('^' + re.escape(sp).replace(':p', '[^/]+') + '$', p.replace(':p', 'X')):
            return method in ms, sp
    return False, None
calls = []
for dp, _, fs in os.walk(MOBILE):
    for f in fs:
        if not f.endswith('.dart'): continue
        path = os.path.join(dp, f); rel = os.path.relpath(path, MOBILE)
        feat = rel.split('/')[1] if rel.startswith('features/') else '/'.join(rel.split('/')[:2])
        src = open(path, encoding='utf-8').read()
        for m in call.finditer(src):
            p = norm(m.group(2)); method = METHOD[m.group(1)]
            line = src[:m.start()].count('\n') + 1
            calls.append((feat, method, p, f'{rel}:{line}', m.group(2).strip()[:60]))
by_feat = collections.defaultdict(list)
broken, dynamic = [], []
used = set()
for feat, method, p, loc, raw in calls:
    if p is None:
        dynamic.append((feat, method, loc, raw)); continue
    ok, sp = match(method, p)
    if sp: used.add((method, sp))
    by_feat[feat].append((method, p, ok, loc))
    if not ok: broken.append((feat, method, p, loc))
# admin web: fetch/api helper strings
admin_paths = set()
for dp, _, fs in os.walk(ADMIN):
    for f in fs:
        if f.endswith(('.ts', '.tsx')) and '.test.' not in f:
            for m in re.finditer(r"[`'\"](/(?:admin|api/v1)[^`'\"]*)[`'\"]", open(os.path.join(dp, f), encoding='utf-8').read()):
                admin_paths.add(re.sub(r'\$\{[^}]*\}', ':p', m.group(1)).split('?')[0].rstrip('/'))
def admin_uses(sp):
    rx = '^' + re.escape(sp).replace(':p', '[^/]+') + '$'
    return any(re.match(rx, a.replace(':p', 'X')) or a == sp for a in admin_paths)
unused = []
for sp, ms in sorted(server.items()):
    for m in sorted(ms):
        if (m, sp) in used or admin_uses(sp) or sp in ('/health', '/live', '/ready', '/metrics'): continue
        unused.append((m, sp))
with open(out_md, 'w', encoding='utf-8') as o:
    o.write(f'# خريطة الـEndpoints (مولّدة من الكود)\n\n- مكالمات الجوال للخادم: {len(calls)} ({len(dynamic)} مسارها يُبنى وقت التشغيل)\n- مسارات الخادم: {sum(len(v) for v in server.values())}\n- مكالمات بدون مسار مطابق في الخادم: {len(broken)}\n- مسارات خادم ما يستخدمها الجوال ولا الإدارة: {len(unused)}\n\n')
    o.write('## مكالمات بدون مسار مطابق في الخادم\n\n| الميزة | الطريقة | المسار | المكان |\n|---|---|---|---|\n')
    for r in broken: o.write(f'| {r[0]} | {r[1]} | `{r[2]}` | `{r[3]}` |\n')
    o.write('\n## مسارات الخادم اللي ما يناديها أحد\n\n| الطريقة | المسار |\n|---|---|\n')
    for m, sp in unused: o.write(f'| {m} | `{sp}` |\n')
    o.write('\n## كل ميزة وش تنادي\n')
    for feat in sorted(by_feat):
        o.write(f'\n### {feat}\n\n| الطريقة | المسار | موجود؟ | المكان |\n|---|---|---|---|\n')
        for method, p, ok, loc in sorted(set(by_feat[feat]), key=lambda x: (x[1], x[0])):
            o.write(f"| {method} | `{p}` | {'✅' if ok else '❌'} | `{loc}` |\n")
    if dynamic:
        o.write('\n## مكالمات مسارها متغيّر (تنراجع يدويًا)\n\n| الميزة | الطريقة | المكان | التعبير |\n|---|---|---|---|\n')
        for d in dynamic: o.write(f'| {d[0]} | {d[1]} | `{d[2]}` | `{d[3]}` |\n')
print(len(calls), 'calls;', len(broken), 'broken;', len(unused), 'unused;', len(dynamic), 'dynamic')
for r in broken: print('BROKEN', r)
