# Frontend

Snapshot date: 2026-08-31

Frontend in this repository includes:

- Flutter mobile app under `mobile/`.
- React/Vite admin web under `admin-web/`.

## Active Frontend Docs

- `docs/frontend/MOBILE.md`
- `docs/frontend/MOBILE_ARCHITECTURE.md`
- `docs/frontend/DESIGN_SYSTEM.md`
- `docs/design/AARAST_MOBILE_EXPERIENCE_SYSTEM_V3.docx` - the August V3 system,
  historical; `DESIGN_SYSTEM.md` wins.
- `docs/frontend/OFFLINE_SQLITE.md`
- `docs/frontend/ADMIN_WEB.md`
- `docs/frontend/MOBILE_ROUTES.md` - generated mobile route reference.
- `docs/frontend/ADMIN_ROUTES.md` - generated admin route reference.
- `docs/qa/MOBILE_QA.md`

## Mobile Checks

From `mobile/`:

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter test --tags golden
```

Run targeted widget/provider tests for the touched flow. For visual work, use
`docs/frontend/DESIGN_SYSTEM.md` and verify phone-width Arabic/RTL behavior.
The former Premium/Royal roadmap is archived and must not be extended.

## Admin Checks

From `admin-web/`:

```powershell
npm run test:architecture
npm run architecture
npm run build
npm run typecheck
npm test -- --run
npm run smoke:admin-runtime
```

The Admin runtime command owns a disposable local backend/database lifecycle;
use it only with the repository-managed local Docker services. R10 strict
boundaries require all cross-feature imports through exact owner public APIs
and keep the legacy Admin roots absent.
