# Provider path build: screen classification

Date: 2026-10-24. Read-only planning audit. No code changed.

**Scope:** every provider design screen in `mobile/test/prototype/provider/` (54 ids, list in `provider_test.dart`, PNGs in `out/`). For each screen: what it shows, what the backend gives today, and what the mobile build must drop or adapt until a backend change ships. The backend change list for the owner is `docs/superpowers/plans/2026-10-25-provider-backend-changes.md` (item numbers `B-xx` below point there).

**Legend:** ✅ buildable as designed on today's endpoints · 🔧 buildable now with mobile-side mapping, and some parts dropped or reworded · ➕ the screen's main job needs a backend change first.

**Rule for every 🔧 drop:** no invented numbers, no placeholder data, and no copy that promises a behaviour the server does not have. When a part is dropped, the space closes up. A line is never shown with a fake value.

## 0. Backend facts this file relies on (verified in source on 2026-10-24)

| # | Fact | Evidence |
|---|---|---|
| F1 | `POST /api/v1/provider/apply` creates the provider as `PENDING` at once (`businessName`, `phone`, `cityId`, `categoryIds[]`, `description`). There is no draft. A second apply returns 409. | `backend/src/provider-dashboard/provider-dashboard.service.ts` `apply`; `dto/apply-provider.dto.ts` |
| F2 | Services, packages, service images, quote requests, offers, reviews and summary all require `ACTIVE` (`findActiveOwnedProviderOrThrow` / `'OPERATIONAL'`). Before approval the provider can only edit the profile (`PATCH /provider/me/profile`, which is LIMITED for PENDING and NEEDS_CHANGES, and READ_ONLY for REJECTED and SUSPENDED). | same file; `backend/src/modules/marketplace/public/provider-access-policy.ts` |
| F3 | No endpoint moves NEEDS_CHANGES or REJECTED back to PENDING. Admin `request-changes` stores one free-text `reviewNote`. | `backend/src/admin/provider-admin-lifecycle.ts`; controllers list |
| F4 | Claiming (`POST /api/v1/provider/claim/:id`) needs a phone match and an ACTIVE unclaimed listing, and the account becomes that provider, already ACTIVE. `GET /provider/claimable` returns only `{id, businessName}`. Requests to unclaimed listings get 409 `PROVIDER_NOT_CLAIMED`. | `provider-dashboard.service.ts` `claimListing`; `backend/src/marketplace/quote-request-creation.ts:112` |
| F5 | The provider's request list (`GET /provider/me/quote-requests`) returns every status, unpaginated, with `user{id,name,phone}`, `contactName`, `contactPhone`, `budgetMin/Max`, `guestCount`, `location`, `message`, `service`, `offers[]` and `booking`. | `toQuoteResponse` in `provider-dashboard.service.ts` |
| F6 | One offer per request. Editing is in place: no version, no conversation event, no notification to the customer. `WITHDRAWN` exists in the enum and nothing writes it. Expiry is computed (`isExpired`) from `validUntil`. An expired offer is still PENDING, so it can be renewed by editing (D35). | `updateQuoteOffer`; `backend/src/marketplace/quote-offer-expiry.ts` |
| F7 | Provider decline is `PATCH /provider/me/quote-requests/:id/status {status: REJECTED}` with no reason and no message. The customer's offer rejection (`PATCH /quote-offers/:id/reject`) has no body either. | `quote-lifecycle.ts` `ALLOWED_TRANSITIONS`; `marketplace.controller.ts:278` |
| F8 | Requests never expire: there is no job and no status. The only marketplace schedulers are booking reminders and notification reminders. | `@Cron` / `@Interval` grep |
| F9 | Booking: one CONFIRMED booking per provider per day (partial unique index). No slot, no unit, no quantity. Confirm re-checks the day and returns 409 `BOOKING_DATE_UNAVAILABLE` on a race. Decline and cancel store one `note`, which overwrites the customer's request note. `COMPLETED` is derived from the date. Reminders go to both sides 7 days and 1 day before. | `backend/src/marketplace/bookings.service.ts`, `booking-policy.ts`, `booking-notifications.ts` |
| F10 | `GET /provider/me/bookings` returns REQUESTED and upcoming CONFIRMED only. Cancelled, declined and past bookings are reachable only through the request list's `booking` field (F5). This list does not check the provider status, so a SUSPENDED provider still sees it. | `marketplace-booking.repository.ts` `listProviderBookings` |
| F11 | Blocked dates are whole days. Blocking ignores pending booking requests and works for a SUSPENDED provider. | `bookings.service.ts` `blockDate` |
| F12 | Provider notifications use `routeTarget = /provider/dashboard`, but each one carries `entityId` and `data.quoteRequestId` / `data.bookingId`. Chat messages route to `/conversations/:id`. No notification exists for a new review. | `quote-notifications.ts`, `booking-notifications.ts`, `conversations.service.ts:431` |
| F13 | In PLAN-scope conversations the provider side gets `counterpart = null`. `latestQuoteRequest` carries `contactName` (D35 already falls back to it). | `conversations.service.ts:964` |
| F14 | Media purposes are only `user-avatar`, `provider-logo`, `provider-cover`, `service-image`, `chat-image`, `cost-receipt`, all images. There is no audio, no portfolio, and no verification documents. | `backend/src/media/media-upload-policy.ts` |
| F15 | Reviews: `rating`, `comment`, `status`, reviewer name. No tags, no reply, no report, no booking link. | `marketplace.prisma` `ProviderReview` |
| F16 | Public `GET /api/v1/providers/:id` returns `responsiveness{sampleSize, answeredPercent, typicalResponseHours}` (180 days, at least 3 requests, median) and always `phone`/`whatsapp`. `GET /provider/me/summary` returns 30-day `profileViews`, `quoteRequests`, `offersAccepted/Decided`, `acceptanceRate`, `upcoming/completedBookings`. | `marketplace.service.ts:216`; `provider-stats.ts` |
| F17 | Directory order is `isFeatured desc, createdAt desc`. Photos, verification and reply speed do not change visibility. | `marketplace-core.repository.ts` |
| F18 | Package `items` is free JSON, stored without validation. Services carry `priceUpdatedAt`. There is no seasonal price, no team or unit, and no coverage beyond `Provider.cityId` and `ProviderService.cityId`. Governorates and districts exist as a reference list (`GET /api/v1/governorates/:id/districts`). | `marketplace.prisma`; `marketplace.controller.ts` |
| F19 | `GET/PATCH /api/v1/users/me/settings` has `pushEnabled` and `providerMessagesEnabled`. `DELETE /api/v1/users/me` erases the provider with no upcoming-booking guard. `GET /api/v1/contexts` lists account contexts (the switch to a wedding plan). | `modules/identity/api/users.controller.ts`, `contexts.controller.ts`, `users.service.ts` |
| F20 | Chat: text and `chat-image` attachments, mute, block, report (`reason` text). The timeline carries quote events. | `conversations.controller.ts` |

## 1. Screen classification (54 screens)

| Id | Title | Shows / does | Endpoints / fields | St | Mobile must drop or adapt now | Depends on |
|---|---|---|---|---|---|---|
| p01_register | حساب مزود | name, phone, password, WhatsApp code; «نفس الرقم تقدر تسوي فيه خطة عرسك» | auth register + OTP; `GET /api/v1/contexts` | ✅ | — | — |
| p02_claim | لقينا ملف بنفس رقمك | listing card, «عندك طلبين…», «38 شافوا ملفك», claim, «مو أنا» | `GET /provider/claimable`, `POST /provider/claim/:id` (F4) | 🔧 | Drop the pending-requests line (unclaimed listings cannot receive requests) and the views line (not in `claimable`). Show the category and city only if read from the claimed profile after the claim. «مو أنا، أشتي ملف جديد» cannot work (apply returns `PROVIDER_LISTING_CLAIMABLE`): replace it with «تواصل مع الدعم». «بعد ما تستلمه تعدّل كل شيء» is true (ACTIVE right away) | B-12, B-13 |
| p03_business | نشاطك | business name, category, «يخدم مين» | collected locally and sent by `POST /provider/apply` at p07 | 🔧 | Drop «يخدم مين» and the note about «المصورين/المصورات» (no field). The wizard keeps steps locally because apply creates PENDING at once (F1) | B-10, B-14 |
| p04_where | وين تشتغل | city, districts, travel toggle, shop address | `cityId` (apply), `address` (profile PATCH after apply) | 🔧 | Keep city and address. Drop district chips and the travel toggle | B-15 |
| p05_work | وريهم شغلك | ≥3 photos, TikTok/Instagram link, women-photo rule | none before approval (F2, F14) | ➕ | Skip the step. Never say «نراجع كل صورة» (no review exists) | B-10, B-16 |
| p05b_model | كيف تشتغل؟ | three working models | none | ➕ | Skip the step | B-20 |
| p06_units | فرقك وخدماتك | teams with audience, packages | packages exist but need ACTIVE (F2); no teams | ➕ | Skip during joining. Packages are added after approval in p36 | B-10, B-20 |
| p06c_catalog | اللي تبيعه | sales catalogue with stock | none | ➕ | Not built | B-21 |
| p07_submit | كذا بيشوفك العرسان | local preview card, checklist, send | `POST /api/v1/provider/apply` | 🔧 | Preview from the entered name, category and city only. Drop the rows «6 صور» and «4 فرق وباقتين», the tags «للرجال والنساء» and «فريق مصوّرات», and the price tag. «نراجع خلال يومين عادة» has no server promise: say «نراجع طلبك ونبلغك هنا» | B-10 |
| p08_pending | طلبك قيد المراجعة | sent time, hidden until approved, can edit, preview | `GET /provider/me/profile` (`status`, `createdAt`), `PATCH /provider/me/profile` | 🔧 | «تقدر تعدّل وتضيف صور» → «تقدر تعدّل بيانات ملفك» (photos need ACTIVE). «نرد عليك خلال يومين على واتساب» → «نبلغك هنا» (only in-app notifications exist). Preview built locally | B-10 |
| p09_needs_changes | يحتاج تعديل بسيط | per-field notes, «أرسلت التعديل» | `reviewNote` (one text), profile PATCH; no resubmit (F3) | ➕ | Until B-01: show `reviewNote` as one note, keep editing, replace «أرسلت التعديل» with «تواصل مع الدعم», and do not say «نراجعه أول بأول» | B-01, B-02 |
| p10_approved | مبروك، صرت في اعّرست | three first steps | profile `status=ACTIVE`; blocked dates; `users/me/settings` | 🔧 | Drop «وثّق ملفك» (no verification request). Replace it with «أضف خدماتك وأسعارك». Remove the claims «شارة موثّق تزيد الطلبات» and «الطلب اللي يتأخر رده يقل ظهورك» (F17) | B-17 |
| p11_rejected | ما قدرنا نوافق الآن | reason, «صلّح وقدّم من جديد», support | `reviewNote`; READ_ONLY (F2) | ➕ | Until B-02: reason plus «تواصل مع الدعم» only. «مو نهاية الطريق» must not imply a path that does not exist | B-02 |
| p12_suspended | حسابك موقوف مؤقتًا | since, reason, «حجوزاتك المؤكدة مستمرة · 5 أعراس جاية», support | `reviewNote`, `reviewedAt`, `GET /provider/me/bookings` (F10) | ✅ | Count upcoming CONFIRMED only from the bookings list | — |
| p13_home | الرئيسية | waiting requests, oldest age and expiry, accepted offer to confirm, this week | quote list (F5), bookings list | 🔧 | Count = SENT and VIEWED. Drop «ينتهي بعد 6 أيام» (F8). «محمد قبل عرضك · أكّد» shows only when a booking is REQUESTED; an ACCEPTED quote with no booking reads «قبل عرضك، ينتظر يطلب الحجز». This week: date, customer name and service, without the occasion («السمرة») and team | B-04, B-19 |
| p14_home_new | ما وصلك طلب لسا | tips, weekly views | summary `profileViews` (30 days), service images | 🔧 | Views line reads «آخر 30 يوم». Drop the verify tip and the share tip (no public link, B-27). Photo tip without the «12 صورة تجيها طلبات أكثر» claim (F17) | B-17, B-27 |
| p15_requests | الطلبات | tabs جديد/ردّيت/محجوز/انتهى, card next step, time left | quote list (all statuses, F5) | 🔧 | Tabs derived on the device: new = SENT/VIEWED; replied = RESPONDED with a live offer; booked = booking CONFIRMED; ended = REJECTED/CANCELLED, expired offer, DECLINED booking. Drop «باقي 6 أيام» and the occasion label | B-04, B-19 |
| p16_request | طلب جديد | customer, date, period, place, guests, wants, message, day status, privacy line, ask | `GET /provider/me/quote-requests/:id` (sets VIEWED), bookings + blocked dates, conversation | 🔧 | Show date, place, guests, service and message. Drop the occasion and period rows. Day status reads «اليوم فاضي» or «عندك حجز مؤكد هذا اليوم» from own bookings and blocked dates (day level). Never show `contactPhone` or the budget, even though the server sends them (B-08) | B-08, B-19, B-20 |
| p16c_order | طلب جديد (بيع) | items, sizes, pickup date | none | ➕ | Not built | B-21 |
| p17_offer | عرضك لمحمد | package chips, price, currency, includes/excludes, deposit/remaining, validity | `POST /provider/me/quote-requests/:id/offers` (`title`, `message`, `amount`, `currency`, `validUntil`); `GET /provider/me/packages` | 🔧 | A package chip prefills title and price. Includes and excludes go into the free text `message`, written by the provider, not shown as structured lines. Drop the deposit and remaining fields. Validity 7/10/14 days as D35 | B-07 |
| p18_decline | تعتذر من محمد؟ | reason, «نقفل ليلة الخميس؟», message preview, send | status REJECTED; `POST /provider/me/blocked-dates`; `POST /conversations/:id/messages` | 🔧 | Reasons are local only: the message goes as a chat message sent before the REJECTED call. «نقفل الليلة؟» calls blocked-dates after the decline (day level). The reason is not stored, so it cannot feed p39 | B-05 |
| p19_offer_sent | عرضك مرسل | title, amount, «نسخة 1», «شافه محمد», valid until, edit, withdraw | offer fields, edit `PATCH /provider/me/quote-offers/:id` | 🔧 | Drop «نسخة» and «شافه». Drop «اسحب العرض» (B-03). Drop the note «التعديل يوصله نسخة 2…»: the edit is silent today (B-06), so the screen must say «التعديل يغيّر العرض نفسه» | B-03, B-06, B-09 |
| p20_ended | انتهى | expired offer + renew, chose another + reason, cancelled request, unanswered request expired | quote list: `isExpired`, REJECTED, CANCELLED; renew by edit | 🔧 | Keep the expired-offer card with «جدّد العرض» (D35). «اختار غيرك» without a reason. Keep «لغى الطلب». Drop «انتهى بدون رد» (F8) | B-04, B-11 |
| p21_confirm | محمد قبل عرضك | booking request, team choice, race note, confirm, decline | `PATCH /provider/me/bookings/:id/confirm|decline` (`note`) | 🔧 | Drop team choice. The race note is true (409 `BOOKING_DATE_UNAVAILABLE`), worded at day level | B-20 |
| p22_booking | حجز محمد الحمدي | facts, agreement version, team, deposit, remaining, delivery, reminders, chat, cancel | booking from the bookings list or the quote's `booking`; offer; cancel `{note}` | 🔧 | Agreement = the offer's title, amount and message, without «نسخة». Drop team, deposit, remaining and delivery rows. Reminder line is true (7 days and 1 day) | B-07, B-18, B-24 |
| p23_deposit | وصلتك الدفعة المقدمة؟ | customer-recorded deposit, receipt, yes/no | none | ➕ | Not built | B-18 (owner decision D-1) |
| p24_changed | محمد أجّل العرس | date change, keep/re-offer/can't | none (a plan date change does not reach bookings) | ➕ | Not built | B-24 |
| p25_cancelled | حجز فهد ملغي | who, when, reason, day freed, deposit refund | quote list `booking{status, cancelledBy, cancelledAt, note}` (F10) | 🔧 | «رجع فريق 2 فاضي» → «رجع اليوم فاضي في تقويمك». Drop the deposit section | B-18 |
| p26_after | تم العرس؟ | done / didn't happen / force majeure, delivery | `lifecycleStatus` COMPLETED derived from the date | ➕ | Until B-22: no question. A past booking shows «تم» as a passive label. Never say «نحسب الحجز تم لو ما بلّغت خلال يومين» | B-22, B-23 |
| p26c_order_done | طلب محلات الأناقة | order steps ready/collected | none | ➕ | Not built | B-21 |
| p27_review | تقييم جديد | stars, tags, text, one public reply, report | `GET /provider/me/reviews` | ➕ | Until B-09: show the review read-only inside p35. No reply box, no tags, no «بلّغ عنه» | B-09, B-28 |
| p28_month | التقويم | month with remaining per night, waiting, closed, legend, freshness | bookings list, blocked dates | 🔧 | Day states only: booked, waiting for confirmation (REQUESTED), closed, free. Hijri label computed on the device. Drop «باقي N» and the freshness note. Action row: «أقفل أيام» only (no «حجز من برا») | B-20, B-25 |
| p29_day | الخميس 21 يناير | periods × teams, outside booking, lock | same | 🔧 | A day sheet: the booking (or the request waiting) and lock/unlock. No periods or teams. Drop «حجز من برا» | B-20, B-25 |
| p30_outside | حجز من برا | outside booking with conflict check | none | ➕ | Not built | B-25 |
| p31_hold | امسك الليلة | tentative hold with auto-release | none | ➕ | Not built | B-25 |
| p32_fresh | تقويمك صحيح؟ + إجازة | weekly check, vacation | none | ➕ | Not built | B-25, B-26 |
| p33_chats | الرسائل | customer name, wedding, last message, unread, request status | `GET /api/v1/conversations` | 🔧 | Name from `latestQuoteRequest.contactName` (D35 fallback). Status tag from `latestQuoteRequest.status`. Wedding line = request date. No voice preview | B-14 |
| p34_chat | المحادثة | offer strip, bubbles, quick replies, voice | timeline, messages, `chat-image` | 🔧 | Quick replies are fixed device-side chips; «أرسل موقع المحل» uses `address` / coordinates. Drop the mic (F14) | B-29 |
| p35_me | ملفي | verified, rating, reply speed, preview, sections | profile, public `GET /providers/:id` (`responsiveness`, F16) | 🔧 | Reply-speed tag only when `responsiveness` is not null («عادة خلال N ساعات»). Gallery line without «تيك توك مربوط». Coverage = city only. Drop the unreplied-review dot. Hide «التوثيق» until B-17, or show «موثّق» when `verifiedAt` is set | B-09, B-15, B-16, B-17 |
| p36_services | خدماتك | packages with includes/extras, season price, teams, team paused | services, packages (`items` JSON, F18), `priceUpdatedAt` | 🔧 | Includes shown from `description` (or from `items` only if B-07 fixes the shape). Drop season price and the teams section | B-07, B-20 |
| p37_gallery | معرض الشغل + التغطية | albums, pending photos, women note, coverage | service images per service | 🔧 | Gallery = all service images, grouped by service. Drop the «نراجعها» tag and «كل صورة جديدة نراجعها» (images go live). Coverage = city | B-15, B-16 |
| p38_verify | التوثيق | choose method, upload, send | none (admin verify only sets `verifiedAt`) | ➕ | Not built | B-17 |
| p39_performance | أداؤك | views +%, requests, average reply, bookings + rate, why not chosen | summary (30 days), public responsiveness (180 days, median) | 🔧 | Views, requests and bookings from the summary («آخر 30 يوم»). Reply time from `typicalResponseHours`, labelled «عادة» (it is a median over 180 days). Drop «+18%» and «ليش ما اختاروك» | B-11, B-30 |
| p40_settings | الإعدادات | phone visible, women pledge, notification toggles, switch to wedding plan, staff, logout, delete | `users/me/settings` (F19), contexts, `DELETE /users/me` | 🔧 | Notifications: one toggle mapped to `pushEnabled` and one to `providerMessagesEnabled`. Drop «رقمك يظهر», «تعهّد…», «ملخص يومي» and «مين يدير الحساب». Delete warns with the upcoming-booking count from the bookings list (the server does not block) | B-31, B-32, B-33 |
| p41_claim_link | استلم ملفك من رابط واتساب | WhatsApp message about a waiting request | none (F4) | ➕ | Not built | B-12 |
| p42_notifications | التنبيهات | each notice opens its request | `GET /api/v1/notifications` (`entityId`, `data.quoteRequestId`, `data.bookingId`) | 🔧 | Route on the device from `data` (as D35 does for quotes): request → request screen, booking → booking screen. Deposit, postpone, hold and review notices do not exist; they are never shown | B-19 |
| p43_offline | بدون نت | queued offer, confirm needs network, last update | client cache; offer create guarded by `QUOTE_OFFER_ALREADY_EXISTS` (F6) | 🔧 | A queued offer is safe to replay (a second create returns 409 with `quoteOfferId`). Confirm stays online-only (true). Other writes stay online-only until B-34 | B-34 |
| p44_run_sheet | شغل الليلة | tonight's jobs, team, contact, live «في الطريق/وصلنا» | none for teams, contacts or live state | ➕ | Not built (a plain list of tonight's bookings already sits in p13) | B-35 |
| p45_quick_offer | رد سريع | pick a package, season hint, voice | packages, create offer | 🔧 | Package list → one tap creates the offer with the package title and price and a fixed message the provider can edit. Drop «آخر 5 عرسان…», the season price and voice | B-07, B-29 |
| p46_empty_nights | ليالي فاضية قريبة | pick nights, discount, reach couples | none | ➕ | Not built | B-36 |
| p47_income | حساباتك | received / owed from confirmed bookings | none | ➕ | Not built | B-18 (D-1) |
| p48_share_card | شارك ملفك | branded card, rating, verified, free nights, QR | profile, rating, `verifiedAt` | 🔧 | Share an image card (name, category, city, rating if `ratingCount > 0`, «موثّق» if `verifiedAt`) with the app's name in text. Drop the QR, the link and «ليالي فاضية: 9» | B-27 |
| p49_staff | فريق العمل | staff with scoped access | none | ➕ | Not built | B-37 |
| p50_deliver | التسليم | delivery promise, checklist, link, customer confirms | none | ➕ | Not built | B-23 |

**Counts:** ✅ 2 (p01, p12) · 🔧 30 · ➕ 22. Total 54.

Copy rules that apply across the 🔧 screens (all verified):
- The provider sees the customer's phone and budget in the payload (F5). The app never shows them. This is the only honest way to keep p16's line «ميزانيته ورقمه ما يوصلونك إلا إذا شاركهم» until B-08 ships. Until then, the line is dropped: it describes the data, and the data says otherwise.
- No visibility promises (F17).
- Dates and slots are day-level (F9).
- One noun for the provider: «مزود» (the design's spelling), never «مورد» or «مزوّد». The server's own copy still mixes them (B-38).

## 2. Build order (slices)

Slices 1 to 4 need no backend change. Slices 5 to 8 wait for the backend items named.

| Slice | Screens | Why together | Backend gate |
|---|---|---|---|
| 1. الحساب والانضمام | p01, p02, p03, p04, p07, p08, p10, p12 (8) | Account, claim, the 3-step joining wizard (activity, where, review and send), and the three states that are already truthful | none |
| 2. الطلب والعرض | p13, p15, p16, p17, p18, p19, p20, p45 (8) | One case card from request to offer, home's «ينتظرونك», quick offer | none |
| 3. الحجز والتقويم والتنبيهات | p21, p22, p25, p28, p29, p42, p43 (7) | Confirm, booked, cancelled, day-level calendar, notices that open their case, offline states | none |
| 4. الرسائل وملفي | p33, p34, p35, p36, p37, p39, p40, p14, p48 (9) | Chats, profile, services, gallery, performance, settings, empty home, share card | none |
| 5. دورة الحساب كاملة | p09, p11, p05, p05b, p06, p38 (6) | Resubmit and re-apply, then the joining steps that need writes before approval | B-01, B-02, B-10 (P0/P1), then B-16, B-20, B-17 |
| 6. بعد الحجز | p26, p27, p24, p50, p23, p47 (6) | Done / didn't happen, review reply, date changes, delivery, deposits | B-09, B-22, B-23, B-24; p23 and p47 only after decision D-1 and B-18 |
| 7. التقويم بالسعة | p30, p31, p32, p44, p46 (5) | Outside bookings, holds, freshness and vacation, run sheet, empty nights | B-20, B-25, B-26, then B-35, B-36 |
| 8. البيع والدليل والفريق | p06c, p16c, p26c, p41, p49 (5) | Sales model, WhatsApp claim link, staff | B-21, B-12, B-37 |

When a backend item ships, the dropped parts in slices 1 to 4 come back in place (each row's "Depends on" column). Examples: B-03 restores «اسحب العرض» in p19, and B-04 restores the time-left lines in p13, p15 and p20.

## 3. Conflicts and decisions for the owner

| # | Decision | Why it is open |
|---|---|---|
| D-1 | Deposits: record and acknowledge (p22, p23, p25, p47), or leave them out of V1? | `docs/project/DECISIONS.md` rows at lines 293 and 295 exclude deposits from the MVP. The row at line 398 allows tracking money the user moves. PJ §8.1 wants a recorded and acknowledged deposit. |
| D-2 | Capacity model (teams, halls, periods, «باقي N») for V1, or keep one booking per day? | The design assumes it everywhere (p06, p21, p28, p29, p30, p44). It replaces the day-level unique index (F9) and is the biggest backend change. |
| D-3 | Joining: a draft that collects services and photos before review (p05, p06), or apply first and add services after approval? | Today apply is immediate (F1) and services need ACTIVE (F2). |
| D-4 | Claimed listings: keep «claim = active at once» (F4), or send them to review? Should unclaimed listings accept requests and send a WhatsApp claim link (p41)? | The design (p02, p41) and the backend disagree. |
| D-5 | Offer edits: versions with «ايش تغيّر» (p19, p22), or in-place edits plus a notice to the customer? | B-06 is the minimum either way: today the edit is silent. |
| D-6 | V1 or later: live «في الطريق/وصلنا» (p44), staff logins (p49), empty-nights promotion (p46), voice notes (p34, p45), sales model (p06c, p16c, p26c). | Each is a new backend area. |
