"""Generate the bride's copy of the current-screen capture tests.

Today's app has no separate bride design: the bride uses the groom's screens
with her persona, which changes some wording and the starter lists. This
script copies the groom capture tests into bride_profile/gen/ (git-ignored)
with the persona switched, so the bride's "before" shots come from the same
real screens.

  python3 test/prototype/bride_profile/gen_now.py      # from mobile/
  flutter test test/prototype/bride_profile/gen/now_bride --update-goldens
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # prototype/
OUT = os.path.join(ROOT, 'bride_profile', 'gen', 'now_bride')
DOMAINS = ['onboarding', 'home', 'money', 'tasks', 'guests', 'providers', 'account']

RULES = [
    ("'GROOM'", "'BRIDE'"),
    ('GuestPersona.groom', 'GuestPersona.bride'),
    ('AccountContextPersona.groom', 'AccountContextPersona.bride'),
    ('TaskStarterPersona.groom', 'TaskStarterPersona.bride'),
    ("find.text('العريس')", "find.text('العروسة')"),
    ("_member('m3', 'العروسة', 'BRIDE'", "_member('m3', 'العريس', 'GROOM'"),
    ("'عرس محمد'", "'عرس سلمى'"),
    ("'محمد'", "'سلمى'"),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for d in DOMAINS:
        src = os.path.join(ROOT, f'now_{d}', f'now_{d}_test.dart')
        with open(src, encoding='utf-8') as f:
            s = f.read()
        for a, b in RULES:
            s = s.replace(a, b)
        s = re.sub(r"'\.\./\.\./", "'../../../../", s)
        s = s.replace("matchesGoldenFile('out/", f"matchesGoldenFile('out/{d}_")
        s = re.sub(r"matchesGoldenFile\('out/\$", f"matchesGoldenFile('out/{d}_$", s)
        with open(os.path.join(OUT, f'{d}_test.dart'), 'w', encoding='utf-8') as f:
            f.write(s)
    print('wrote', len(DOMAINS), 'files to', OUT)


main()
