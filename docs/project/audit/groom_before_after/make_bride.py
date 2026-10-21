"""Builds data/bride_<domain>.json from the groom's data plus the bride's
own differences, and converts the bride's images. Run: python3 -I make_bride.py"""
import glob, json, os, re
from PIL import Image, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
PROTO = '/home/user/aarast-production/mobile/test/prototype'
NEW_SRC = f'{PROTO}/bride_profile/gen/v3/out'
NOW_SRC = f'{PROTO}/bride_profile/gen/now_bride/out'
DOMAINS = ['onboarding', 'home', 'money', 'tasks', 'guests', 'providers', 'account']
TITLES = {
    'onboarding': 'البداية والتسجيل', 'home': 'الرئيسية والتنبيهات', 'money': 'الفلوس',
    'tasks': 'المهام', 'guests': 'الضيفات والدعوات والهدايا', 'providers': 'المزودين',
    'account': 'الحساب والخطة والأهل',
}
SAME = 'باقي الشاشة مثل شاشة العريس الجديدة: نفس الترتيب، بلون العروسة وبكلام للمؤنث.'
HAVE = 'الموجود في السيرفر والباقي مثل شاشة العريس بالضبط (شوف صفحة العريس).'

# Bride-specific notes per groom entry id: (changed, left, fix)
NOTES = {
    'a02b': (['تختار «العروسة»: خطتها لعرس النساء: التجهيز والصالة والنقش والصبحية.'],
             ['<b>قرار:</b> لون العروسة (الوردي) يحتاج ألوان تتغير حسب صاحبة الخطة. مؤجل لين نخلص العريس.'], []),
    'a03': (['تكتب اسمها هي، والعنوان يصير «عرس سلمى».'],
            ['<b>قرار:</b> قاعدة الاسم عند العروسة: اسمها يظهر في خطتها؟ واسم العريس يظهر معها؟ التصميم يكتب «عرس سلمى ومحمد» في الرئيسية.'], []),
    'a08': (['الأرقام الحقيقية للعروسة: 11 بند مقترح، و8 مهام مقترحة من 16 (بعد تحديد الموعد).'], [],
            ['الصورة تقول «9 مهام»: للعروسة 8.']),
    'b01': (['«أهلًا سلمى» و«عرس سلمى ومحمد».'], ['<b>قرار:</b> اسم العريس يظهر في رئيسية العروسة؟'], []),
    'b02': (['خطوات العروسة: الصالة، الفستان، الكوافير، النقش.'], [], ['«من 30 مهمة»: للعروسة 16.']),
    'c01': (['مصادر فلوسها: الاتفاق مع العريس (اللي بتستلمه)، وعرسها.'], [], []),
    'c02': (['بنودها: الفستان، المكياج والشعر، الصالة، الكوشة، التصوير النسائي، الضيافة، النقش، الذهب، جهاز العروسة.'], [], []),
    'a06': (['المهر عندها: اللي بتستلمه من العريس، والباقي وموعد تسليمه.'],
            ['المهر ما له شيء في السيرفر، مثل العريس.'], []),
    'd03': (['مهامها: حجز قاعة النساء، الفستان، الكوافير، النقاشة، الفنانة، الصبحية.'], [],
            ['«أضف 30 مهمة»: للعروسة 16، منها 8 مقترحة.']),
    'd01': (['«ل نورة» و«للوالدة» بدل صالح والوالد.'], [], []),
    'e01': (['«الضيفات» و«صالة الياسمين تتسع 150».', 'مجموعات من جهتها: زميلات العمل، الصاحبات، الجارات.'], [], []),
    'e04': (['البطاقة: «أم سلمى تتشرف بدعوتكم لحضور حفل زفاف ابنتها سلمى».'],
            ['<b>قرار:</b> البطاقة تكتب اسم العروسة كبير وتنرسل لكل الضيفات. نخليه، أو نعطيها خيار تخفي الاسم؟'], []),
    'b06': (['«الرفد» صار «الهدايا»: سجّلي هدية.'], ['الهدايا ما لها شيء في السيرفر، مثل الرفد.'], []),
    'e09': (['«دفتر الهدايا» بدل «دفتر الرفد».'], [], []),
    'f02': (['فئاتها: مزينات ونقاشات، تصوير نسائي، بخور.'],
            ['<b>قرار:</b> «تصوير نسائي» يحتاج المزود يحدد إنه يخدم النساء. ما له حقل اليوم.'], []),
    'g01': (['المشاركين: نورة (أختها)، الوالدة، والعريس.'], [], []),
}

os.makedirs(f'{HERE}/img/bride_new', exist_ok=True)
os.makedirs(f'{HERE}/img/bride_now', exist_ok=True)


def conv(src, dst, trim):
    if os.path.exists(dst):
        return
    im = Image.open(src).convert('RGB')
    if trim:
        px = im.load(); h = im.height
        while h > 900 and all(sum(px[x, h - 1]) > 750 for x in range(0, im.width, 20)):
            h -= 1
        im = im.crop((0, 0, im.width, min(im.height, h + 40)))
    im = im.resize((520, int(im.height * 520 / im.width)), Image.LANCZOS)
    im.save(dst, quality=84)


def same_as_groom(bride_png, groom_png):
    if not os.path.exists(groom_png):
        return False
    a = Image.open(groom_png).convert('L'); b = Image.open(bride_png).convert('L')
    if a.size != b.size:
        return False
    diff = ImageChops.difference(a, b).point(lambda p: 255 if p > 40 else 0)
    changed = sum(1 for v in diff.getdata() if v) / (a.size[0] * a.size[1])
    return changed < 0.005  # only the name differs


def old_png(domain, jpg):
    stem = os.path.basename(jpg)[:-4]
    for cand in (f'{domain}_{stem}', *[os.path.basename(p)[:-4] for p in glob.glob(f'{NOW_SRC}/{domain}_*_{stem}.png')], f'{domain}_{domain}_{stem}'):
        p = f'{NOW_SRC}/{cand}.png'
        if os.path.exists(p):
            return p
    return None


for d in DOMAINS:
    g = json.load(open(f'{HERE}/data/{d}.json', encoding='utf-8'))
    out = []
    for e in g['screens']:
        b = {k: e.get(k) for k in ('id', 'name', 'sub', 'status')}
        olds, same = [], True
        for o in e.get('old') or []:
            p = old_png(d, o['src'])
            if p:
                dst = f'img/bride_now/{os.path.basename(p)[:-4]}.jpg'
                conv(p, f'{HERE}/{dst}', True)
                olds.append({'src': dst, 'cap': o.get('cap', '')})
                groom_png = p.replace(NOW_SRC, f'{PROTO}/now_{d}/out').replace(f'/{d}_', '/', 1)
                same = same and same_as_groom(p, groom_png)
            else:
                olds.append(o); same = False
        b['old'] = olds
        note = e.get('oldNote') or ''
        if olds and same:
            note = 'نفس شاشة العريس اليوم (الفرق الاسم بس): التطبيق الحالي ما يفرّق بين العريس والعروسة هنا.'
        b['oldNote'] = note
        news = []
        for n in e.get('new') or []:
            nid = os.path.basename(n['src'])[:-4]
            p = f'{NEW_SRC}/{nid}.png'
            if os.path.exists(p):
                dst = f'img/bride_new/{nid}.jpg'
                conv(p, f'{HERE}/{dst}', False)
                news.append({'src': dst, 'cap': n.get('cap', '')})
            else:
                news.append({'src': n['src'], 'cap': (n.get('cap') or '') + ' (صورة العريس: ما لها نسخة عروسة)'})
        b['new'] = news
        ch, left, fix = NOTES.get(e['id'], ([], [], []))
        b['changed'] = ch + [SAME]
        b['have'] = [HAVE]
        b['left'] = left or ['مثل العريس.']
        b['fix'] = fix
        out.append(b)
    json.dump({'domain': f'bride_{d}', 'title': TITLES[d],
               'intro': 'نفس شاشات العريس للعروسة. هنا بس اللي يختلف عندها.', 'screens': out},
              open(f'{HERE}/data/bride_{d}.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(d, len(out))
