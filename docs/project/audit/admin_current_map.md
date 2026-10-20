# Admin back office — current-state map

Date: 2026-10-20. Read-only audit of the working tree. Every claim is from source; `file:line` refs.
Abbreviations: `aw/` = `admin-web/src/`, `be/` = `backend/src/`. Arabic UI strings are quoted verbatim.

---

## 0. One-screen summary

- **Pages (routes):** 17 screens behind login + login + 404 (`aw/App.tsx:31-211`). 8 feature owners: auth, dashboard, providers, catalog, moderation, notifications, users, audit.
- **Backend admin endpoints:** 60 under `/admin/*` (41 `be/admin/admin.controller.ts`, 1 `be/admin/admin-audit.controller.ts`, 6 reference-catalogs + 12 governorates/districts/localities in `be/catalogs/catalogs.controller.ts`) + 7 admin auth under `/api/v1/auth/admin/*` = **67**. Matches `api_inventory.md` §1.14 count (60); one inventory row is wrong (`DELETE /admin/services/:id` is a soft disable, not a delete).
- **Admin roles:** `AdminRole { SUPER_ADMIN, OPERATIONS, MODERATOR, SUPPORT }` (`backend/prisma/schema/backoffice.prisma:1-6`), mapped to 17 permissions (`be/modules/backoffice/domain/admin-permissions.ts:4-60`). Admin accounts are created only by CLI scripts, always as SUPER_ADMIN; no UI/API to create admins or assign roles.
- **Top gaps:** no provider resubmit path after NEEDS_CHANGES; no verification-documents storage (verify = a timestamp); no bookings/deposit/dispute view; no "unclaimed listing" marker/follow-up; category has no capability/default-model fields; no settings screen (expiry days, exchange rates, assistant limits, Sana'a reference prices); conversation reports show no chat excerpt and offer no sanction; no review/provider reports; no plan restore; no account-deletion visibility; disabled categories/cities cannot be re-enabled from the UI; many destructive actions have no confirmation; dev/English jargon in Arabic copy.

---

## 1. admin-web (React SPA)

### 1.1 Stack
- React 18.3 + react-dom, react-router-dom 7.18.2, lucide-react icons, recharts 3 (charts chunk) — `admin-web/package.json`. Vite 7, TypeScript 5.9, Vitest + Testing Library.
- No state library, no data-fetching library: each page uses `useState` + `useEffect` + `load()` (full reload after every mutation).
- Served by nginx (`admin-web/nginx.conf`), SPA fallback, CSP `img-src 'self' data:` (`nginx.conf:29,40`) — remote images (provider logo/cover, service images on the media origin `AARAST_MEDIA_PUBLIC_BASE_URL`) are likely blocked by CSP unless same-origin (inference; verify on deployed panel).
- API base: `VITE_API_BASE_URL`, else dev `http://127.0.0.1:3115`, prod fallback `https://aarast-api.shadowgardn.com` (`aw/platform/api/client.ts:1-9`).
- Architecture gate: `npm run architecture` (`admin-web/scripts/admin-boundaries.mjs`); cross-feature imports only via `features/<owner>/api.ts` (DECISIONS.md:341).

### 1.2 Routing (`aw/App.tsx`)
| Path | Page | Guard permission | Line |
|---|---|---|---|
| `/login` | LoginPage | public | 31 |
| `/` (index) | DashboardPage | DASHBOARD_READ | 40-47 |
| `/providers/applications` | ProviderApplicationsPage | PROVIDERS_READ | 48-59 |
| `/providers/applications/:id` | ProviderApplicationDetailsPage | PROVIDERS_READ | 60-67 |
| `/providers` | ProvidersPage | PROVIDERS_READ | 68-78 |
| `/providers/new` | redirect → `/providers/applications` (dead) | PROVIDERS_READ | 79-86 |
| `/providers/:id` | ProviderDetailsPage | PROVIDERS_READ | 87-94 |
| `/cities` | CitiesPage | CATALOG_READ | 95-102 |
| `/cities/new` | redirect → `/cities` (dead) | CATALOG_READ | 103-110 |
| `/categories` | CategoriesPage | CATALOG_READ | 111-118 |
| `/reference-catalogs` | ReferenceCatalogsPage | CATALOG_READ | 119-126 |
| `/administrative-areas` | AdministrativeAreasPage | CATALOG_READ | 127-134 |
| `/users` | UsersPage | USERS_READ | 135-142 |
| `/users/:id` | UserDetailsPage | USERS_READ | 143-150 |
| `/services` | ServicesPage | SERVICES_READ | 151-158 |
| `/services/new` | redirect → `/services` (dead) | SERVICES_READ | 159-166 |
| `/reviews` | ReviewsPage | REVIEWS_READ | 167-174 |
| `/conversation-reports` | ConversationReportsPage | CONVERSATION_REPORTS_READ | 175-184 |
| `/notifications` | NotificationsPage | NOTIFICATIONS_READ | 185-192 |
| `/reports` | ReportsPage | REPORTS_READ | 193-200 |
| `/audit-logs` | AuditLogsPage | AUDIT_READ | 201-208 |
| `/admin` | redirect → `/` | — | 210 |
| `*` | NotFoundPage «الصفحة غير موجودة» (`aw/platform/routing/NotFoundPage.tsx:7`) | — | 211 |

`RequireAdminPermission` redirects silently to `/` on missing permission (`aw/features/auth/RequireAdminPermission.tsx:15`) — no "forbidden" message.

### 1.3 Navigation / sidebar (`aw/layout/adminNavigation.ts`), in order
Group «نظرة عامة» (:70): «لوحة التحكم» `/` (:74), «التقارير» `/reports` (:81).
Group «السوق والكتالوج» (:89): «الموردون» `/providers` (:94), «طلبات الموردين» (:101), «الخدمات» (:108), «التقييمات» (:115), «فئات الموردين» (:122), «الكتالوجات الديناميكية» (:129), «المحافظات والمديريات» (:136), «المدن والمناطق» (:143) — the last two share the `MapPin` icon.
Group «الحسابات والرقابة» (:150): «المستخدمون» (:155), «بلاغات المحادثات» (:162), «الإشعارات» (:169), «سجل التدقيق» (:176).
- Links are hidden per permission; empty groups hidden (`aw/layout/Sidebar.tsx:83-101`).
- Detail breadcrumbs: «تفاصيل طلب مورد», «تفاصيل مورد», «تفاصيل مستخدم» (`adminNavigation.ts:191,197,203`). Fallback «صفحة غير معروفة» (:220).

### 1.4 Layout
- `aw/layout/AdminLayout.tsx`: `dir="rtl"` shell (:65), sidebar drawer on small screens with scrim «إغلاق القائمة» (:77), Escape closes, `inert` on main while open.
- Sidebar brand «اعّرست» / «لوحة الإدارة» (`Sidebar.tsx:67-68`), footer note «مساحة تشغيلية هادئة لمتابعة الطلبات والكتالوج وسلامة الحسابات.» (:106), «تسجيل الخروج» (:110).
- Topbar: breadcrumb «لوحة الإدارة / {group}» (`Topbar.tsx:39`); profile shows name and the fixed label «مدير النظام» (:53-54) for every role — actual admin role is never shown.
- No global search, no notification bell/inbox for admins, no dark mode.

### 1.5 Auth flow
- **Login** (`aw/features/auth/LoginPage.tsx`): phone «رقم الهاتف» (:370) placeholder `7XXXXXXXX` + «كلمة المرور» (:379) → `POST /api/v1/auth/admin/login`. If the browser holds a trusted-device cookie (30 days, `be/modules/identity/internal/auth/admin-trusted-device.ts:11-12`) the session starts without a code; else a WhatsApp OTP challenge: heading «التحقق بخطوتين» (:218), field «رمز التحقق» (:295), button «تحقق وافتح اللوحة» (:242) → `POST /api/v1/auth/admin/login/complete`. Dev shows «رمز التطوير المحلي: {code}» (:309). Back: «العودة وتسجيل الدخول من جديد» (:432).
- **Password recovery** 3 steps: «نسيت كلمة المرور؟» (:392) → phone «رقم هاتف المسؤول» (:314) → `POST …/password-reset/request`; code «رمز الاستعادة» (:325) with resend countdown «إعادة الإرسال خلال {n} ث» (:444) → `POST …/password-reset/verify`; new password + confirmation (min 6, max 72 bytes; :27-29, :153) → `POST …/password-reset/confirm`; notice «تم تغيير كلمة المرور وإلغاء الجلسات السابقة…» (:173). Neutral wording does not reveal account existence (:19-23, :231).
- **Session**: access token in memory only (`aw/platform/api/client.ts:14-37`); refresh = httpOnly `aarast_admin_refresh` cookie, path `/api/v1/auth/admin` (`be/modules/identity/api/auth.controller.ts:38,148-170`). On boot `restoreAdminSession()` calls `POST /api/v1/auth/admin/refresh`. 401 → one silent refresh then retry, else «انتهت جلسة الإدارة. سجّل الدخول مرة أخرى.» (`aw/features/auth/AuthProvider.tsx:43`). Logout `POST /api/v1/auth/admin/logout`.
- Client rejects non-ADMIN `user.role` «ليس لديك صلاحية الدخول إلى لوحة الإدارة» (`aw/features/auth/transport.ts` acceptAdminSession).
- All mutating requests carry `X-Client-Request-Id` UUID (`client.ts:70-72,144`) → idempotency + audit request id.
- English server messages are mapped to Arabic by HTTP status (`client.ts:197-206`), e.g. 409 «تغيّرت البيانات قبل الحفظ. حدّث الصفحة ثم حاول مرة أخرى.».
- Login is not audited (audit interceptor only covers `/admin*`).

### 1.6 Roles/permissions in the UI
- `AdminPermission` enum mirrored client-side (`aw/features/auth/adminPermissions.ts`); server sends `adminPermissions[]` on the session user (`be/modules/identity/public/safe-user.ts:13,38`).
- Gating: route guard (`RequireAdminPermission`), sidebar filter, and `<Can permission>` around write controls. Matrix (from `be/modules/backoffice/domain/admin-permissions.ts:26-60`):

| Permission | SUPER_ADMIN | OPERATIONS | MODERATOR | SUPPORT |
|---|---|---|---|---|
| DASHBOARD_READ | Y | Y | Y | Y |
| REPORTS_READ | Y | Y | – | – |
| USERS_READ / WRITE | Y/Y | Y/Y | –/– | Y/– |
| PROVIDERS_READ / WRITE | Y/Y | Y/Y | Y/– | Y/– |
| SERVICES_READ / WRITE | Y/Y | Y/Y | –/– | Y/– |
| CATALOG_READ / WRITE | Y/Y | Y/Y | –/– | Y/– |
| REVIEWS_READ / WRITE | Y/Y | Y/– | Y/Y | –/– |
| CONVERSATION_REPORTS_READ / WRITE | Y/Y | –/– | Y/Y | –/– |
| NOTIFICATIONS_READ / WRITE | Y/Y | Y/– | Y/Y | Y/– |
| AUDIT_READ | Y | – | – | – |

- Extra UI rule: user enable/disable button shown for an ADMIN target only if current admin is SUPER_ADMIN, disabled for self (`aw/features/users/UsersPage.tsx:176-184`). Not applied on `UserDetailsPage` (button always shown with USERS_WRITE; server still refuses, `be/admin/admin-user-status.ts:28-35`).
- Role labels exist only in the audit page (`aw/features/audit/AuditLogsPage.tsx:195-200`: «مدير أعلى», «تشغيل», «إشراف محتوى», «دعم»). `RoleBadge` knows only USER/ADMIN/PROVIDER: «مستخدم», «إدارة», «مورد» (`aw/design_system/RoleBadge.tsx`).

### 1.7 i18n / RTL
- Arabic only, hard-coded literals (no i18n library). `index.html` `lang="ar" dir="rtl"`, title «إدارة أعّرست» (`admin-web/index.html:6`) — spelling differs from brand «اعّرست» required by checklist 5.5.
- Dates: `Intl.DateTimeFormat('ar-YE')` via `aw/platform/i18n/formatDate.ts` (null → «غير محدد»), but Reports, Reviews, ConversationReports, Notifications, Audit each define their own local `formatDate` with time (duplicated).
- Phones/IDs rendered with `dir="ltr"`.

### 1.8 Design system (`aw/design_system/`)
Components: ActionButton/ActionLink, ConfirmDialog (focus-trap, optional required note), DataTable (horizontal scroll, `minWidth`), DetailField, EmptyState (`tone='api'`), ErrorState (always titled «تعذر تحميل البيانات», `ErrorState.tsx:10`), FilterSelect, FormCard, FormField/TextAreaField, LoadingSkeleton, LoadingState, MiniDonut (recharts), PageHeader (eyebrow, glyph icon e.g. «□», «◉», «%»), Pagination, RoleBadge, SearchInput (submit-on-enter), SectionCard, StatCard (tones brand/gold/info/success/warning/danger), StatusBadge, TableToolbar, Timeline.
- `StatusBadge` map (`StatusBadge.tsx:3-27`): ACTIVE «نشط», PENDING «قيد المراجعة», NEEDS_CHANGES «يحتاج تعديل», REJECTED «مرفوض», SUSPENDED «موقوف», DISABLED «معطل», OPEN «مفتوح», REVIEWED «تمت المراجعة», DISMISSED «مرفوض» (same word as REJECTED), PUBLISHED «منشور», etc. Unknown values (e.g. `FEATURED`, quote statuses) render raw English.
- Tokens (`aw/styles/globals.css:23-80`, 2905 lines): semantic neutral set (`--brand: #800020`, `--canvas #f6f7fb`, success/warning/danger/info + muted) plus a legacy burgundy/gold/pearl set (`--color-burgundy-*`, `--color-gold-*`) still present (checklist 5.6 "remove transitional palette" open). Font Tajawal bundled (`aw/assets/fonts`). Breakpoints 1320/1180/1100/980/900/760/620/420; `prefers-reduced-motion` supported; no `prefers-color-scheme`.

---

## 2. Pages (what each shows, actions, endpoints)

Common pattern on every list page: full-page `LoadingState`; any error (including a failed **action**) replaces the whole page with `ErrorState` + «إعادة المحاولة» (except ReferenceCatalogs/AdministrativeAreas/ConversationReports which show inline banners); page size 20; "page > totalPages → jump back"; KPI cards are mostly *page-local* counts («… في الصفحة»).

### 2.1 Dashboard `/` — `aw/features/dashboard/DashboardPage.tsx`
- Calls: `GET /admin/dashboard/stats`, `GET /admin/providers/applications?status=PENDING&limit=5` (:43-46).
- Header «مرحباً، {name}» (:62), eyebrow «نظرة تشغيلية»; CTA «مراجعة {n} طلب/طلبات» → applications, or «عرض الموردين» (:133-135).
- KPI cards: «المستخدمون», «الموردون», «خطط الزواج», «طلبات العروض» (:141-164).
- Card «طلبات الموردين التي تنتظر المراجعة» (top 5 PENDING; NEEDS_CHANGES excluded from list though counted in CTA) with empty «قائمة المراجعة فارغة» (:179).
- Card «صورة العمل اليوم»: «طلبات جديدة», «طلبات تحتاج تعديل», «موردون نشطون», «مدن مفعّلة» (:213-226).
- Donut «حالة الموردين» (5 statuses) (:234-241).
- Quick links «وصول سريع» gated by permission (:244-294): «طلبات الموردين», «دليل الموردين», «فئات الموردين», «المدن والمناطق», «الخدمات», «مراقبة التقييمات», «إشعارات الحساب» (label wrong: page is all-user system log), «التقارير التشغيلية». No links to reference catalogs, administrative areas, conversation reports, users, audit.
- States: loading «جارٍ تجهيز لوحة التحكم», error, empty «لا توجد بيانات».

### 2.2 Reports `/reports` — `aw/features/dashboard/ReportsPage.tsx` + `SuccessReportSection.tsx`
- Calls: `GET /admin/reports/overview` (no `from/to` sent although backend supports them, `be/admin/admin.controller.ts:54-58`), `GET /admin/reports/success`.
- Header «تقرير تشغيلي حقيقي», description exposes path «لقطة تشغيلية من /admin/reports/overview…» (:76); source shown via `StatusBadge status='OPEN'` → «مفتوح» (:80) (meaningless).
- Success section (4.21): «مستخدمون نشطون هذا الأسبوع» «{active} من {total}», «تكاليف مسجلة لكل خطة», «طلبات عروض صارت حجزًا» «{rate}٪ ({n} من {m})», «مزوّدون يراهم العملاء» (`SuccessReportSection.tsx:48-70`). Market prices table «تقرير أسعار السوق» columns «المدينة/الفئة/المزوّدون/أقل سعر/الوسيط/أعلى سعر», ≥3 providers rule, empty «لا توجد بيانات كافية بعد» (:75-100).
- KPI row: users, providers, services, reviews, notifications.
- Table «مؤشرات التشغيل» rows with dev notes: «من جدول ProviderService.» (:59), «أوقفها الأدمن.» (:56). Table «حالات طلبات العروض» subtitle «Planning leads فقط، ليست حجوزات مدفوعة.» (:119) and raw English status values (:128). Empty text «لم يرجع endpoint التقارير بيانات…» (:40).
- No date range picker, no export, no charts over time.

### 2.3 Provider applications `/providers/applications` — `aw/features/providers/ProviderApplicationsPage.tsx`
- Calls: `GET /admin/providers/applications?status&cityId&categoryId&search&page&limit`, `GET /admin/cities`, `GET /admin/provider-categories`, `GET /admin/dashboard/stats` (:72-84). Default backend statuses = PENDING, NEEDS_CHANGES, REJECTED (`be/admin/provider-admin-lifecycle.ts:32-36`).
- KPIs «جديد», «يحتاج تعديل», «مرفوض» (:135-141).
- Filters: search «بحث باسم النشاط أو الهاتف» (backend also matches ownerName, email, account name/phone), status select «الطلبات غير المعتمدة / جديد / يحتاج تعديل / مقبول / مرفوض / موقوف» (:24-31 — ACTIVE/SUSPENDED offered on an applications page), city, category (category filter also matches any service category).
- Table «سجل الطلبات»: «رقم الطلب» (`#` + 8 chars), «المورد» (+ owner), «المدينة», «نوع الطلب» (= primary category; fallback «خدمة أعراس»), «الحالة», «تاريخ الطلب», «الإجراءات» (:205-213).
- Row actions = `ProviderActions` (§2.6). Empty «لا توجد طلبات حاليا».
- No "submitted again"/resubmission indicator, no age/SLA, no assignment, no bulk.

### 2.4 Application detail `/providers/applications/:id` — `ProviderApplicationDetailsPage.tsx`
- Call: `GET /admin/providers/applications/:id` (same payload as `GET /admin/providers/:id`, `be/admin/admin.service.ts:140-142`).
- Sections: summary card; «إجراءات المراجعة» with `ProviderActions` and «ملاحظة الإدارة: {reviewNote}» (:77-86); «بيانات النشاط» (name, city, category, phone, WhatsApp, email, description); «صاحب الحساب» (name, account phone, email, role raw e.g. `PROVIDER`) (:109-124); «خط المراجعة» timeline (created, reviewed) (:128-144); «المستندات والصور» subtitle «حسب ما يتيحه backend حاليا.» — only logo/cover, no documents (:147-157); «الخدمات والباقات» cards (:161-189).
- Missing: who reviewed (`reviewedBy` is in payload, not shown), history of decisions, address/latitude/longitude, gallery/service images, claim state.

### 2.5 Providers directory `/providers` — `ProvidersPage.tsx`
- Calls: `GET /admin/providers?…` (default ACTIVE+SUSPENDED), cities, categories.
- Header «ملفات الموردين داخل المنصة» (:121). KPIs «كل النتائج», «نشط في الصفحة», «موقوف في الصفحة», «خدمات الصفحة», «طلبات الصفحة» (:127-131).
- Filters as applications; status options «النشطون والموقوفون / نشط / موقوف / جديد / يحتاج تعديل / مرفوض».
- Table «قائمة الموردين»: «المورد» (+category · updatedAt), «الحالة», «المدينة», «الهاتف», «الخدمات», «طلبات العروض», «التقييم» «{avg} / 5 · {n} تقييم», «الإجراءات» (:195-204).
- Side: «ترتيب سريع» top-5 by quote requests on current page (:250-280).
- Side (PROVIDERS_WRITE): `AddListedProviderCard` and `ImportProvidersCard` (:282-293).
- No column for verified, featured, claimed/unclaimed (`userId == null`), or bookings.

### 2.6 Provider actions (shared) — `aw/features/providers/providerHelpers.tsx`
Visibility mirrors backend transitions (`providerHelpers.tsx:26-36` ↔ `be/admin/provider-admin-lifecycle.ts:11-30`):

| Action | From status | Dialog title / message | Note | Endpoint |
|---|---|---|---|---|
| «اعتماد» | PENDING, NEEDS_CHANGES, REJECTED | «اعتماد المورد» / «سيصبح المورد ظاهرا للعملاء في سوق الموردين بعد الاعتماد.» (:69-70) | – | `PATCH /admin/providers/:id/approve` |
| «تفعيل» | SUSPENDED | «تفعيل المورد» / «سيعود المورد إلى الحالة النشطة…» (:83) | – | `PATCH …/activate` |
| «طلب تعديل» | PENDING, REJECTED | «سيبقى المورد مخفيا حتى يراجع بياناته…» (:96) | required «ملاحظة الإدارة» | `PATCH …/request-changes` body `{note}` |
| «رفض» | PENDING, NEEDS_CHANGES | «رفض الطلب» (:112) | required «سبب الرفض» (backend optional) | `PATCH …/reject` body `{reason}` |
| «إيقاف» | ACTIVE | «إيقاف المورد» / «سيتم إخفاء المورد من السوق العام مؤقتا حتى تتم مراجعته.» (:128-129) | required «سبب الإيقاف» (backend optional) | `PATCH …/suspend` body `{reason}` |
| «توثيق» | ACTIVE & not verified | «تأكد أنك راجعت وثائق المورد (السجل التجاري أو الهوية). ستظهر شارة «موثّق» للعملاء.» (:145) | – | `PATCH …/verify` body `{}` |
| «إلغاء التوثيق» | verified (any status) | «ستختفي شارة «موثّق» عن المورد في التطبيق.» (:158) | – | `PATCH …/unverify` |

All behind `<Can PROVIDERS_WRITE>`; errors show inside dialog. REQUEST_CHANGES is not allowed from NEEDS_CHANGES (cannot amend the note); APPROVE from REJECTED is allowed (no re-review step).

### 2.7 Provider detail `/providers/:id` — `ProviderDetailsPage.tsx`
- Call `GET /admin/providers/:id`. KPIs «الخدمات», «الباقات», «طلبات العروض», «التقييمات» (hint «متوسط {x}») (:77-89). Sections «حالة الظهور العام» (actions + review note), «بيانات عامة» (phone, WhatsApp, city, category, address, created), «سجل الحالة» timeline, «الخدمات» cards (packages not listed here although counted).
- No edit of provider profile fields, no featured toggle (backend has `isFeatured` field but no admin endpoint), no reviews/quote list, no link to owner user, no bookings.

### 2.8 Add listed provider (4.18) — `AddListedProviderCard.tsx`
- Title «إضافة مزوّد بلا حساب», subtitle «يظهر في الدليل بعد إضافة خدمة نشطة له، ويستلمه صاحبه من التطبيق حين يسجّل بنفس الرقم.» (:71-72).
- Fields: «اسم النشاط»*, «رقم الجوال (رقم صاحب النشاط)»*, «رقم واتساب (اختياري)», «المدينة»*, «الفئة»*, «العنوان (اختياري)», «نبذة (اختياري)».
- `POST /admin/providers`. Success «أُضيف «{name}». أضف له خدمة ليظهر في الدليل.» with link to `/services` (:143-144) (not pre-filtered). Duplicate phone `PROVIDER_PHONE_TAKEN` → «هذا الرقم مسجّل لمزوّد آخر…» (:159). No confirmation.

### 2.9 CSV import (4.22) — `ImportProvidersCard.tsx` + `providerCsv.ts`
- Title «استيراد مزوّدين من ملف» (:78); «تنزيل القالب» (data: URI CSV) (:82-83); headers «اسم النشاط, الجوال, واتساب, المدينة, الفئة, العنوان, النبذة» (`providerCsv.ts:15-23`); max 300 rows (`providerCsv.ts:12`).
- Pre-validation listing «الصف {n}: …»; button «استيراد {n} مزوّد» (:112) — no confirm; rows sent sequentially to `POST /admin/providers` (one audit entry each); result «أُضيف {a} من {b}…» (:120). No rollback, no downloadable error report.

### 2.10 Services `/services` — `aw/features/catalog/ServicesPage.tsx`
- Calls: `GET /admin/services?search&status&cityId&categoryId&page&limit`, `GET /admin/providers?search&page=1&limit=20` (for dropdown — only first 20 ACTIVE/SUSPENDED providers; PENDING/listed-unapproved can't be picked), cities, categories.
- Header description «إدارة حقيقية من Admin API…» (:167); form subtitle «تُحفظ مباشرة في /admin/services.» (:180); list subtitle «هذه ليست قراءة عامة؛ كل صف من /admin/services.» (:311).
- Create form (SERVICES_WRITE): «المورد», «الفئة», «بحث المورد», «اسم الخدمة», «السعر الأساسي» (currency fixed YER) → `POST /admin/services`. No description/priceUnit/city/images.
- Status filter «كل الحالات / نشطة / متوقفة / مميزة».
- Table: «الخدمة», «المورد», «الفئة», «المدينة», «السعر» («حسب الطلب»), «الحالة» (+ raw `FEATURED` badge text), «إجراءات».
- Row actions, **no confirmation**: «إيقاف»/«تفعيل» and «تمييز»/«إلغاء التمييز» → `PATCH /admin/services/:id`.
- Not used: `DELETE /admin/services/:id` (`aw/features/catalog/api.ts:244` defined, no caller); editing title/price/description.

### 2.11 Categories `/categories` — `CategoriesPage.tsx`
- `GET /admin/provider-categories`; create/update `POST|PATCH /admin/provider-categories[/:id]`; «تعطيل» → `DELETE /admin/provider-categories/:id` (soft: `isActive=false`, `be/admin/admin-mutation-executor.ts:440-461`) with dialog «سيتم تعطيل هذه الفئة من إدارة السوق دون حذفها نهائيا.» (:193).
- KPIs total/active/providers/services. Table: «اسم الفئة», «الأيقونة» (free text), «يظهر في» («العريس والعروسة»/«العريس»/«العروسة»/«مخفي من المسارين»), «الحالة», «الترتيب», «الموردون», «الخدمات», «إجراءات».
- Form: «الاسم العربي», «الاسم الإنجليزي», «المعرف slug», «الأيقونة», «الترتيب», audience checkboxes «العريس»/«العروسة» with guard «اختر مسارًا واحدًا على الأقل…» (:266).
- Gap: payload never sends `isActive` (:79-87) → a disabled category **cannot be re-enabled** from UI; «تعطيل» is shown on already-disabled rows. Save error replaces the page (`setError` shared with load).

### 2.12 Cities `/cities` — `CitiesPage.tsx`
- `GET/POST/PATCH/DELETE /admin/cities[/:id]`; same pattern as categories. Header «إدارة المدن اليمنية» (:106). Form: Arabic name, English name, «رمز الدولة», order. Disable dialog «سيتم تعطيل المدينة من قوائم إدارة السوق دون حذفها نهائيا.» (:167). Same re-enable gap.
- Legacy `City` coexists with governorate/district model (DECISIONS.md:265); providers/services still reference `City`.

### 2.13 Reference catalogs `/reference-catalogs` — `ReferenceCatalogsPage.tsx`
- Calls: `GET /admin/reference-catalogs`, `GET /admin/reference-catalogs/:key`, `POST …/:key/items`, `PATCH …/:key/items/:id`, `POST …/:key/items/:id/publish` `{revision?}`, `DELETE …/:key/items/:id`.
- Two system catalogs seeded: `money.starter.categories` «تصنيفات بداية الميزانية», `tasks.starter` «قوالب المهام» (`be/catalogs/reference-catalog.defaults.ts:283-296`).
- Header «الكتالوجات التي تتحدث دون إصدار جديد» (:242), meta «إصدار الكتالوج {v}». KPIs «الكتالوجات», «العناصر», «المجموعات», «بانتظار النشر».
- Table: «العنصر» (+key), «المجموعة» (+icon key), «الجمهور» (groom/bride/provider only; customer flag not shown, :449-455), «الحالة» (+«مسودة غير منشورة»), «الترتيب», actions «تعديل», «نشر المسودة» (no confirm), revision select «نسخة {n} · منشورة» + «اعتماد» (republish old revision, no confirm), «إيقاف» (confirm «سيُنشر إصدار غير نشط…», :349; backend creates + bumps version immediately, `be/catalogs/reference-catalog.service.ts:247-277`).
- Form: «المعرّف الثابت (اختياري)», «الاسم العربي», «اسم المجموعة», «معرّف المجموعة», «وصف المجموعة», icon select (31 hard-coded keys, :28-60), «الترتيب», flags «العريس/العروسة/المستخدم/المزوّد/مقترح افتراضيًا/نشط».
- Gaps: `nameEn` and `metadata` not editable — `tasks.starter` items carry `metadata.daysBefore` (`reference-catalog.defaults.ts:271`), so task offset days cannot be changed from UI; no catalog creation; no diff between draft and published.

### 2.14 Administrative areas `/administrative-areas` — `AdministrativeAreasPage.tsx`
- Calls: `GET/POST /admin/governorates`, `PATCH/DELETE /admin/governorates/:id`, `GET/POST /admin/governorates/:id/districts`, `PATCH/DELETE /admin/districts/:id`, `GET/POST /admin/districts/:id/localities`, `PATCH/DELETE /admin/localities/:id`.
- Header «المحافظات والمديريات والمناطق» (:231). KPIs «المحافظات», «مديريات المحافظة», «مناطق المديرية», «النشطة هنا».
- Path selectors «1 · المحافظة», «2 · المديرية» (inactive suffixed «· معطلة»); add buttons «+ محافظة», «+ مديرية», «+ منطقة أو حي».
- Localities table: «الاسم» (+code), «النوع» (AREA «منطقة», ISOLATION «عزلة», NEIGHBORHOOD «حي», ZONE «نطاق», :63-68), «يتبع», «الحالة», «الترتيب», actions «تعديل», «إيقاف» (confirm).
- Editor: code (immutable after create), Arabic/English name, type, parent, order, active checkbox «نشط ويظهر في الاقتراحات» (re-enable possible here, unlike cities/categories), «إيقاف» in editor.
- Not in UI: governorate `latitude/longitude` (DTO supports, `be/catalogs/dto/admin-reference-catalog.dto.ts`).

### 2.15 Reviews `/reviews` — `aw/features/moderation/ReviewsPage.tsx`
- Calls: `GET /admin/reviews?search&providerId&status&page&limit`, `GET /admin/providers?search&limit=20` (provider filter list).
- Header «رقابة تقييمات الموردين», description «إدارة حقيقية من /admin/reviews…» (:119); list subtitle «لا يوجد مسح محدود لأول 30 مورد؛ المصدر إداري مباشر.» (:178) (dev jargon).
- KPIs page-local published/pending/hidden/average.
- Filters: search «بحث بالعميل أو المورد أو التعليق» (backend: comment, reviewer name, provider name), provider search + select, status «منشورة/قيد المراجعة/مخفية».
- Table: «العميل» (+«بيانات الاتصال خاصة»), «المورد», «النجوم», «التعليق», «الحالة», «التاريخ», «إجراءات».
- Actions, **no confirmation, no reason**: «نشر» → `PATCH /admin/reviews/:id/status {PUBLISHED}`; «مراجعة» → `{PENDING}`; «إخفاء» → `DELETE /admin/reviews/:id` (sets HIDDEN). Rating recomputed in same tx. No notification to reviewer or provider. No provider reply shown. No user-reported reviews queue (no model).

### 2.16 Conversation reports `/conversation-reports` — `ConversationReportsPage.tsx`
- Calls: `GET /admin/conversation-reports?status&page&limit`, `PATCH /admin/conversation-reports/:id/status`.
- Header «بلاغات المحادثات», description «…دون إظهار محتوى الرسائل أو البيانات المالية.» (:106); subtitle «تظهر هوية المبلّغ وسياق المزود فقط، ولا تعرض سجل المحادثة.» (:135).
- Filter status «مفتوحة/تمت مراجعتها/مرفوضة» (:23-28). KPIs page-local.
- Table: «المبلّغ» (name + full phone), «المزود» (+«آخر طلب {raw quoteRequest id}»), «السبب» (free text 3-500 chars), «الحالة», «التاريخ», «إجراءات».
- Actions, **no confirmation, no resolution note**: «تمت المراجعة» (REVIEWED), «رفض البلاغ» (DISMISSED) (:185,196). OPEN can be reached only via API.
- Missing vs contract (provider spec §8 "ترى محتوى المحادثة فقط في البلاغ المحدد"): no message excerpt/transcript, no reported party identity (only provider business; the customer side when a provider reports is not shown), no links to provider/user, no sanction action (suspend provider / disable user) from the report, no reporter notification.

### 2.17 Notifications `/notifications` — `aw/features/notifications/NotificationsPage.tsx`
- Calls: `GET /admin/notifications?type&priority&unreadOnly&search&page&limit`, `GET /admin/notifications/unread-count`, `PATCH /admin/notifications/:id/read`, `PATCH …/:id/archive`, `DELETE /admin/notifications/:id`.
- This is the **system log of all users' notifications**, not an admin inbox (subtitle «المصدر إداري عام، وليس إشعارات الحساب الحالي فقط.» :206). Finance content redacted server-side (`toAdminNotificationPrivacyView`), phone masked.
- Filters: type (11 hard-coded options :26-38; enum has more), priority, «غير المقروءة فقط».
- Table: «الإشعار», «المستخدم», «النوع», «الأولوية», «القراءة», «الارتباط» (raw entityType / routeTarget), «التاريخ», «إجراءات».
- Actions, **no confirmation**: «قراءة», «أرشفة», «حذف» (hard delete of a user's notification).
- Semantics problem: admin marking a user's notification read/archived/deleted mutates that user's inbox.

### 2.18 Users `/users` — `aw/features/users/UsersPage.tsx`
- Calls: `GET /admin/users?search&page&limit`, `PATCH /admin/users/:id/disable|activate`.
- Header «حسابات المستخدمين دون بيانات حساسة» (:97). KPIs page-local. Search only (name/phone); frontend type has `status` but backend `listUsers` ignores status (`be/admin/admin.service.ts:587-606`).
- Table: «الاسم» (+ placeholder «معرف آمن للعرض الإداري»), «الهاتف» (full, unmasked — unlike notifications), «البريد», «الدور», «الحالة», «المورد المرتبط», «تاريخ التسجيل», «إجراءات» («عرض التفاصيل», «تعطيل»/«تفعيل»).
- «تعطيل» has **no confirmation** although it revokes refresh tokens, live invites issued by the user, emits session-revoked outbox and disconnects realtime (`be/admin/admin.service.ts:641-689`).
- Side «توزيع الأدوار» from current page only.

### 2.19 User detail `/users/:id` — `UserDetailsPage.tsx`
- `GET /admin/users/:id`; toggle «تعطيل الحساب»/«تفعيل الحساب» (no confirm). Fields name, phone, email, role, status, created, updated; «المزود المرتبط» link.
- Not shown: admin sub-role (`toSafeUser` omits `adminRole`, `be/admin/admin.presenter.ts` toSafeUser), last login, app persona, plans/memberships (by design), deletion status.

### 2.20 Audit log `/audit-logs` — `aw/features/audit/AuditLogsPage.tsx`
- `GET /admin/audit-logs?page&limit&action&actorUserId&phase` (backend also accepts `from`, `to` — unused).
- Filters: text «بحث بالعملية أو المسار», «معرّف المسؤول» (raw id), phase «بدأت/نجحت/فشلت».
- Table: «الوقت», «المسؤول» (raw user id, no name), «الدور», «العملية» (`PATCH /admin/providers/:id/approve` + «event {uuid}»), «الهدف» (raw id), «النتيجة» (phase + «HTTP {code}» + errorType), «معرّف الطلب». Subtitle uses English phase names (:127).
- No request reason/note captured; no link to target entity.

### 2.21 Login / 404 / ErrorBoundary
See §1.5; ErrorBoundary «حدث خطأ غير متوقع» + «العودة إلى لوحة التحكم» (`aw/platform/errors/ErrorBoundary.tsx:38-46`).

---

## 3. Backend admin API

### 3.1 Guards & cross-cutting
- Class guards on every admin controller: `JwtSessionGuard, AdminGuard, AdminPermissionGuard` (`be/admin/admin.controller.ts:37`, `admin-audit.controller.ts:11`, `be/catalogs/catalogs.controller.ts:51,111`).
- `AdminGuard`: `role===ADMIN && adminMfa===true && sessionScope==='admin'` (`be/modules/backoffice/public/admin.guard.ts:17-21`).
- `AdminPermissionGuard`: route must declare `@RequireAdminPermission`, else 403 (fail-closed) (`admin-permission.guard.ts:25-27`).
- Every mutation re-checks the actor inside a SERIALIZABLE tx with row lock (`runAuthorizedAdminMutation`, `be/modules/backoffice/public/admin-mutation-gate.ts`).
- **Audit**: global `AdminAuditInterceptor` (`be/app.module.ts:98`) writes `AdminAuditLog` ATTEMPT before and SUCCEEDED/FAILED after every POST/PUT/PATCH/DELETE on `/admin*` by an actor with `adminRole`; fail-closed if ATTEMPT can't be written (`be/admin/admin-audit.interceptor.ts:55-120`). Stores eventId, actor id+role, `METHOD route-template`, `targetId` (= `:id` param only), status code, error class, client request id. No body/reason. Reads (GETs, incl. PII views) not audited.
- Pagination: `page` ≥1, `limit` default 20 max 100; response `{items,page,limit,total,totalPages}` (`admin.service.ts:917-942`).
- No global prefix: admin routes are `/admin/...`; app routes `/api/v1/...`.

### 3.2 Admin auth (`be/modules/identity/api/auth.controller.ts`)
| Method Path | Line | Throttle | Notes |
|---|---|---|---|
| POST `/api/v1/auth/admin/login` | 63 | 10/min | phone+password (role ADMIN, ACTIVE). Trusted-device cookie `aarast_admin_device` + verified phone → session directly; else WhatsApp OTP challenge (10 min) |
| POST `/api/v1/auth/admin/login/complete` | 92 | 10/min | `{challengeToken(64 hex), code(6)}` → access token, refresh cookie, trusted-device cookie (30 d, voided by password change) |
| POST `/api/v1/auth/admin/password-reset/request` | 124 | 10/min | neutral response for any phone |
| POST `/api/v1/auth/admin/password-reset/verify` | 134 | 10/min | consumes code, opens 15-min window |
| POST `/api/v1/auth/admin/password-reset/confirm` | 141 | 10/min | new password ≥6; revokes sessions |
| POST `/api/v1/auth/admin/refresh` | 148 | 30/min | rotates `aarast_admin_refresh` cookie |
| POST `/api/v1/auth/admin/logout` | 172 | – | revokes refresh, clears cookie |

### 3.3 `/admin/*` routes
Controller `be/admin/admin.controller.ts` (service `be/admin/admin.service.ts`, mutations `be/admin/admin-mutation-executor.ts`):

| # | Method Path | Line | Permission | Request | Response / side effects |
|---|---|---|---|---|---|
| 1 | GET `/admin/dashboard/stats` | 41 | DASHBOARD_READ | – | totalUsers, totalProviders, pending/approved/rejected/needsChanges/suspendedProviders, totalQuoteRequests, totalWeddingPlans, totalCities(active), totalProviderCategories (service:100-131) |
| 2 | GET `/admin/reports/success` | 48 | REPORTS_READ | – | activeUsers(7 d), costs per plan, conversion(30 d) quote→confirmed booking, visibleProviders, prices[] (≥3 providers) (service:363-412) |
| 3 | GET `/admin/reports/overview` | 54 | REPORTS_READ | `from,to` | users/providers/services/reviews/quotes/notifications/catalog/weddingPlans counts; `paymentOrDepositDataIncluded:false` (presenter) |
| 4 | GET `/admin/providers/applications` | 60 | PROVIDERS_READ | status, cityId, categoryId, search, page, limit | default PENDING/NEEDS_CHANGES/REJECTED; status aliases PENDING_REVIEW→PENDING, APPROVED→ACTIVE (service:874-883) |
| 5 | GET `/admin/providers/applications/:id` | 66 | PROVIDERS_READ | – | = #15 |
| 6 | PATCH `/admin/providers/:id/approve` | 72 | PROVIDERS_WRITE | – | →ACTIVE; promotes owner to PROVIDER role; notification to owner «تم اعتماد حساب المزوّد» (`be/admin/provider-status-notification.ts:12`) |
| 7 | PATCH `/admin/providers/:id/reject` | 81 | PROVIDERS_WRITE | `{reason?}` | →REJECTED, reviewNote=reason; HIGH notif «لم يُعتمد طلب المزوّد» (:24); revokes provider conversation access (realtime) |
| 8 | PATCH `/admin/providers/:id/request-changes` | 91 | PROVIDERS_WRITE | `{note}` required | →NEEDS_CHANGES; notif «مطلوب تعديل ملف المزوّد» body = note (:17); revokes conversations |
| 9 | PATCH `/admin/providers/:id/suspend` | 101 | PROVIDERS_WRITE | `{reason?}` | →SUSPENDED; HIGH notif «تم إيقاف حساب المزوّد» (:31); revokes conversation access. No customer notification, open quote requests/bookings not touched |
| 10 | PATCH `/admin/providers/:id/activate` | 111 | PROVIDERS_WRITE | – | SUSPENDED→ACTIVE; notif «تم اعتماد حساب المزوّد» (same as approve) |
| 11 | PATCH `/admin/providers/:id/verify` | 120 | PROVIDERS_WRITE | – | ACTIVE only (409 otherwise); sets verifiedAt/verifiedById; no notification |
| 12 | PATCH `/admin/providers/:id/unverify` | 129 | PROVIDERS_WRITE | – | clears; no notification |
| 13 | POST `/admin/providers` | 139 | PROVIDERS_WRITE | businessName, phone, whatsapp?, cityId, categoryId, description?, address? | creates ACTIVE listing with `userId=null` (claim by phone later); 409 `PROVIDER_PHONE_TAKEN` (executor:51-95) |
| 14 | GET `/admin/providers` | 148 | PROVIDERS_READ | as #4 | default ACTIVE/SUSPENDED |
| 15 | GET `/admin/providers/:id` | 154 | PROVIDERS_READ | – | full provider incl. user, reviewedBy, services+images, packages, counts, verifiedAt, isFeatured (presenter `toProviderResponse`) |
| 16 | GET `/admin/services` | 160 | SERVICES_READ | status(ACTIVE/DISABLED/INACTIVE/FEATURED), providerId, cityId, categoryId, search, page, limit | |
| 17 | POST `/admin/services` | 166 | SERVICES_WRITE | providerId, categoryId, title, description, basePrice, priceUnit, currency(YER), cityId, isActive, isFeatured | |
| 18 | PATCH `/admin/services/:id` | 175 | SERVICES_WRITE | same (providerId immutable) | |
| 19 | DELETE `/admin/services/:id` | 185 | SERVICES_WRITE | – | **soft**: isActive=false,isFeatured=false, returns `deleted:false` (executor:209-233). `api_inventory.md` calls it "Delete service" |
| 20 | GET `/admin/reviews` | 194 | REVIEWS_READ | status, providerId, search, page, limit | reviewer identity via `toReviewIdentity` |
| 21 | PATCH `/admin/reviews/:id/status` | 200 | REVIEWS_WRITE | `{status}` PUBLISHED/HIDDEN/PENDING | recomputes provider rating in tx; no notification |
| 22 | DELETE `/admin/reviews/:id` | 210 | REVIEWS_WRITE | – | = HIDDEN, `deleted:false` |
| 23 | GET `/admin/conversation-reports` | 219 | CONVERSATION_REPORTS_READ | status, page, limit | id, conversationId, reason, status, reporter{id,name,phone,avatarUrl}, conversation.provider{id,businessName}, latest quoteRequest id (`be/admin/admin-owners.ts:324-369`). No message content |
| 24 | PATCH `/admin/conversation-reports/:id/status` | 225 | CONVERSATION_REPORTS_WRITE | `{status}` OPEN/REVIEWED/DISMISSED | no notification, no note |
| 25 | GET `/admin/notifications` | 239 | NOTIFICATIONS_READ | type, priority, unreadOnly, search, page, limit | all users' notifications, privacy-redacted, phone masked |
| 26 | GET `/admin/notifications/unread-count` | 245 | NOTIFICATIONS_READ | – | `{count}` system-wide |
| 27 | PATCH `/admin/notifications/:id/read` | 251 | NOTIFICATIONS_WRITE | – | mutates the user's notification |
| 28 | PATCH `/admin/notifications/:id/archive` | 260 | NOTIFICATIONS_WRITE | – | same |
| 29 | DELETE `/admin/notifications/:id` | 269 | NOTIFICATIONS_WRITE | – | hard delete |
| 30 | GET `/admin/provider-categories` | 278 | CATALOG_READ | – | + providersCount, servicesCount |
| 31 | POST `/admin/provider-categories` | 284 | CATALOG_WRITE | nameAr, nameEn?, slug?, icon?, isActive?, showForGroom?, showForBride?, sortOrder? | active category must target ≥1 persona (executor:666-676) |
| 32 | PATCH `/admin/provider-categories/:id` | 293 | CATALOG_WRITE | same | |
| 33 | DELETE `/admin/provider-categories/:id` | 303 | CATALOG_WRITE | – | soft disable |
| 34 | GET `/admin/cities` | 312 | CATALOG_READ | – | |
| 35 | POST `/admin/cities` | 318 | CATALOG_WRITE | nameAr, nameEn?, countryCode?(YE), isActive?, sortOrder? | |
| 36 | PATCH `/admin/cities/:id` | 327 | CATALOG_WRITE | same | |
| 37 | DELETE `/admin/cities/:id` | 337 | CATALOG_WRITE | – | soft disable |
| 38 | GET `/admin/users` | 346 | USERS_READ | reuses `AdminProviderQueryDto` (status/cityId/categoryId accepted but ignored); search | SafeUser + provider summary |
| 39 | PATCH `/admin/users/:id/activate` | 352 | USERS_WRITE | – | ADMIN target needs SUPER_ADMIN actor |
| 40 | PATCH `/admin/users/:id/disable` | 361 | USERS_WRITE | – | not self; not last active SUPER_ADMIN (409); revokes invites + refresh tokens, outbox session-revoked, realtime disconnect |
| 41 | GET `/admin/users/:id` | 370 | USERS_READ | – | |
| 42 | GET `/admin/audit-logs` | audit ctrl :15 | AUDIT_READ | page, limit, action, actorUserId, phase, from, to | |

`be/catalogs/catalogs.controller.ts` (reference catalogs, versioned drafts):

| # | Method Path | Line | Permission | Request | Response / side effects |
|---|---|---|---|---|---|
| 43 | GET `/admin/reference-catalogs` | 55 | CATALOG_READ | – | seeds system catalogs; counts items/published/pending |
| 44 | GET `/admin/reference-catalogs/:catalogKey` | 61 | CATALOG_READ | – | items with revisions |
| 45 | POST `…/:catalogKey/items` | 67 | CATALOG_WRITE | key?, nameAr, nameEn?, groupKey?, groupNameAr?, groupSubtitleAr?, icon? (must be in supported set), sortOrder?, showFor{Groom,Bride,Customer,Provider}?, isRecommended?, isActive?, metadata? | draft |
| 46 | PATCH `…/:catalogKey/items/:id` | 77 | CATALOG_WRITE | same | new draft revision |
| 47 | POST `…/:catalogKey/items/:id/publish` | 88 | CATALOG_WRITE | `{revision?}` | publishes revision, bumps catalog version (clients resync) |
| 48 | DELETE `…/:catalogKey/items/:id` | 99 | CATALOG_WRITE | – | new inactive revision, published immediately |

Administrative geography (same file, `@Controller('admin')` :110):

| # | Method Path | Line | Permission | Request | Notes |
|---|---|---|---|---|---|
| 49-52 | GET/POST `/admin/governorates`, PATCH/DELETE `/admin/governorates/:id` | 115-147 | CATALOG_READ / CATALOG_WRITE | code?, nameAr, nameEn, latitude?, longitude?, isActive?, sortOrder? | DELETE = soft disable |
| 53-56 | GET/POST `/admin/governorates/:id/districts`, PATCH/DELETE `/admin/districts/:id` | 149-182 | CATALOG_R/W | + governorateId | |
| 57-60 | GET/POST `/admin/districts/:id/localities`, PATCH/DELETE `/admin/localities/:id` | 184-219 | CATALOG_R/W | + type (AREA/ISOLATION/NEIGHBORHOOD/ZONE), parentId? (same district, no cycles) | |

(Count: `admin.controller` 41 + audit 1 + reference catalogs 6 + geography 12 = **60** `/admin/*` routes.)

### 3.4 Admin role model & admin creation
- `User.role = ADMIN` + `User.adminRole: AdminRole?` (`backend/prisma/schema/identity.prisma:54`); one row can be both admin and app user (separate `app*` credentials; DECISIONS.md:243).
- Creation only via scripts, always SUPER_ADMIN:
  - dev: `npm run dev:create-admin` (`backend/scripts/dev/create-admin.cjs`, refuses production; env `DEV_ADMIN_PHONE/PASSWORD/NAME`).
  - prod: `npm run prod:provision-admin` (`backend/scripts/prod/provision-admin.cjs`; env `PROVISION_ADMIN_PHONE` Yemeni mobile, `PROVISION_ADMIN_PASSWORD`, `PROVISION_ADMIN_CONFIRM`; revokes sessions/challenges/OTPs).
- No API/UI to create OPERATIONS/MODERATOR/SUPPORT admins, change role, or list admins by role. Only guard: last active SUPER_ADMIN can't be disabled (`admin.service.ts:653-665`).

### 3.5 Side effects summary
- Notifications to users: only provider status changes #6-#10 (type GENERAL, route `/provider/dashboard`, dedupeKey per status+time) (`admin.service.ts:757-781`). Nothing on verify, review moderation, report resolution, user disable, catalog publish.
- Notifications to admins: none (no admin inbox; new applications/reports are not pushed).
- Realtime: conversation access revocation on non-ACTIVE provider; user disconnect on disable.
- Audit: every `/admin` mutation (route-level only).

---

## 4. Admin-related requirements & rules in docs

| Source | Requirement | Current state |
|---|---|---|
| V1 checklist 1.12 (`V1_DELIVERY_CHECKLIST.md:139`) | «لوحة الأدمن: اعتماد المزودين، والمستخدمين، والمراجعات، والبلاغات، والتقارير» | ⬜ in checklist; pieces exist (§2) |
| 4.11 (:216) | verified badge; admin verifies ACTIVE provider after checking documents | verify = timestamp only; no document upload/view |
| Q14 (:180) | directory shows approved provider only after ≥1 active service | admin UI hints this in 2.8 copy; no "invisible approved" indicator in lists |
| 4.18 (:223) | admin creates listing; owner claims by phone; before claim no quote requests | implemented (#13 + `POST /api/v1/provider/claim/:providerId`); no admin view of claim state |
| 4.20 (:225) | provider packages & featured visibility, manually activated by admin | ⬜; no provider-level featured endpoint/UI (field `Provider.isFeatured` exists) |
| 4.21 (:226) | success KPIs + anonymous market price report | implemented (§2.2) |
| 4.22 (:227) | CSV import | implemented (§2.9) |
| 4.12 (:217) | assistant daily limit 10 / monthly cost $30 «قابلان للتغيير» | not admin-configurable |
| 5.5 (:237) | brand «اعّرست» everywhere incl. admin | `index.html:6` «إدارة أعّرست» |
| 5.6 (:238) | one palette + Tajawal in admin; remove transitional palette later | legacy tokens still in `globals.css:49-68` |
| 6.8 (:272) | Arabic admin guide + training | `docs/handover/ADMIN_GUIDE.md` exists |
| DECISIONS.md:130 | marketplace = planning/quote leads; no deposits/settlement/payment processing | reports state `paymentOrDepositDataIncluded:false` |
| DECISIONS.md:162 | admin = password + phone OTP, server-bound sessions, admin-scoped JWT rejected by product guards | implemented |
| DECISIONS.md:264 | reference catalogs versioned, draft→publish, history = rollback; roles/permissions/finance states stay code-owned | implemented |
| DECISIONS.md:265 | Governorate/District distinct from legacy City; deletes soft-disable | implemented; legacy City still active |
| DECISIONS.md:310 | "Final admin dashboard implementation details" deferred | open |
| DECISIONS.md:341-342 | 8 admin feature owners, strict public API, no compatibility layers | enforced by `npm run architecture` |
| Provider contract `docs/superpowers/specs/2026-10-05-provider-system-product-contract.md:74,85-96` | capabilities (FIXED_VENUE, MOBILE_SERVICE, DATE_BOOKING, GUEST_COUNT_PRICING, PRODUCT_ORDER, DEPOSIT_POLICY) set by admin as per-category template with default capacity | no schema/API/UI (ProviderCategory has no capability fields, `backend/prisma/schema/catalog.prisma:137-155`) |
| same :340 | NEEDS_CHANGES notes **linked to fields**; provider edits and resubmits | single free-text note; no resubmit transition anywhere in backend (only `provider-dashboard.repository.ts:114` creates PENDING) |
| same :462, :506 | review hidden by admin decision; report → open item in admin, «سجل الإدارة فقط» | hide exists; report queue exists |
| same :554 (§8 roles) | admin: approve/suspend/review reports & reviews; **must not edit agreements or payments**; sees chat content **only in the specific report** | no agreement/payment write endpoints (compliant); chat content not shown at all (under-delivers) |
| same row 38 (:510) | suspend: hide, close open requests with notice, notify affected agreement holders «المزود موقوف — الاتفاق قائم» | suspend notifies provider only; open requests/bookings untouched |
| same §9 (:586) | admin decision notification to provider (high) | done for status; not for verify |
| same :651-653 (MVP admin) | capability templates per category; approval with field notes; reports queue; review monitoring; **provider cancellation rate** | only reports queue + review monitoring exist |
| same :680 | report must not auto-punish; block must not notify admin | compliant (no automation) |
| `docs/project/PROVIDER_JOURNEY.md:134` | «الأدمن يضبط لكل قسم: النموذج المقترح… والحقول اللي تظهر فيه» | missing |
| same :151-169 | states incl. «أرسلت التعديل», «في إجازة», resubmit after rejection | missing states |
| same :325 decision 4 | reviews publish immediately; admin hides offenders; provider replies once | admin can also set PENDING/PUBLISHED; reply not visible in admin |
| same decision 2 (:319) / screen w33 | unclaimed listing **receives requests**, each sends owner a WhatsApp claim link | conflicts with 4.18/ADMIN_GUIDE ("no quote requests before claim"); needs owner decision |
| `docs/frontend/journey-redesign/README.md:155,167` | new admin screen for approximate Sana'a prices per item (calculator depends on it) | missing |
| `AGENTS.md:13,25` | do not blindly overwrite admin approval flow; preserve Admin contracts | constraint for redesign |
| `ARCHITECTURE_CONSTITUTION.md:26 (L12), :31 (L17)` | admin boundaries strict; routes/permissions/Arabic copy must not change accidentally | constraint for redesign |
| `docs/handover/ADMIN_GUIDE.md` | says rejected provider «يستطيع التعديل وإعادة التقديم»; reports page lets you «أوقف الحساب المخالف»; audit «باسم من نفّذه» | no resubmit path; no sanction link from report; audit shows actor id, not name |

---

## 5. Gaps and problems

### 5.1 Backend capability with no UI
- `GET /admin/reports/overview?from&to` and `GET /admin/audit-logs?from&to` date ranges.
- `DELETE /admin/services/:id`; editing service title/description/price/priceUnit/city; service images (read only via provider detail payload, never rendered in services list).
- `isActive` on category/city PATCH (re-enable after «تعطيل»).
- Governorate `latitude/longitude`; reference item `nameEn`, `metadata` (task `daysBefore`), `showForCustomer` column.
- `reviewedBy`, `address`, packages list on provider detail; `ownerName` editing.
- Conversation report status OPEN (re-open).

### 5.2 UI with no/weak backend
- Applications page status filter offers ACTIVE/SUSPENDED (works, but contradicts page purpose).
- Users page `status` param (frontend type) ignored by backend; `AdminUserRecord.adminRole` typed but never returned.
- «المستندات والصور» card promises documents; backend has no document model.
- Dashboard link label «إشعارات الحساب» → page is the global system notification log.
- `getProviders(limit:20)` used as provider picker on Services and Reviews — only 20 results, ACTIVE/SUSPENDED only.

### 5.3 Missing confirmations / unsafe interactions
No confirm dialog on: user disable/enable (list and detail), service activate/deactivate/feature, review publish/pending/hide, conversation report reviewed/dismissed, notification read/archive/**delete**, reference-catalog publish and old-revision «اعتماد», CSV «استيراد», add listed provider. Reject/suspend force a note although backend makes it optional. A failed action on most pages wipes the page into «تعذر تحميل البيانات».

### 5.4 Wording / consistency
- Provider noun mixed: «مورد/الموردون» (nav, tables) vs «مزوّد/مزود» (add card, import, reports, conversation reports, server notifications).
- PENDING = «جديد» in filters vs «قيد المراجعة» in badge; DISMISSED and REJECTED both «مرفوض»; report action «رفض البلاغ».
- Dev/English leakage: «Admin API», «/admin/services», «/admin/reviews», «/admin/notifications», «/admin/reports/overview», «endpoint», «backend», «ProviderService», «Planning leads», «event {id}», «HTTP», raw `FEATURED`, raw quote statuses, raw role `PROVIDER`, raw entityType/routeTarget, raw IDs (`#XXXXXXXX`, «آخر طلب {id}», actor id).
- Topbar «مدير النظام» for every role; title «إدارة أعّرست».
- Duplicate local `formatDate` helpers with different formats.
- Users table phones unmasked while notifications mask them; SUPPORT role sees full phones.

### 5.5 Dead / odd states
- Redirect-only routes `/providers/new`, `/cities/new`, `/services/new`, `/admin`.
- «تعطيل» shown on already-disabled categories/cities; no way back.
- REQUEST_CHANGES impossible from NEEDS_CHANGES (can't revise the note); APPROVE from REJECTED skips any re-review.
- `activate` after suspension sends the same «تم اعتماد حساب المزوّد» text as first approval.
- Unread-count KPI is system-wide across all users; admin "read" actions alter users' inboxes.
- Applications KPIs and dashboard counts are independent calls; page-local KPI cards look like totals.

### 5.6 Needed by the new provider/plan journeys but absent
1. **Resubmit after NEEDS_CHANGES / REJECTED**: no provider-side transition back to PENDING, no "resubmitted" queue, no field-linked notes, no decision history (only last `reviewNote/reviewedAt`).
2. **Verification documents**: no upload model/endpoint, no viewer, no expiry; verify carries no evidence or reason; no notification.
3. **Bookings / deposits / disputes**: `Booking` model exists (`backend/prisma/schema/marketplace.prisma:274`) but admin has zero booking visibility; no deposit-confirmation disputes, «هناك مشكلة» issues (contract row 31) or cancellation-rate metric. Contract forbids admin edits of agreements/payments — read-only + report-scoped access is what's missing.
4. **Unclaimed listings**: no `claimed/unclaimed` badge/filter, no claim date, no follow-up list (listings without owner, without active service, or with customer requests waiting), no re-send claim link; journey decision conflicts with 4.18 on whether they receive requests.
5. **Category default model**: no capability template / default booking model / visible-fields config / default capacity per category (contract §3.2-3.3, PROVIDER_JOURNEY:134).
6. **Reports on reviews/providers**: only conversation reports exist; no review-report or provider-report model, no reported-message excerpt, no reported-party identity for provider→customer reports, no sanction actions linked from a report, no reporter feedback.
7. **Account deletion grace**: deletion is immediate erasure with anonymous receipt (DECISIONS.md:243); admin cannot see pending/deleted state, provider deletion with future bookings (PROVIDER_JOURNEY:158) has no admin view.
8. **Plan archive restore**: `PATCH /api/v1/wedding-plans/:id/archive` exists (`be/wedding-plans/wedding-plans.controller.ts:70`); no unarchive endpoint for users or admin.
9. **Settings**: no settings screen or table for quote/offer expiry days, tentative-hold 48 h, availability freshness 14 days, review windows, exchange rates (YER Sana'a vs Aden — PROVIDER_JOURNEY:131), assistant limits (4.12), Sana'a reference prices (journey README:155).
10. **Provider-level featured/packages (4.20)**, provider vacation state, provider profile edit by admin.
11. **Admin team management**: create/assign OPERATIONS/MODERATOR/SUPPORT, show role, admin activity by name.
12. **Admin inbox/alerts**: no notification on new application, resubmission, report.
13. **Suspension consequences**: contract requires closing open requests and notifying affected customers; backend notifies only the provider.
