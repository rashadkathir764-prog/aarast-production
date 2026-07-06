# Aarast Mobile Asset Reference Index

Current product truth for mobile screens comes from implementation code,
automated tests, and the Premium 2027 contracts:

- `docs/mobile-ux/AARAST_PREMIUM_2027_DESIGN_SYSTEM.md`
- `docs/mobile-ux/AARAST_PREMIUM_2027_SCREEN_CONTRACTS.md`
- `mobile/lib/**`
- `mobile/test/**`

The files below are historical or verification artifacts. They must not be used
as current screen contracts unless a future task explicitly promotes them.

| Path | Status | Notes |
| --- | --- | --- |
| `design_refs/*.jpg` | Historical reference material | Visual inspiration only; not source of product truth. |
| `design_apk/*.png` | Historical APK/reference captures | Do not infer current screen contracts from these images. |
| `docs/mobile-ux/prototypes/*.html` | Historical prototype | Superseded by Premium 2027 mobile contracts and current Flutter code. |
| `docs/mobile-ux/prototypes/*.png` | Historical prototype captures | Useful only as archived comparison evidence. |
| `mobile/test/goldens/*.png` | Test evidence | Golden outputs are verification artifacts tied to tests, not design requirements by themselves. |
| `mobile/*/app_icon.png`, `mobile/*/launcher_icon.png`, `mobile/web/icons/*.png` | Platform assets | App icons only; not screen UX references. |
| `admin-web/index.html` | Web shell entry point | Not a mobile prototype. |

If a new visual reference becomes official, update this index in the same change
that updates the relevant screen contract or test.
