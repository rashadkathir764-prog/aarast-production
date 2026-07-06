# Frontend

Snapshot date: 2026-07-05

Frontend in this repository includes:

- Flutter mobile app under `mobile/`.
- React/Vite admin web under `admin-web/`.

## Active Frontend Docs

- `docs/frontend/MOBILE.md`
- `docs/frontend/MOBILE_ARCHITECTURE.md`
- `docs/frontend/DESIGN_SYSTEM.md`
- `docs/frontend/OFFLINE_SQLITE.md`
- `docs/frontend/ADMIN_WEB.md`
- `docs/frontend/PREMIUM_ROADMAP.md`
- `docs/frontend/MOBILE_ROUTES.md` - generated mobile route reference.
- `docs/frontend/ADMIN_ROUTES.md` - generated admin route reference.
- `docs/qa/MOBILE_QA.md`

## Mobile Checks

From `mobile/`:

```powershell
flutter analyze
flutter test
```

Run targeted widget/provider tests for the touched flow. For visual work, verify
phone-width Arabic/RTL behavior.

## Admin Checks

From `admin-web/`:

```powershell
npm run build
npm run smoke:admin-runtime
```

Admin runtime smoke requires a running backend.
