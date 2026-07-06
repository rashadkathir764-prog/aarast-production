# Aarast Auth & Guest Strategy

Date: 2026-06-19
Stage: Auth & Guest Strategy
Status: Planning document only

## 1. Decision

Aarast mobile must be guest-first for wedding planning and account-gated for server-owned, collaborative, provider, and sensitive long-term actions.

The app must not require login on first launch for a wedding user. Login/register appears when the user asks to do something that needs identity, ownership, another participant, cloud sync, or provider communication.

## 2. Current State

Current mobile has:

- `SplashScreen` restoring session.
- `OnboardingScreen` that leads to registration.
- `LoginScreen`.
- `RegisterScreen`, including provider mode through `?type=provider`.
- `OtpScreen`.
- Auth token storage through `AuthStorage`.
- Backend auth/register/login/me plus OTP/profile flows.

Current product gap:

- First-time wedding users are pushed toward account creation before building a plan.
- Provider and wedding-user registration are mixed in the same screen.
- Guest local plan migration is not yet defined.

## 3. Guest Capabilities

Guest can:

- Start onboarding.
- Choose wedding-user path.
- Select persona.
- Enter location.
- Select wedding date or skip date.
- Select priorities.
- Enter or skip budget.
- Select suggested categories.
- Create local generated plan.
- View generated dashboard.
- Add local starter categories/tasks/guest/expense drafts if Offline & Sync Plan approves.
- Browse public/cached providers.

Guest cannot complete:

- Cloud sync.
- Share plan.
- Invite members.
- Send quote request.
- Accept quote/offer.
- Receive server notifications.
- Manage provider profile.
- Save long-term sensitive server financial records.
- Use provider dashboard.

## 4. Account Gate Triggers

Show auth gate only for these actions:

| Action | Reason shown to user | Resume after auth |
|---|---|---|
| Send quote request | "نحتاج حساباً لإرسال طلبك للمورد ومتابعة الرد." | Return to quote form and submit/confirm. |
| Share plan | "المشاركة تحتاج حساباً حتى نحفظ الصلاحيات بأمان." | Return to sharing screen. |
| Add member | "إضافة عضو تحتاج حساباً وخطة محفوظة." | Return to add member. |
| Enable cloud sync | "المزامنة تحفظ خطتك على حسابك." | Start guest migration then sync. |
| Enable notifications | "التذكيرات تحتاج حساباً حتى تصل إليك بأمان." | Return to notification settings. |
| Accept provider offer | "قبول العرض يحتاج ربطه بخطتك المحفوظة." | Return to offer detail. |
| Open account settings | "الإعدادات مرتبطة بحسابك." | Open settings. |
| Provider apply/dashboard | "مسار المزود يحتاج حساب مزود." | Return to provider apply/dashboard. |

Rules:

- Auth gate must include login and signup choices.
- Auth gate must preserve intended route/action.
- Auth gate must not delete guest local data.
- Auth gate copy must be short and specific.

## 5. Guest Plan Migration

Migration goal:

Move local guest plan data into authenticated server-owned records without data loss.

Recommended migration steps:

1. User completes login/register.
2. Mobile checks for local guest plan.
3. Mobile creates server `WeddingPlan`.
4. Mobile creates selected `BudgetCategory` records.
5. Mobile creates approved local starter tasks if task templates exist.
6. Mobile maps local IDs to server IDs.
7. Mobile marks migrated records as synced.
8. Mobile resumes the original gated action.

Failure behavior:

- If migration partially fails, keep local data and show a retry action.
- Do not claim cloud save succeeded until server calls succeed.
- Do not remove local data until migration completion is confirmed.

## 6. Auth Route Strategy

Required auth routes:

- Login.
- Register user.
- Register provider or provider apply auth gate.
- OTP verify where needed.
- Auth gate wrapper with reason and resume target.

Recommended route parameters:

```text
/login?resume=<encoded_target>&reason=quote_request
/register?resume=<encoded_target>&reason=share_plan
/provider/register?resume=<encoded_target>
```

Implementation note:

- Existing `/register?type=provider` can be preserved temporarily with redirect compatibility.
- Final provider registration should move under provider path after provider navigation is implemented.

## 7. Security Rules

- Password hash never leaves backend.
- Tokens stay in current secure/local storage approach until a security plan changes it.
- Guest local data must be treated as private device data.
- Shared financial data remains hidden unless permissions explicitly allow it.
- Provider sees only submitted quote fields.
- Unknown phone numbers are not auto-created when sharing.
- Account gate must not leak private route data in URLs beyond safe resume identifiers.

## 8. Offline Rules

Guest-first depends on offline/local behavior.

Allowed offline:

- Guest onboarding.
- Local generated plan.
- Cached dashboard.
- Local drafts if approved by Offline & Sync Plan.

Requires online:

- Register/login.
- OTP verify.
- Cloud migration.
- Quote request.
- Sharing.
- Provider application.
- Push token registration.

If offline during auth-required action:

- Explain that the action needs connection.
- Keep the local draft.
- Offer retry when online.

## 9. Provider Auth Strategy

Provider path is separate:

1. Choose Path -> Provider.
2. Explain provider review.
3. If unauthenticated, show provider auth gate.
4. Register/login.
5. Complete provider application.
6. Show status screen.
7. After approved/active, show provider navigation.

Provider rules:

- Provider account does not automatically enter wedding-user shell.
- Provider dashboard requires provider profile state.
- Suspended/rejected providers see restricted state.
- Provider status messages must not promise approval.

## 10. Acceptance Criteria

- Guest-first decision is explicit.
- Guest capabilities and limitations are documented.
- Account gate triggers and resume behavior are defined.
- Guest plan migration steps and failure behavior are defined.
- Provider auth path is separated.
- Security and offline rules are documented.
- No auth/backend/mobile code is changed.

## 11. Risks

- Migrating local guest data incorrectly can create duplicate server records.
- Keeping resume targets in URLs can expose private data if not encoded safely.
- Provider account flow can confuse users if not separated from wedding-user flow.
- Guest local financial records need privacy and device-storage consideration.
- Auth gate must not become a hidden mandatory-login wall.

## 12. Next Implementation Notes

- Next stage: `docs/architecture/LOCATION_PROVIDER_MATCHING.md`.
- Do not change current auth screens until Mobile Implementation Plan.
- Do not implement migration before Offline & Sync Plan and Testing & QA Plan.

