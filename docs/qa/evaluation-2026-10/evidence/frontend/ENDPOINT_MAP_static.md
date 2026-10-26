# خريطة الـEndpoints (مولّدة من الكود)

- مكالمات الجوال للخادم: 152 (9 مسارها يُبنى وقت التشغيل)
- مسارات الخادم: 287
- مكالمات بدون مسار مطابق في الخادم: 3
- مسارات خادم ما يستخدمها الجوال ولا الإدارة: 89

## مكالمات بدون مسار مطابق في الخادم

| الميزة | الطريقة | المسار | المكان |
|---|---|---|---|
| catalogs | GET | `/api/v1/catalogs/bootstrap:p` | `features/catalogs/data/reference_catalog_api.dart:26` |
| chat | GET | `/api/v1/conversations:p` | `features/chat/data/chat_api.dart:15` |
| chat | GET | `/api/v1/conversations/:p/timeline:p` | `features/chat/data/chat_api.dart:40` |

## مسارات الخادم اللي ما يناديها أحد

| الطريقة | المسار |
|---|---|
| GET | `/admin/audit-logs` |
| GET | `/admin/bookings` |
| GET | `/admin/conversation-reports` |
| GET | `/admin/featured-periods` |
| GET | `/admin/provider-claims` |
| PATCH | `/admin/providers/:p/unverify` |
| PATCH | `/admin/providers/:p/verify` |
| GET | `/admin/providers/applications` |
| GET | `/admin/reports/overview` |
| GET | `/admin/reviews` |
| GET | `/admin/users` |
| POST | `/api/v1/auth/admin/refresh` |
| POST | `/api/v1/auth/logout-all` |
| DELETE | `/api/v1/budget-categories/:p` |
| PATCH | `/api/v1/budget-categories/:p` |
| GET | `/api/v1/catalogs/bootstrap` |
| GET | `/api/v1/cities` |
| GET | `/api/v1/conversations` |
| GET | `/api/v1/conversations/:p/messages` |
| GET | `/api/v1/conversations/:p/timeline` |
| POST | `/api/v1/cost-payments/:p/reverse` |
| DELETE | `/api/v1/costs/:p` |
| PATCH | `/api/v1/costs/:p` |
| POST | `/api/v1/costs/:p/cancel` |
| GET | `/api/v1/costs/:p/payment-schedules` |
| POST | `/api/v1/costs/:p/payment-schedules` |
| POST | `/api/v1/costs/:p/payments` |
| GET | `/api/v1/dashboard/home` |
| GET | `/api/v1/districts/:p/localities` |
| GET | `/api/v1/governorates` |
| GET | `/api/v1/governorates/:p/districts` |
| GET | `/api/v1/guests/:p` |
| GET | `/api/v1/invites/mine` |
| GET | `/api/v1/me` |
| GET | `/api/v1/me/favorite-providers` |
| GET | `/api/v1/me/quote-requests` |
| GET | `/api/v1/me/quote-requests/:p` |
| PATCH | `/api/v1/me/quote-requests/:p/cancel` |
| GET | `/api/v1/notifications` |
| GET | `/api/v1/notifications/:p` |
| PATCH | `/api/v1/notifications/read-all` |
| GET | `/api/v1/notifications/unread-count` |
| DELETE | `/api/v1/payment-schedules/:p` |
| PATCH | `/api/v1/payment-schedules/:p` |
| POST | `/api/v1/payment-schedules/:p/cancel` |
| POST | `/api/v1/payment-schedules/:p/pay` |
| GET | `/api/v1/provider-categories` |
| PATCH | `/api/v1/provider/me/bookings/:p/cancel` |
| PATCH | `/api/v1/provider/me/bookings/:p/decline` |
| DELETE | `/api/v1/provider/me/packages/:p` |
| GET | `/api/v1/provider/me/quote-requests/:p` |
| DELETE | `/api/v1/provider/me/services/:p` |
| GET | `/api/v1/provider/me/services/:p` |
| PATCH | `/api/v1/provider/me/services/:p/images/:p` |
| GET | `/api/v1/providers` |
| GET | `/api/v1/providers/:p/packages` |
| POST | `/api/v1/providers/:p/quote-requests` |
| GET | `/api/v1/providers/:p/reviews` |
| GET | `/api/v1/providers/:p/services` |
| GET | `/api/v1/public/rsvp/:p` |
| POST | `/api/v1/public/rsvp/:p` |
| DELETE | `/api/v1/push/installations/current` |
| DELETE | `/api/v1/reviews/:p` |
| PATCH | `/api/v1/reviews/:p` |
| GET | `/api/v1/services` |
| GET | `/api/v1/services/:p` |
| GET | `/api/v1/shared/wedding-plans` |
| GET | `/api/v1/tasks/:p` |
| GET | `/api/v1/users/lookup` |
| DELETE | `/api/v1/users/me` |
| GET | `/api/v1/wedding-plans` |
| GET | `/api/v1/wedding-plans/:p/budget-categories` |
| POST | `/api/v1/wedding-plans/:p/budget-categories` |
| GET | `/api/v1/wedding-plans/:p/contributions` |
| GET | `/api/v1/wedding-plans/:p/contributions/summary` |
| GET | `/api/v1/wedding-plans/:p/cost-payments` |
| GET | `/api/v1/wedding-plans/:p/costs` |
| POST | `/api/v1/wedding-plans/:p/costs` |
| GET | `/api/v1/wedding-plans/:p/invites` |
| POST | `/api/v1/wedding-plans/:p/mahr` |
| GET | `/api/v1/wedding-plans/:p/members` |
| DELETE | `/api/v1/wedding-plans/:p/members/me` |
| PUT | `/api/v1/wedding-plans/:p/money-budget` |
| GET | `/api/v1/wedding-plans/:p/payment-schedules/due` |
| GET | `/api/v1/wedding-plans/:p/quote-requests` |
| POST | `/api/v1/wedding-plans/:p/quote-requests` |
| GET | `/api/v1/wedding-plans/:p/tasks` |
| GET | `/api/v1/wedding-plans/active` |
| GET | `/api/v1/wedding-plans/my` |

## كل ميزة وش تنادي

### account_contexts

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| GET | `/api/v1/contexts` | ✅ | `features/account_contexts/data/account_contexts_api.dart:21` |
| POST | `/api/v1/contexts/validate` | ✅ | `features/account_contexts/data/account_contexts_api.dart:43` |

### auth

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| POST | `/api/v1/account-deletions/status` | ✅ | `features/auth/data/auth_repository.dart:412` |
| POST | `/api/v1/auth/login` | ✅ | `features/auth/data/auth_repository.dart:39` |
| POST | `/api/v1/auth/logout` | ✅ | `features/auth/data/auth_repository.dart:471` |
| GET | `/api/v1/auth/me` | ✅ | `features/auth/data/auth_repository.dart:102` |
| POST | `/api/v1/auth/otp/request` | ✅ | `features/auth/data/auth_repository.dart:113` |
| POST | `/api/v1/auth/otp/verify` | ✅ | `features/auth/data/auth_repository.dart:168` |
| POST | `/api/v1/auth/password-reset/confirm` | ✅ | `features/auth/data/auth_repository.dart:272` |
| POST | `/api/v1/auth/password-reset/request` | ✅ | `features/auth/data/auth_repository.dart:256` |
| POST | `/api/v1/auth/phone-change/confirm` | ✅ | `features/auth/data/auth_repository.dart:133` |
| POST | `/api/v1/auth/phone-change/request` | ✅ | `features/auth/data/auth_repository.dart:123` |
| POST | `/api/v1/auth/refresh` | ✅ | `features/auth/data/auth_repository.dart:293` |
| POST | `/api/v1/auth/register` | ✅ | `features/auth/data/auth_repository.dart:63` |
| POST | `/api/v1/auth/register/complete` | ✅ | `features/auth/data/auth_repository.dart:80` |
| POST | `/api/v1/invites/:p/request-otp` | ✅ | `features/auth/data/auth_repository.dart:144` |
| POST | `/api/v1/invites/:p/verify-otp` | ✅ | `features/auth/data/auth_repository.dart:221` |
| POST | `/api/v1/media/uploads/presign` | ✅ | `features/auth/data/auth_repository.dart:351` |
| POST | `/api/v1/media/uploads/verify` | ✅ | `features/auth/data/auth_repository.dart:363` |
| PATCH | `/api/v1/users/me` | ✅ | `features/auth/data/auth_repository.dart:372` |

### catalogs

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| GET | `/api/v1/catalogs/bootstrap:p` | ❌ | `features/catalogs/data/reference_catalog_api.dart:26` |

### chat

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| GET | `/api/v1/conversations/:p` | ✅ | `features/chat/data/chat_api.dart:28` |
| GET | `/api/v1/conversations/:p/attachments/:p/download` | ✅ | `features/chat/data/chat_api.dart:82` |
| PATCH | `/api/v1/conversations/:p/block` | ✅ | `features/chat/data/chat_api.dart:102` |
| POST | `/api/v1/conversations/:p/messages` | ✅ | `features/chat/data/chat_api.dart:59` |
| PATCH | `/api/v1/conversations/:p/mute` | ✅ | `features/chat/data/chat_api.dart:96` |
| GET | `/api/v1/conversations/:p/quote-requests` | ✅ | `features/chat/data/chat_api.dart:48` |
| PATCH | `/api/v1/conversations/:p/read` | ✅ | `features/chat/data/chat_api.dart:89` |
| POST | `/api/v1/conversations/:p/report` | ✅ | `features/chat/data/chat_api.dart:108` |
| GET | `/api/v1/conversations/:p/timeline:p` | ❌ | `features/chat/data/chat_api.dart:40` |
| GET | `/api/v1/conversations:p` | ❌ | `features/chat/data/chat_api.dart:15` |
| GET | `/api/v1/quote-requests/:p/conversation` | ✅ | `features/chat/data/chat_api.dart:20` |

### core/media

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| POST | `/api/v1/media/uploads/presign` | ✅ | `core/media/media_upload_api.dart:52` |
| POST | `/api/v1/media/uploads/verify` | ✅ | `core/media/media_upload_api.dart:73` |

### core/offline

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| GET | `/api/v1/costs/:p/payments` | ✅ | `core/offline/offline_sync_service.dart:734` |

### core/push

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| PUT | `/api/v1/push/installations/current` | ✅ | `core/push/push_registration_api.dart:24` |

### finance

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| GET | `/api/v1/cost-payments/:p` | ✅ | `features/finance/data/finance_api.payments.dart:71` |
| GET | `/api/v1/costs/:p` | ✅ | `features/finance/data/finance_api.costs.dart:95` |
| GET | `/api/v1/costs/:p/receipts` | ✅ | `features/finance/data/cost_receipts_api.dart:13` |
| POST | `/api/v1/costs/:p/receipts` | ✅ | `features/finance/data/cost_receipts_api.dart:26` |
| DELETE | `/api/v1/costs/:p/receipts/:p` | ✅ | `features/finance/data/cost_receipts_api.dart:34` |
| DELETE | `/api/v1/funding-sources/:p` | ✅ | `features/finance/data/funding_api.dart:95` |
| PATCH | `/api/v1/funding-sources/:p` | ✅ | `features/finance/data/funding_api.dart:81` |
| POST | `/api/v1/funding-sources/:p/repayments` | ✅ | `features/finance/data/funding_api.dart:104` |
| DELETE | `/api/v1/loan-repayments/:p` | ✅ | `features/finance/data/funding_api.dart:124` |
| PATCH | `/api/v1/loan-repayments/:p` | ✅ | `features/finance/data/funding_api.dart:116` |
| GET | `/api/v1/wedding-plans/:p/funding-sources` | ✅ | `features/finance/data/funding_api.dart:22` |
| POST | `/api/v1/wedding-plans/:p/funding-sources` | ✅ | `features/finance/data/funding_api.dart:58` |
| GET | `/api/v1/wedding-plans/:p/money-summary` | ✅ | `features/finance/data/finance_api.dart:54` |

### guests

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| DELETE | `/api/v1/guest-groups/:p` | ✅ | `features/guests/data/guests_api.dart:134` |
| PATCH | `/api/v1/guest-groups/:p` | ✅ | `features/guests/data/guests_api.dart:125` |
| DELETE | `/api/v1/guests/:p` | ✅ | `features/guests/data/guests_api.dart:297` |
| PATCH | `/api/v1/guests/:p` | ✅ | `features/guests/data/guests_api.dart:284` |
| POST | `/api/v1/guests/:p/invitation-link` | ✅ | `features/guests/data/guests_api.dart:308` |
| GET | `/api/v1/wedding-plans/:p/guest-groups` | ✅ | `features/guests/data/guests_api.dart:75` |
| POST | `/api/v1/wedding-plans/:p/guest-groups` | ✅ | `features/guests/data/guests_api.dart:117` |
| GET | `/api/v1/wedding-plans/:p/guests` | ✅ | `features/guests/data/guests_api.dart:25` |
| POST | `/api/v1/wedding-plans/:p/guests` | ✅ | `features/guests/data/guests_api.dart:178` |
| POST | `/api/v1/wedding-plans/:p/guests/bulk` | ✅ | `features/guests/data/guests_api.dart:225` |
| GET | `/api/v1/wedding-plans/:p/guests/summary` | ✅ | `features/guests/data/guests_api.dart:58` |

### marketplace

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| PATCH | `/api/v1/me/bookings/:p/cancel` | ✅ | `features/marketplace/data/marketplace_api.dart:541` |
| POST | `/api/v1/me/quote-requests/:p/booking` | ✅ | `features/marketplace/data/marketplace_api.dart:518` |
| POST | `/api/v1/provider/apply` | ✅ | `features/marketplace/data/marketplace_api.dart:875` |
| POST | `/api/v1/provider/claim/:p` | ✅ | `features/marketplace/data/marketplace_api.dart:697` |
| GET | `/api/v1/provider/claimable` | ✅ | `features/marketplace/data/marketplace_api.dart:687` |
| POST | `/api/v1/provider/me/application/reopen` | ✅ | `features/marketplace/data/marketplace_api.dart:727` |
| POST | `/api/v1/provider/me/application/resubmit` | ✅ | `features/marketplace/data/marketplace_api.dart:718` |
| GET | `/api/v1/provider/me/blocked-dates` | ✅ | `features/marketplace/data/marketplace_api.dart:813` |
| POST | `/api/v1/provider/me/blocked-dates` | ✅ | `features/marketplace/data/marketplace_api.dart:821` |
| DELETE | `/api/v1/provider/me/blocked-dates/:p` | ✅ | `features/marketplace/data/marketplace_api.dart:827` |
| GET | `/api/v1/provider/me/bookings` | ✅ | `features/marketplace/data/marketplace_api.dart:789` |
| PATCH | `/api/v1/provider/me/bookings/:p/:p` | ✅ | `features/marketplace/data/marketplace_api.dart:805` |
| GET | `/api/v1/provider/me/claim` | ✅ | `features/marketplace/data/marketplace_api.dart:706` |
| GET | `/api/v1/provider/me/ledger` | ✅ | `features/marketplace/data/marketplace_api.dart:932` |
| GET | `/api/v1/provider/me/packages` | ✅ | `features/marketplace/data/marketplace_api.dart:833` |
| POST | `/api/v1/provider/me/packages` | ✅ | `features/marketplace/data/marketplace_api.dart:1046` |
| PATCH | `/api/v1/provider/me/packages/:p` | ✅ | `features/marketplace/data/marketplace_api.dart:1079` |
| GET | `/api/v1/provider/me/profile` | ✅ | `features/marketplace/data/marketplace_api.dart:746` |
| PATCH | `/api/v1/provider/me/profile` | ✅ | `features/marketplace/data/marketplace_api.dart:941` |
| PATCH | `/api/v1/provider/me/profile` | ✅ | `features/marketplace/data/marketplace_api.dart:739` |
| PATCH | `/api/v1/provider/me/profile` | ✅ | `features/marketplace/data/marketplace_api.dart:905` |
| PATCH | `/api/v1/provider/me/profile` | ✅ | `features/marketplace/data/marketplace_api.dart:957` |
| PATCH | `/api/v1/provider/me/profile` | ✅ | `features/marketplace/data/marketplace_api.dart:920` |
| PATCH | `/api/v1/provider/me/quote-offers/:p` | ✅ | `features/marketplace/data/marketplace_api.dart:1127` |
| POST | `/api/v1/provider/me/quote-offers/:p/withdraw` | ✅ | `features/marketplace/data/marketplace_api.dart:1144` |
| GET | `/api/v1/provider/me/quote-requests` | ✅ | `features/marketplace/data/marketplace_api.dart:778` |
| POST | `/api/v1/provider/me/quote-requests/:p/offers` | ✅ | `features/marketplace/data/marketplace_api.dart:1106` |
| PATCH | `/api/v1/provider/me/quote-requests/:p/status` | ✅ | `features/marketplace/data/marketplace_api.dart:1090` |
| GET | `/api/v1/provider/me/reviews` | ✅ | `features/marketplace/data/marketplace_api.dart:855` |
| POST | `/api/v1/provider/me/reviews/:p/reply` | ✅ | `features/marketplace/data/marketplace_api.dart:847` |
| GET | `/api/v1/provider/me/services` | ✅ | `features/marketplace/data/marketplace_api.dart:767` |
| POST | `/api/v1/provider/me/services` | ✅ | `features/marketplace/data/marketplace_api.dart:998` |
| PATCH | `/api/v1/provider/me/services/:p` | ✅ | `features/marketplace/data/marketplace_api.dart:1031` |
| POST | `/api/v1/provider/me/services/:p/images` | ✅ | `features/marketplace/data/marketplace_api.dart:972` |
| DELETE | `/api/v1/provider/me/services/:p/images/:p` | ✅ | `features/marketplace/data/marketplace_api.dart:984` |
| GET | `/api/v1/provider/me/summary` | ✅ | `features/marketplace/data/marketplace_api.dart:751` |
| GET | `/api/v1/providers/:p` | ✅ | `features/marketplace/data/marketplace_api.dart:158` |
| GET | `/api/v1/providers/:p` | ✅ | `features/marketplace/data/marketplace_api.dart:759` |
| DELETE | `/api/v1/providers/:p/favorite` | ✅ | `features/marketplace/data/marketplace_api.dart:328` |
| POST | `/api/v1/providers/:p/favorite` | ✅ | `features/marketplace/data/marketplace_api.dart:304` |
| POST | `/api/v1/providers/:p/reviews` | ✅ | `features/marketplace/data/marketplace_api.dart:530` |
| POST | `/api/v1/providers/:p/views` | ✅ | `features/marketplace/data/marketplace_api.dart:299` |
| PATCH | `/api/v1/quote-offers/:p/accept` | ✅ | `features/marketplace/data/marketplace_api.dart:493` |
| PATCH | `/api/v1/quote-offers/:p/reject` | ✅ | `features/marketplace/data/marketplace_api.dart:504` |
| GET | `/api/v1/quote-requests/:p` | ✅ | `features/marketplace/data/marketplace_api.dart:464` |
| PATCH | `/api/v1/quote-requests/:p/cancel` | ✅ | `features/marketplace/data/marketplace_api.dart:475` |

### notifications

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| DELETE | `/api/v1/notifications/:p` | ✅ | `features/notifications/data/notifications_api.dart:62` |
| PATCH | `/api/v1/notifications/:p/archive` | ✅ | `features/notifications/data/notifications_api.dart:66` |
| PATCH | `/api/v1/notifications/:p/read` | ✅ | `features/notifications/data/notifications_api.dart:46` |

### settings

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| GET | `/api/v1/users/me/settings` | ✅ | `features/settings/data/settings_api.dart:10` |
| PATCH | `/api/v1/users/me/settings` | ✅ | `features/settings/data/settings_api.dart:15` |

### sharing

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| GET | `/api/v1/invites/:p` | ✅ | `features/sharing/data/sharing_api.dart:162` |
| POST | `/api/v1/invites/:p/accept` | ✅ | `features/sharing/data/sharing_api.dart:172` |
| POST | `/api/v1/invites/:p/decline` | ✅ | `features/sharing/data/sharing_api.dart:202` |
| POST | `/api/v1/wedding-plans/:p/invites` | ✅ | `features/sharing/data/sharing_api.dart:105` |
| DELETE | `/api/v1/wedding-plans/:p/invites/:p` | ✅ | `features/sharing/data/sharing_api.dart:126` |
| POST | `/api/v1/wedding-plans/:p/invites/:p/reissue` | ✅ | `features/sharing/data/sharing_api.dart:144` |
| POST | `/api/v1/wedding-plans/:p/members` | ✅ | `features/sharing/data/sharing_api.dart:74` |
| DELETE | `/api/v1/wedding-plans/:p/members/:p` | ✅ | `features/sharing/data/sharing_api.dart:222` |
| PATCH | `/api/v1/wedding-plans/:p/members/:p` | ✅ | `features/sharing/data/sharing_api.dart:214` |
| GET | `/api/v1/wedding-plans/:p/permissions/me` | ✅ | `features/sharing/data/sharing_api.dart:23` |

### tasks

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| DELETE | `/api/v1/tasks/:p` | ✅ | `features/tasks/data/task_timeline_api.dart:328` |
| PATCH | `/api/v1/tasks/:p` | ✅ | `features/tasks/data/task_timeline_api.dart:272` |
| PATCH | `/api/v1/tasks/:p/assign` | ✅ | `features/tasks/data/task_timeline_api.dart:249` |
| POST | `/api/v1/tasks/:p/checklist` | ✅ | `features/tasks/data/task_timeline_api.dart:689` |
| DELETE | `/api/v1/tasks/:p/checklist/:p` | ✅ | `features/tasks/data/task_timeline_api.dart:722` |
| PATCH | `/api/v1/tasks/:p/checklist/:p` | ✅ | `features/tasks/data/task_timeline_api.dart:705` |
| POST | `/api/v1/wedding-plans/:p/tasks` | ✅ | `features/tasks/data/task_timeline_api.dart:164` |
| POST | `/api/v1/wedding-plans/:p/tasks/shift-due-dates` | ✅ | `features/tasks/data/task_timeline_api.dart:84` |
| GET | `/api/v1/wedding-plans/:p/tasks/summary` | ✅ | `features/tasks/data/task_timeline_api.dart:98` |
| GET | `/api/v1/wedding-plans/:p/timeline` | ✅ | `features/tasks/data/task_timeline_api.dart:62` |

### wedding_plans

| الطريقة | المسار | موجود؟ | المكان |
|---|---|---|---|
| GET | `/api/v1/me/wedding-plans/:p/bookings` | ✅ | `features/wedding_plans/data/plan_bookings_lookup.dart:42` |
| POST | `/api/v1/onboarding/complete` | ✅ | `features/wedding_plans/data/wedding_plans_api.dart:30` |
| POST | `/api/v1/onboarding/import-local` | ✅ | `features/wedding_plans/data/wedding_plans_api.dart:44` |
| POST | `/api/v1/wedding-plans` | ✅ | `features/wedding_plans/data/wedding_plans_api.dart:177` |
| GET | `/api/v1/wedding-plans/:p` | ✅ | `features/wedding_plans/data/wedding_plans_api.dart:140` |
| PATCH | `/api/v1/wedding-plans/:p` | ✅ | `features/wedding_plans/data/wedding_plans_api.dart:237` |
| PATCH | `/api/v1/wedding-plans/:p/archive` | ✅ | `features/wedding_plans/data/wedding_plans_api.dart:279` |
| GET | `/api/v1/wedding-plans/:p/assistant` | ✅ | `features/wedding_plans/data/plan_assistant_api.dart:15` |
| POST | `/api/v1/wedding-plans/:p/assistant/questions` | ✅ | `features/wedding_plans/data/plan_assistant_api.dart:27` |
| GET | `/api/v1/wedding-plans/:p/dashboard-summary` | ✅ | `features/wedding_plans/data/wedding_plans_api.dart:99` |
| GET | `/api/v1/wedding-plans/:p/plan-view` | ✅ | `features/wedding_plans/data/wedding_plans_api.dart:91` |
| POST | `/api/v1/wedding-plans/:p/set-active` | ✅ | `features/wedding_plans/data/wedding_plans_api.dart:223` |

## مكالمات مسارها متغيّر (تنراجع يدويًا)

| الميزة | الطريقة | المكان | التعبير |
|---|---|---|---|
| marketplace | GET | `features/marketplace/data/marketplace_api.dart:550` | `path` |
| tasks | GET | `features/tasks/data/task_timeline_api.dart:358` | `path` |
| finance | GET | `features/finance/data/finance_api.costs.dart:40` | `path` |
| finance | GET | `features/finance/data/finance_api.payments.dart:24` | `path` |
| finance | GET | `features/finance/data/finance_api.dart:116` | `path` |
| finance | GET | `features/finance/data/finance_api.dart:123` | `path` |
| wedding_plans | GET | `features/wedding_plans/data/wedding_plans_api.dart:294` | `path` |
| onboarding | GET | `features/onboarding/data/yemen_administrative_api.dart:91` | `path` |
| sharing | GET | `features/sharing/data/sharing_api.dart:297` | `path` |
