# Decisions

## Current Decisions Addendum - 2026-06-14

| Decision | Status | Rationale |
| --- | --- | --- |
| Treat Flutter SQLite as a mobile cache/sync layer only. | Accepted | PostgreSQL remains the backend source of truth; SQLite supports offline UX and selected queued writes without storing credentials or replacing server data. |
| Keep provider marketplace work as planning/reference and quote-lead flows. | Accepted | Provider listings, favorites, reviews, quote requests, provider dashboard, and admin approval exist, but paid booking, deposits, provider settlement/payment-processing status, and financing remain excluded. The user's manual CostPayment ledger is part of planning, not payment processing. |
| Split production domains only after Compose/Dokploy/NPM are aligned. | Accepted | Current Dokploy Compose has backend on `8093` and admin-web on `8094`. A separate Flutter web service on `8095` is not configured in the committed production Compose file. |
| Meta WhatsApp OTP has a production channel, while external activation remains pending. | Accepted and implemented in code | The backend sends approved authentication templates through Meta Cloud API, never echoes production codes, and fails boot on incomplete channel configuration. Live activation still requires Meta business/template approval and real secrets outside Git. |

## Current Decisions Addendum - 2026-07-06

| Decision | Status | Rationale |
| --- | --- | --- |
| Allow conversations only when attached to a real quote request. | Accepted | Messaging is limited to the requester and the provider account on that quote. Open or unsolicited messaging remains excluded. |
| Use one prelaunch money domain: general budget, categories, `WeddingCost`, `CostPayment`, and `PaymentSchedule`. | Accepted and implemented | `Expense`, `FinancialCommitment`, `FinancialPaymentRecord`, `FinancialInstallment`, their routes, caches, operational seed/load tools, and user-facing concepts were removed rather than kept as compatibility paths because there are no production users. Every cost belongs to one category; payments and schedules belong to one cost. |
| Calculate every money surface from the canonical cost ledger. | Accepted | Confirmed cost is the sum of non-cancelled cost totals. Paid is the net append-only payment ledger after reversals. Outstanding is confirmed cost minus paid, and remaining budget is the general budget minus confirmed cost. A schedule is only a reminder and contributes nothing until paid. |
| Keep category allocation separate from the general budget. | Accepted | A null general budget remains unset and category allocations never become a fallback general budget. Budget-first setup may save no categories; any positive category allocation requires a non-null general budget, and total allocations may not exceed it. |
| Make finance sharing understandable. | Accepted | `canViewMoney` controls all private money reads and `canManageMoney` controls all money writes. Hidden values are absent, not returned as misleading zeros. |
| Use short-lived access tokens with rotating refresh tokens. | Accepted and implemented | Access JWTs default to 15 minutes. Opaque 30-day refresh tokens are hashed at rest, rotated transactionally, and revocable per session or per user. Terminal rows remain for 30 days after their applicable expiry or revocation event for reuse detection and incident evidence, then an hourly single-replica cleanup removes them. |
| Keep one active documentation source per area. | Accepted | `docs/README.md` owns the source map. Historical plans and reports live as `.md.txt` under `docs/archive/` and must not compete with current docs. |

## Current Decisions Addendum - 2026-07-10

| Decision | Status | Rationale |
| --- | --- | --- |
| Require verified phone ownership before account or invite access. | Accepted and implemented | Registration creates no User/session before OTP completion; legacy unverified sessions are revoked and JWT/refresh/password login remain blocked until phone proof. |
| Persist invite-token fingerprints and enforce delegated permission ceilings. | Accepted and implemented | Raw external tokens exist only in the create response, invite consumption is atomic, and a delegated inviter cannot grant effective authority above their own. Email-only invites remain disabled until verified-email identity exists. |
| Scope Flutter state by account and selected plan. | Accepted and implemented | Account identity changes dispose the complete data-provider subtree; plan changes replace plan-sensitive providers without rebuilding navigation. Late responses from disposed providers cannot repopulate another session. |
| Bind offline replay to its originating session. | Accepted and implemented | Replay captures the cache owner, session generation, and access token. Logout or account change stops the old loop, prevents the new token from authorizing an old write, and restarts only the new account queue. |
| Keep guest budget optional through dashboard entry. | Accepted and implemented | Saving an empty quick-setup budget records an explicit skip; completion accepts a budget or that skip. A skipped or null budget remains unset and category allocations must not silently replace it. |
| Fail mobile Release closed. | Accepted and implemented in source | Product builds require an explicit public HTTPS API origin, reject development login bypass, and Android refuses missing/placeholder/nonexistent signing configuration instead of falling back to debug keys. iOS runs the equivalent API gate before its Flutter build. |
| Keep native launch identity consistent with the live design system. | Accepted and implemented | Android adaptive/legacy icons and splash plus iOS AppIcon/LaunchImage use the same burgundy, gold, ivory, and celebration-spark mark as the in-app brand. Generated sizes are tested, while final store and device review remains a release gate. |
| Separate liveness from readiness. | Accepted and implemented | `/live` and `/health` prove only that the process responds; `/ready` verifies PostgreSQL and required Redis/media dependencies with bounded timeouts and redacted failures. Production containers use readiness before receiving dependent traffic. |
| Use a transactional PostgreSQL outbox before adding an external broker. | Accepted and implemented | Notification and chat availability events commit with their domain rows. Workers use `FOR UPDATE SKIP LOCKED`, stale-lock recovery, bounded retries, failed-event retention, metrics, and alerts. Immediate Socket.IO delivery remains the low-latency path; outbox availability events repair commit-to-publish crashes. |
| Bind and expire idempotency keys. | Accepted and implemented | A user key is valid only for one method, concrete target, and canonical body. Identical retries replay safely, mismatches return `409`, pending reservations and completed responses have bounded lifetimes, and cleanup uses a cross-replica PostgreSQL advisory lock. |
| Keep provider rating caches transactionally exact. | Accepted and implemented | Review create/update/delete and admin publish/hide serialize on the Provider row, mutate the review, and derive the published-only count/average in one transaction. Account deletion explicitly refreshes every surviving provider whose review cascades would otherwise make the cache stale. |
| Validate provider prices at the shared money boundary. | Accepted and implemented | Service base prices, package prices, quote-offer amounts, admin service prices, and marketplace price filters share one `numeric(14,2)` validator. Overflow and excess precision fail as `400` before persistence instead of becoming PostgreSQL rounding or `500`. |
| Require password + phone OTP and server-bound browser sessions for administration. | Accepted and implemented | General login paths cannot mint admin assurance. Every access JWT has a signed `application` or `admin` scope; product and Chat guards reject admin-scoped tokens, while admin guards require the admin scope, MFA, and a live server session. Access tokens stay in memory, refresh tokens stay in rotating HttpOnly/SameSite cookies, and refresh/logout invalidate the prior admin JWT immediately. |

## Current Decisions Addendum - 2026-07-12

| Decision | Status | Rationale |
| --- | --- | --- |
| Allow a temporary hardened OpenWA OTP transport for the risk-accepted MVP, while retaining Meta as the target channel. | Accepted and locally verified; limited rollout gates remain | Aarast never calls stock `send-text`, applies durable HMAC-keyed phone/IP/global quotas, and fails readiness unless a connected session exposes the transient contract. The pinned fork, QR link, no-persistence proof, protected restart, and live self-recipient request/verify flow pass. An independently owned second recipient and 24-hour stability observation remain mandatory before widening the MVP rollout. |

## Current Decisions Addendum - 2026-07-23

| Decision | Status | Rationale |
| --- | --- | --- |
| Make conversation identity the provider relationship context, not one request. | Accepted and implemented | `PLAN` is unique by `weddingPlanId + providerId`; `ACCOUNT` is unique by `accountRequesterUserId + providerId`. Every QuoteRequest is linked to exactly one conversation and multiple requests share its timeline. |
| Derive conversation authorization live from plan/provider relations. | Accepted and implemented | Plan owners, explicit `SharedMember.canManageProviders` members, the account requester, and the linked provider account are authorized by current rows on every REST/Socket operation. Role defaults initialize the stored provider flag only on a new invitation; direct member creation is fail-closed, and the current stored boolean is authoritative across provider APIs and conversations. `ConversationParticipant` stores only personal state and is never an authority source. |
| Keep quote lifecycle updates as system events, separate from human messages. | Accepted and implemented | `ConversationEvent` stores idempotent request/offer events without price or contact data. Offer expiry is derived from `validUntil`; unread counts include human messages only. |

## Current Decisions Addendum - 2026-07-15

| Decision | Status | Rationale |
| --- | --- | --- |
| Keep payment schedules non-reserving and use one payment-reminder date. | Accepted and implemented | `WeddingCost` has no due date; `PaymentSchedule.dueDate` is the only payment-reminder date. A pending schedule neither deducts nor reserves money and cannot block a direct payment. Each reminder amount is checked independently against the row-locked outstanding cost on create/update, and any payment that completes the cost cancels the remaining pending reminders. |

## Current Decisions Addendum - 2026-07-17

| Decision | Status | Rationale |
| --- | --- | --- |
| Send participant invitation links from Aarast and bind access to token plus verified phone. | Accepted and implemented in source | Invite creation remains pending until the recipient proves the exact invited phone. The backend sends a generic private link through the hardened transient OpenWA contract, reports uncertain delivery honestly, and sends OTP only after token-phone matching. A first-time contributor creates a real application password with that same verified invite OTP; no hidden random password or second registration OTP is allowed. Verification only reveals the invitation, role, and permissions; the participant must explicitly accept or reject before any membership is created or the shared plan opens. Manual `wa.me` composition was removed so the owner is not responsible for delivering the link. |

## Current Decisions Addendum - 2026-07-20

| Decision | Status | Rationale |
| --- | --- | --- |
| Create one planning cost when a provider offer is accepted. | Accepted and implemented in source | Offer acceptance and `WeddingCost` creation are one serializable, idempotent transaction keyed by unique `quoteOfferId`. The cost starts unpaid, uses the plan currency and provider/service context, and falls back to `أخرى` only when no logical budget-category match exists. This creates no payment, payment schedule, task, booking, settlement, or payment-processing state. |

## Current Decisions Addendum - 2026-07-24

| Decision | Status | Rationale |
| --- | --- | --- |
| Fail closed on weak production JWT secrets and serialize authentication attempt ceilings at the database row. | Accepted and implemented in source | Production startup rejects missing, placeholder, short, repetitive, or low-entropy JWT secrets without exposing them. OTP comparison, failed attempts, exhaustion, and consumption are committed under one row lock; password attempts reserve admission under a row-locking upsert before credential comparison so concurrent replicas cannot bypass the configured ceiling. |
| Serialize every quote decision with one request-first lock order and live permissions. | Accepted and implemented in source | Accept, reject, provider update, and requester cancel lock QuoteRequest before QuoteOffer, re-read the current state, and use an expected-state write. Acceptance also locks and rechecks provider plus money authority inside the same transaction, so revocation or another terminal decision cannot leave cost/link rows attached to a non-accepted offer. |
| Make conversation revocation transactional and reactivation explicit. | Accepted and implemented in source | Send and mark-read recheck live authority plus the active participant under locks in one serializable transaction. Sending and reading never clear `revokedAt`; only an explicit provider-management grant may reactivate a participant. A provider joins only through its own access, so customer reads preserve the truthful `providerJoined: false` read-only state. |

## Current Decisions Addendum - 2026-07-25

| Decision | Status | Rationale |
| --- | --- | --- |
| Derive account contexts from current ownership and membership rows. | Accepted and implemented in backend source | One authenticated User may expose owner contexts from `WeddingPlan.ownerUserId`, contributor contexts from `SharedMember`, and one provider context from `Provider.userId`. `User.role` and `appRole` are not sufficient context authority, no role-membership table is added, and every validation rebuilds permissions from current database rows. |
| Never replace an invalid active plan automatically. | Accepted and implemented in backend source | `GET /api/v1/wedding-plans/active` returns the explicitly selected accessible planning plan or null. Deleted, archived, or revoked selections never fall back to a different plan; the future Flutter context selector owns the next explicit choice. |

## Current Decisions Addendum - 2026-07-29

| Decision | Status | Rationale |
| --- | --- | --- |
| Keep one provider category catalog with groom/bride discovery flags. | Accepted and implemented in source | What the customer requests remains the shared category identity. `showForGroom` and `showForBride` separate visibility without duplicating provider data, while service titles and later tags carry specialization. Flutter derives the active view only from `AccountContextController.selectedContext.persona`. |
| Model Yemen governorates and districts separately from legacy City. | Accepted and implemented in source | The OCHA Yemen/CSO HDX v01 reference provides 22 first-level units including Amanat Al Asimah and 335 districts. Stable codes and coordinates live in database tables and public read APIs; the existing City relations remain temporarily compatible and are not relabeled as governorates. |

## Current Decisions Addendum - 2026-07-30

| Decision | Status | Rationale |
| --- | --- | --- |
| Make `AuthController` and `SessionTeardownCoordinator` the single Logout/session-expiry termination boundary. | Accepted and implemented in mobile source | The session state machine is `checking`, `authenticated`, `terminating`, `terminationFailed`, and `unauthenticated`. Logout increments the session operation generation, removes the in-memory user, enters `terminating`, and notifies the widget tree before awaiting cleanup. Credential capture is bounded to two seconds and every local cleanup stage to five seconds, so no dependency can leave the termination screen spinning forever. Local auth storage, account cache, guest draft, and the account's push binding are cleared before remote auth revoke and push unregister run in parallel with a two-second deadline. A local failure or timeout exposes only a retry-safe termination screen; a remote failure or timeout never restores the old session. |
| Bind the persisted account context to its authenticated user. | Accepted and implemented in mobile source | Context persistence version 2 stores `version`, `userId`, and `contextKey` in the sensitive-value vault. A fresh authenticated session and full logout clear the prior selection. A multi-context account must choose again, a single available context may be selected directly, and cold restart restores only a same-user context that remains available in the fresh API result. A legacy raw key is migrated once when its user is known and is cleared if it is no longer valid. |
| Give the session and account-context gates ownership of authentication-driven entry navigation. | Accepted and implemented in mobile source | `AarastSessionTransitionGate` prevents Login or any Dashboard from being mounted while the session is `checking`, `terminating`, or `terminationFailed`. `AarastAuthFlowRedirector` consumes Login, Logout, expiry, and invite-entry intents once; `AccountContextEntryGate` owns the matching Dashboard entry after context resolution. Logout widgets only request `AuthController.logout()`. Effective route transitions are recorded centrally, while ordinary in-feature navigation remains local to its feature. |
| Use structured, privacy-redacted, memory-bounded mobile observability with optional Sentry delivery. | Accepted and implemented in mobile source; external acceptance pending | `AppLogger` uses logical categories rather than local `*.log` files, a Debug console sink, a 300-event/256KB/15-minute memory ring, and an optional Sentry sink. Identifiers are installation-salted hashes; tokens, credentials, contact data, headers, query values, and bodies are removed. Sentry errors are sampled at 100%, traces default to 100% in Staging and 10% elsewhere, and profiling, replay, screenshots, default PII, raw print/HTTP breadcrumbs, and request bodies are disabled. A diagnostic JSON attachment is generated in memory and sent only after explicit consent for that attempt. Live symbolication, access control, retention, and PII verification remain release gates outside the application code. |
| Keep the Firebase installation identity device-scoped across account Logout. | Accepted and implemented in mobile source | Logout immediately cancels the old account registration request, clears its in-memory binding, and gives a new session a fresh operation queue. It does not delete the device FID or FCM token; the captured old credentials are used only for the bounded server unregister. Token refresh and app resume revalidate the current account binding. The `FirebaseInstallations.onIdChange` bridge is intentionally not used because the current Flutter plugin dispatches that callback from a Firebase background thread on Android. |

## Current Decisions Addendum - 2026-07-31

| Decision | Status | Rationale |
| --- | --- | --- |
| Make contributor invite outcomes replay-safe and bind access to live membership. | Accepted and implemented in backend and mobile source | Acceptance and decline perform one authoritative terminal mutation and safely replay the result only to the same verified invitee without duplicate notifications. An accepted invite exposes `contextKey` only while its live `SharedMember` exists. Member removal revokes every matching live pending invite before deleting membership, and plan archive revokes all remaining live pending invitations, preventing stale links from restoring access. Flutter single-flights accept/decline, reconciles ambiguous responses, refreshes owner state while pending and at lifecycle boundaries, fails closed during context-authority refresh, and ignores out-of-order invite, access, plan, and dashboard results. |

## Current Decisions Addendum - 2026-08-02

| Decision | Status | Rationale |
| --- | --- | --- |
| Make stored `SharedMember` permission booleans the final contributor authority. | Accepted and verified locally in Backend source, tests, and the managed HTTP scenario | A role supplies defaults only when an invitation is created. Direct member creation stores explicit flags and fail-closed `false` values for omitted authorization fields. Later role changes preserve the stored booleans unless the request explicitly changes them, so `CONTRIBUTOR` or another role cannot silently re-grant a permission that the owner revoked. Every live read or mutation still requires a current membership and the current stored section permission. Staging deployment and native-device acceptance remain separate release gates. |
| Filter contributor live data per item in Backend, never by plan membership alone. | Accepted and verified locally across Backend read/write boundaries | A current contributor may receive only an item assigned to them or an item supported by their own created/completed contribution evidence, as applicable to that domain. Evidence from current or previous tenures may identify the same contributor's work, but it does not restore plan access or a revoked section permission by itself. Flutter receives the already-scoped result and must not hide plan-wide data after download. |
| Preserve contributor work as immutable, privacy-allowlisted snapshots. | Accepted; schema, source, isolated migrations, and managed runtime scenario verified locally | `ContributorHistoryScope`, `ContributorTenure`, and append-only `ContributionEvent` separate historical evidence from live entities. Each qualifying action records plan scope, stable contributor reference, tenure, section, entity type, action, bounded action-time snapshot, hashes, provenance, permission-policy version, authority version, and timestamps. Revocation appends a boundary but never re-snapshots a live row. Database constraints, dedupe keys, indexes, and an UPDATE/DELETE rejection trigger protect consistency. History responses intentionally omit live `entityId` links, and snapshots reject contact, credential, request, attachment, and free-form sensitive fields outside the entity allowlist. |
| Backfill legacy contribution history only from explicit evidence. | Accepted and verified on fresh and populated isolated databases | The migration sets a cutover coverage timestamp and attributes only relationships proved directly by existing columns: task assignee, quote requester/creator, and invite creator while a matching current tenure exists. Accepted membership alone and old guest/money rows remain unattributed. Unsafe legacy text is omitted rather than copied, and no production row is silently reassigned. Production execution still requires the coordinated deployment gate. |
| Separate leaving one plan from deleting the Aarast account. | Accepted and verified locally across Backend HTTP and Flutter state tests; native-device acceptance pending | `DELETE /api/v1/wedding-plans/:weddingPlanId/members/me` is a transactional, replay-safe membership exit bound to the exact `expectedMemberId` and `expectedAuthorityVersion`: a delayed request cannot delete a newly invited tenure. It revokes matching pending invites, closes the tenure, clears the selected active plan, removes live membership/conversation/notification access, and retains immutable contribution events. Flutter first stores a durable installation/user/plan/membership-bound cleanup marker, quarantines ambiguous outcomes, replays before contexts load, clears the exact local plan graph, and removes the marker only after filtered contexts commit. |
| Make central account deletion recoverable after a lost response without retaining account identity. | Accepted and verified locally in Backend, Flutter state tests, and the managed deletion smoke; native process-death acceptance pending | The client persists one secure stable deletion request before sending and immediately unmounts all dashboards. The deletion transaction commits an immutable anonymous `AccountDeletionReceipt` hash before erasing the User. A throttled unauthenticated status endpoint returns only `DELETED`, `PENDING`, or `NOT_STARTED`; the client may clear the marker and restore a still-live account only after a definitive rejection plus `NOT_STARTED`. Confirmed deletion uses the one central teardown path and removes only that user's pending plan-leave markers. |
| Keep contributor create actions inside responsive section cards. | Accepted; implemented in current mobile source, physical-device acceptance pending | A full-width Arabic `FilledButton.icon` belongs below the section summary and is shown only for a current write permission. A nested or clipped `FloatingActionButton.extended` is not used. The contract includes narrow RTL screens and enlarged text, while final device review remains required. |

## Initial Project Decisions

| Decision | Status | Rationale |
| --- | --- | --- |
| Use Flutter for the mobile app. | Accepted | Flutter supports cross-platform mobile delivery with a single codebase. |
| Use NestJS for the backend. | Accepted | NestJS provides a structured TypeScript backend suitable for modular API development. |
| Use PostgreSQL for the database. | Accepted | PostgreSQL is reliable for relational planning, marketplace, and financial records. |
| Use Git worktree workflow. | Accepted | Worktrees support isolated branches and safer phase-based development, but actual worktree usage must wait until the correct Git repository root is confirmed. Do not run git init, create branches, or create worktrees during Docs Foundation. |
| Run smoke tests before expanding core features. | Accepted | Smoke checks help confirm foundations are stable before more work is added. |
| MVP starts with Wedding Financial OS, not marketplace-first. | Accepted | The primary user problem is planning, money, obligations, and coordination. |
| Do not implement confirmed bookings, deposits, provider settlement/payment-processing status, payment processing, loans, credit, financing flows, or FinTech features in MVP. | Accepted | These flows require later validation, privacy review, legal review, operational readiness, and explicit approval before implementation. Manual CostPayment entries remain allowed because they record the user's own planning ledger and do not move money. |
| Financial data is private by default. | Accepted | Budgets, categories, costs, payments, payment schedules, attachments, and private tasks must not be visible unless `canViewMoney` allows it; mutations require `canManageMoney`. |
| Early provider/service features are planning references and quote/lead flows only. | Accepted | The MVP must not become marketplace-first, paid booking, confirmed reservation, or deposit-driven. |
| Phase 3 readiness order is Prisma + PostgreSQL, User, Auth, ownership context, then WeddingPlan. | Accepted | WeddingPlan ownership must be backed by persistence and real authenticated user context before domain implementation begins. |
| Do not use mock-auth shortcuts for WeddingPlan ownership. | Accepted | Ownership and privacy behavior must not be validated against fake or temporary identity assumptions. |
| MVP User model shape is minimal and phone-aware. | Accepted | The initial User design includes `id`, `name`, `phone`, `email`, `passwordHash`, `role`, `status`, `createdAt`, and `updatedAt`; phone matters for Yemen-first usage and `passwordHash` stores hashed passwords only. |
| Initial User roles are USER, ADMIN, and PROVIDER. | Accepted | `PROVIDER` is reserved for later provider flows and must not trigger provider logic in the User model slice. |
| Initial User statuses are ACTIVE and DISABLED. | Accepted | The MVP needs a simple account availability state before richer lifecycle rules are introduced. |
| Ownership checks use authenticated user context. | Accepted | Future private modules must compare resource `ownerUserId` with the authenticated user id before returning or mutating private data; this prepares WeddingPlan without creating it yet. |
| Shared access is explicit and permission-based. | Accepted | Shared members may collaborate on a WeddingPlan, but financial visibility and task management must be granted through explicit SharedMember permissions; private financial data remains hidden by default. |
| Docs Foundation is documentation-only. | Accepted | The current phase may create or update Markdown files only and must not create app code, backend modules, Flutter screens, tests, migrations, Docker files, or deployment configs. |
| Use Docker for local service isolation and reproducible runtime environments. | Accepted | Docker is an operations decision for consistent local services and runtime behavior; it is not an implementation task in the current documentation phase. |
| Use Dokploy for VPS deployment and operations. | Accepted | Dokploy is the approved production deployment path. The current Compose runbook lives in `deploy/dokploy/`, using backend host port `8093`, admin host port `8094`, `PORT=3000`, `CORS_ORIGINS=https://aarast.shadowgardn.com,https://aarast-admin.shadowgardn.com`, and `VITE_API_BASE_URL=https://aarast-api.shadowgardn.com`. |

## Deferred Decisions

- Final mobile UI structure.
- Final admin dashboard implementation details.
- Final database schema and migration sequence.
- AI planning approach.
- Payment-processing, savings, or financing partnerships.
- Confirming the actual Git repository root.
- Permission model details for shared members.
- Attachment storage implementation.
- Exact persistence package/setup sequence.
- Exact User model constraints, indexes, and uniqueness rules.
