# Aarast Adaptive Experience System V3

Snapshot date: 2026-08-10

Status: active Mobile design-system contract. Admin Web modernization remains a
separate surface and must not limit the Mobile product direction.

This Markdown file is the source of truth for design-system rules and tokens.
`docs/design/AARAST_MOBILE_EXPERIENCE_SYSTEM_V3.docx` is the synchronized
product and architecture companion. Runtime values and behavior must remain
traceable to the code boundary below; documentation never overrides a newer
verified implementation silently.

## Product Direction

Aarast is an Arabic-first planning workspace. It must feel calm, precise,
responsive, and unmistakably contemporary. It is not a wedding invitation,
luxury brochure, or stack of decorative cards. The active direction is a soft
near-white content layer with quiet neutral boundaries, a deep burgundy
identity, restrained champagne accents, and a clearly operable control layer. Color establishes
identity and meaning; it never excuses page-sized decoration or weak contrast.

The former Royal/Premium component language remains retired: no crown,
ornamental gradient, glow, glass, decorative shadow, or repeated dark hero.
Mobile V3 restores Aarast's recognizable burgundy/ivory/champagne identity
through semantic role names only; it does not restore the card-heavy ornamental
implementation.

## Source Of Truth

The active code boundary is:

- `mobile/lib/core/experience_v3/aarast_v3_foundations.dart`: color, type,
  spacing, radius, and motion foundations.
- `mobile/lib/core/experience_v3/aarast_v3_composition.dart`: context, page,
  metrics, continuous surfaces, progress, and signal composition.
- `mobile/lib/core/experience_v3/aarast_v3_adaptive.dart`: route screen
  contracts, compact attention/state surfaces, trust signals, and the
  app-level experience scope.
- `mobile/lib/core/experience_v3/aarast_v3_content.dart`: shared Arabic copy
  for frequent loading, offline, permission, empty, and planning states.
- `mobile/lib/core/experience_v3/aarast_v3_forms.dart`: compact form surfaces,
  progressive disclosure, and primary submit actions.
- `mobile/lib/core/theme/aarast_design_tokens.dart`: semantic bridge that
  resolves active roles from V3 only.
- `mobile/lib/core/theme/app_theme.dart`: Flutter Material theme consuming the
  semantic bridge.

Feature code may compose domain components from these foundations. It may not
introduce another palette, local theme alias family, or generic hero copied
across unrelated screens.

## Experience Architecture

```text
V3 foundations
  -> composition primitives
    -> domain kits
      -> routed screens
        -> behavior, responsive, visual, and build gates
```

Changing an API, route, permission, offline owner, or persistence contract is
outside a design-system migration unless separately approved.

### Screen Archetypes

Routed Mobile screens use one of five composition contracts instead of
inventing a new structure per feature:

1. root tab: compact context, current state, one attention item, one action;
2. list: title/filter rail followed by one continuous row surface;
3. detail: identity summary, primary decision, essential content, progressive
   secondary detail;
4. form: one decision first, optional detail on demand, one submit action;
5. settings/utility: small identity anchor and a limited number of logical
   groups, with destructive actions isolated from navigation.

The archetype controls hierarchy and density. Domain data, capability, and
truthful state still belong to the feature.

### Attention And Surface Budget

Every routed screen follows one decision budget:

- one primary location anchor;
- at most one dominant attention item;
- one primary action;
- the first useful content before a full-screen scroll whenever the state
  permits it;
- no duplicate count, total, status, or action in adjacent regions;
- no card inside another card;
- no more than one dominant semantic color in the same attention region.

Content uses four surface roles only:

1. decision surface: the single item that requires action now;
2. summary surface: the minimum truthful metrics needed to understand status;
3. continuous row surface: lists separated by rhythm and dividers;
4. state surface: loading, empty, error, offline, locked, queued, or read-only.

A feature-specific component must map to one of these roles or justify why the
existing composition primitives cannot represent it.

## Visual Foundations

### Color

- `canvas`: `#FFFEFD`
- `paper`: `#FFFFFF`
- `paperQuiet`: `#F7F6F5`
- `ink`: `#2D1A1E`
- `textMuted`: `#6F6467`
- `line`: `#E8E3E4`
- `primary`: `#800020`
- `primaryDark`: `#5A0015`
- `primarySoft`: `#F8E8EC`
- `onPrimary`: `#FFFEFD`
- `brandAccent`: `#D9B15F` (decorative, never small text on ivory)
- `brandAccentStrong`: `#8A6A24` (AA-capable text/icon role)
- `brandAccentSoft`: `#FBF3DE`
- `cobalt`: `#5A788D`
- `mint`: `#4E8A78`
- `amber`: `#A56D34`
- `rose`: `#B86170`
- `danger`: `#B74452`

Near-white and white own most of every screen. Burgundy owns brand marks, primary
actions, selection, thin rails, and the single Home plan-moment surface.
Ivory/champagne is limited to the plan path, restrained financial emphasis, and
small decorative strokes on burgundy; only `brandAccentStrong` may carry small
text on a light surface. Green, amber, red, and cobalt retain semantic meaning.
Status colors appear with text or icons and never carry meaning alone.

### Typography

- IBM Plex Sans Arabic owns display and decisive headings.
- Tajawal owns body, labels, fields, and dense product content.
- Currency, dates, phone values, and percentages preserve their intended
  numeric direction inside RTL layouts.
- Journey screens take every text size from one scale (`JourneyType`, D8),
  sized for phones 360 to 412 points wide at the person's own text size:

  | Role | Size | Used for |
  | --- | --- | --- |
  | `display` | 24 | A screen's heading or question |
  | `title` | 18 | Card, sheet and section titles |
  | `figure` | 22 | A typed amount or name in a large field |
  | `bodyLarge` | 16 | Buttons, field values, list titles |
  | `body` | 15 | Running text |
  | `small` | 13 | Secondary lines, hints, field labels |
  | `caption` | 12 | Tags, the Hijri date under a day |

  A screen never passes a number; a test fails if one does. Main actions
  are 52 points tall, and picture choice cards 104.

### Spacing And Shape

- Spacing scale: 4, 8, 12, 16, 20, 24, 32, 40, 48.
- Control radius: 12.
- Standard surface radius: 16.
- Feature stage radius: 30.
- Pills are reserved for filters, compact status, and true capsule controls.
- Touch targets remain at least 48x48.
- Primary buttons use a 54px minimum height; compact form actions may use 48px
  only when their touch target and label remain clear.
- Filled form fields use 14px horizontal and 10px vertical content padding with
  a quiet surface fill and one focused bottom line. Prefix/suffix affordances
  remain frameless unless the surrounding component is itself an identity or
  state surface.

Prefer open space, dividers, and continuous rows. Cards are exceptional, not
the default grouping device. Do not put an outlined input inside an outlined
card inside another card. Blur belongs only to the floating control layer; it
must not spread into content panels.

### Density And Continuous Lists

- At 420px, compact tab context and primary summaries should normally stay
  within 160-180px. Home is the deliberate exception: its single plan moment
  uses a 146-176px responsive height, keeps the date above the location, and
  still leaves the next decision visible before a full-screen scroll.
- At 320px, title, status, metadata, and the one contextual action may stack,
  but none may clip or create horizontal scrolling.
- The shared page rhythm is 20px horizontal, 12px top, 20px section gap, 12px
  compact gap, 68px minimum continuous-row height, and 82px minimum metric
  height. A plan-root page reserves 184px at the bottom only when the floating
  quick action and command dock are present; ordinary pages reserve 112px.
- Home owns one plan moment, at most one attention surface, three independent
  compact signals, one expanded Money surface, and one compact team strip.
- People, tasks, notifications, utilities, and settings share the same row
  hierarchy: identity, title, secondary truth, compact state, one direct
  action, and overflow for secondary actions.
- A list is one continuous surface with dividers, not a stack of cards.
- The same fact or count is not repeated in the header, summary, and list.

### Motion

- Quick feedback: 120ms.
- Standard transition: 220ms.
- Deliberate transition: 360ms.
- Motion must be interruptible and respect reduced-motion preferences.
- Rebuilding a list must not replay decorative entrance animations.
- Routed Mobile pages use one quiet fade plus a short RTL-aware horizontal
  shift. Tasks and Guests may use a shared-element transition from the Home
  metric that opened them; the destination summary owns the matching element.
- Completion uses a short state change, restrained haptic feedback, and Undo
  for reversible mutations. Success never opens a decorative dialog.

## Navigation And Location

Every routed view must answer without guessing:

1. Which account or plan am I in?
2. Which product area is this?
3. What requires attention now?
4. What is the one primary action?

The plan shell owns context, top-level navigation, safe areas, and contextual
creation. Pages do not recreate that shell. The five-destination command dock
is white or near-white with a quiet boundary and keeps every destination label
visible; the current destination receives only a soft burgundy tint. The plan context is a
compact typographic anchor, not another toolbar card.

`+ إضافة` is the only plan-level creation entry. Its labelled action sheet may
offer task, guest, cost, payment, payment-schedule, budget-category, or quote
work only when the real route and matching permission exist. The order adapts
to the current tab, wedding stage, truthful urgency signals, and the last useful
action in the running session; at most one option is marked as recommended. The
control floats at the lower RTL side above the navigation dock instead of
consuming header space. It uses a contextual label on task, guest, and money
roots, compacts to its icon while scrolling down, expands while returning up,
and disappears for the keyboard, forbidden money writes, provider discovery,
and money subpages. The plan header remains a compact location anchor only.

## Domain Identities

Consistency comes from foundations and behavior, not from rendering the same
hero and cards on every screen.

- Home is a one-screen smart brief: a single solid-burgundy plan moment, one
  calculated next decision, three separate compact truth signals, one expanded
  permission-aware Money surface, and a compact team strip. It must not
  repeat the same facts in a long dashboard scroll. Its single focus follows a
  deterministic urgency order: overdue payment, overdue task, received quote,
  incomplete guest, pending guest reply, missing budget, then missing provider.
  The plan moment shows stage and title first, days remaining as the counter,
  wedding date on one line, location directly below it, one labelled completion
  value, and the shared Plan Path. Metadata may truncate but must never collide
  at 320px or enlarged text.
- Money is a compact white decision ledger: available amount, budget progress,
  payment attention, and flat cost rows begin immediately after the summary.
- Guests is a compact white attendance brief: expected seats, replies, sides,
  and filters. Burgundy carries identity while cobalt remains an informational
  status accent, never a stage background.
- Tasks is a compact white execution brief: urgency, remaining work,
  completion, and a chronological list. Signal color remains an accent only.
- Providers is a visual directory: discovery, search, filters, work samples,
  and truthful quote entry. Search and results begin directly below a compact
  white directory header. Provider detail orders identity, media, trust/price,
  services, and quote action before progressively disclosed secondary detail;
  media failure is a designed state rather than a broken-image gap.
- More is a utility space: account, plans, help, sync, and destructive actions
  with low visual competition.
- Provider Home is a work studio: business identity, lifecycle state, live
  metrics, requests, and catalog actions.

Role-specific workspaces use the same foundations. Capability and information
change by role; palette and interaction grammar do not.

`AarastV3PlanPath` is the product signature shared by Home, Tasks, and Guests.
It is a thin milestone path built from truthful plan progress, not a decorative
illustration or a second progress score.

### Wedding Day Mode

The command view is available only from seven days before the wedding through
the day after. It uses the real plan date, time, location, unfinished urgent
tasks, responsible contacts, and existing plan providers. Missing provider
phone data stays absent rather than being fabricated. The route requires plan
view access, does not add a backend or schema contract, keeps cached tasks
visible when refresh fails, and prioritizes large one-hand actions. It is not a
booking, payment, open-messaging, or AI feature.

### Wedding Stage Engine

The plan chrome and Home resolve one shared stage from the real wedding date:
`بداية التخطيط`, `مرحلة التخطيط`, `الشهر الأخير`, `الأسبوع الأخير`,
`يوم العرس`, or `إغلاق الخطة`. The label shares the existing compact header
line and must not add another hero. The stage may adapt the recommended create
action, but real overdue tasks, due payments, incomplete guests, and missing
providers remain separate factual signals. The resolver is deterministic,
date-boundary tested, and available offline; it is not an AI or readiness
score.

Tasks, notifications, and payment schedules use one temporal grammar:
`الآن`, `اليوم`, `هذا الأسبوع`, `لاحقًا`, and `مكتمل`. Completed notification
means read; completed payment means paid/cancelled according to its domain
state. A section is omitted when it has no real items.

## Form Composer

Forms must not resemble long administrative documents.

1. Show only fields required for the current decision.
2. Begin with one `FocusPrompt` question, reveal additional detail
   progressively, and keep a small live decision summary near the submit area.
3. Keep related choices in one compact sequence; field fill and a single focus
   line replace nested outline boxes.
4. Place provider, notes, address detail, permission customization, or other
   nonessential inputs behind progressive disclosure.
5. Keep one explicit submit action with loading, disabled, validation, and
   failure states.
6. Preserve entered data when a disclosure opens or a request fails.
7. Creation-center forms for tasks, guests, costs, and quote requests autosave
   account-scoped drafts in the secure platform vault. They show a small
   saving/saved/failure line, restore after navigation or process interruption,
   clear only after a successful submit, and are removed with account teardown.
   Private guest and money values must never fall back to plaintext preferences.
8. Financial creation shows total, paid-now, and remaining values directly
   before submit so the user can verify the decision without another dialog.
9. At 420px, the primary decision should normally be visible before the first
   full-screen scroll; at 320px it must remain reachable without overflow.
10. Bottom sheets use intrinsic height when possible and must account for the
   keyboard and safe area.
11. Successful submission uses one non-blocking receipt. It offers the next
    truthful action (`إضافة أخرى`, `فتح التكلفة`, or the real destination), or
    returns automatically when that return already completes the workflow.
    Success never opens a confirmation dialog.

## Contextual Actions And Feedback

- The row exposes the one truthful next action when it is unambiguous: overdue
  task -> `إعادة الجدولة`, incomplete guest -> `إكمال البيانات`, pending guest
  -> `تحديث الرد`, and overdue payment -> `تسجيل دفعة`.
- Overflow menus remain for secondary actions. `إرسال تذكير` is not shown until
  a real reminder delivery contract exists.
- Successful completion/status/payment mutations use restrained haptic feedback.
  Reversible task and guest mutations use the existing toast/undo path; loading
  remains inside the originating button rather than opening a blocking dialog.
- Feedback transitions are 120-180ms and become instantaneous when reduced
  motion is requested.
- Saved providers compare in one continuous two-or-three-column surface. The
  user selects up to three real saved providers and compares category, city,
  displayed price, rating, and active service count without implying booking.

## Truth And State

- Null is not zero.
- Hidden or forbidden data is not an empty result.
- A reminder is not a payment.
- A quote is not a booking.
- Local-only, queued, stale, loading, error, offline, locked, and read-only
  states remain explicit.
- Counts, participants, prices, progress, and readiness are never invented to
  improve a composition.
- Private finance remains absent unless `canViewMoney` permits it; mutation
  controls remain absent unless the matching write permission permits them.

## Accessibility And Arabic

- RTL is the composition default, not a final mirroring pass.
- Icon-only controls require a tooltip or semantic label.
- Focus order follows Arabic reading and task order.
- Text scaling must not clip totals, navigation, or submit actions.
- Foreground roles used as text meet AA contrast on their intended surfaces.
- Arabic copy is concise and does not expose enum or API vocabulary.

## Current Implementation Checkpoint

Implemented in the current working tree:

- independent V3 foundations, composition primitives, and form primitives;
- a runtime contract for every active route archetype, including purpose,
  supported truth states, privacy sensitivity, offline support, and one-hand
  criticality, with unknown routes failing visibly into an unmapped contract;
- one compact attention surface and one compact state surface used by Home,
  Guests, Money, auth/access gates, and shared loading/error/empty states;
- a phone-derived responsive rule that stacks the contextual action at narrow
  widths or enlarged text without clipping the decision copy;
- a shared top sync/offline trust line in the plan shell and a single progress
  primitive that replaces feature-owned raw progress bars;
- V3 as the only active semantic color source;
- removal of old Mobile theme aliases and the shared editorial hero;
- a soft near-white Mobile palette with a deep burgundy identity, restrained
  champagne accent, and unchanged semantic status roles;
- a compact smart Home that fits its primary brief within one phone screen;
- one labelled, state-aware creation sheet instead of an unexplained detached
  plus button;
- deterministic Plan Pulse reconciliation across Home, Tasks, Guests, provider
  presence, and money attention without claiming AI;
- one thin Plan Path signature shared by Home, Tasks, and Guests, with shared
  route transitions from the corresponding Home metrics;
- compact white Money, Guests, Tasks, and Providers headers that keep working
  content above the fold;
- direct truthful task, guest, and payment actions with unified feedback;
- secure autosaved drafts for durable task, guest, quote, plan, sharing,
  provider, budget, cost, payment, and schedule forms, with auth secrets
  explicitly excluded;
- inline validation, keyboard-aware next/done actions, and a financial save
  summary for the primary creation forms;
- Focus Mode prompts on every non-auth domain form, live summaries and
  progressive additional detail where useful, and fixed keyboard-safe action
  areas on full-screen forms;
- practical empty, loading, error, offline, and read-only states using Arabic
  product language and the nearest truthful action;
- a permission-aware Wedding Day Mode backed by real plan/task/provider data,
  a full cached dashboard summary plus cached-task cold-start continuity,
  one-hand actions, and no invented contacts;
- one wedding-stage engine across plan chrome, Home, Tasks, Guests, Money,
  Providers, and smart creation order, plus one temporal grammar across tasks,
  notifications, and schedules;
- one saved-provider comparison surface and a shared non-blocking form-success
  receipt with truthful next actions;
- reviewed changed Goldens plus a passing 50-Golden Mobile suite;
- `flutter analyze` and the full 1,134-test Mobile suite passing at the
  2026-08-10 documentation checkpoint;
- a white/near-white five-destination command dock with all labels visible and a
  quiet soft-burgundy active state;
- border-led empty, error, setup, utility, and list states instead of repeated
  rounded cards;
- one responsive continuous-row primitive shared by guests, participants,
  notifications, settings, utilities, and dense task views, including stacked
  320px status behavior;
- three separate compact dashboard signal cards plus one expanded truthful
  Money surface instead of either four equal cards or one compressed 2x2 block;
- a compact More hierarchy with only `خططك` and `أدواتك`, while logout and
  account deletion live behind a separate account-actions sheet;
- notifications rendered as white semantic rows instead of large status-color
  panels;
- provider services shown first while packages, about, and reviews use one
  explicit progressive-detail control;
- a flat `AarastBrandMark` and a production-source gate that rejects gradients
  and decorative `BoxShadow` usage anywhere under `mobile/lib`;
- open V3 authentication narratives;
- compact progressive disclosure shared by auth, plan, task, guest, finance,
  provider, quote, and sharing forms;
- existing routed Mobile screens migrated from retired color names to semantic
  roles without changing product contracts;
- retired Premium/Royal production class and file names removed, with an
  automated source gate preventing their return;
- one restrained success haptic and non-blocking receipt, with real Undo for
  reversible task, guest, and saved-provider mutations;
- 73 focused edge cases passing across 320px/420px, 1.3x/2.0x text, finance,
  provider, sharing, and contributor surfaces.

Still required before a release-ready claim:

- physical routed review of every secondary screen and edge state at 320px and
  420px RTL; the five owner root tabs and a cached airplane-mode cold start
  passed on a 1440x3120 Samsung device at 1.15 text scale, but
  secondary/auth/form and offline mutation/sync-recovery coverage remains;
- reviewed replacement Goldens whenever another route or edge state changes;
- physical enlarged-text and short-height form review;
- release Android signing/package verification (Release Web and debug APK pass);
- exhaustive physical Android verification beyond the passing owner root-tab
  smoke, and physical iOS verification.

## Verification Gate

For every migrated route, record:

1. behavior/navigation test result;
2. permission/privacy result where applicable;
3. loading, empty, error, offline, disabled, and read-only states;
4. 320px and 420px RTL visual review;
5. enlarged-text and keyboard behavior for forms;
6. reviewed screenshot or Golden;
7. `flutter analyze`, full tests, and relevant build result.

The automated source gate also rejects production gradients, decorative
`BoxShadow`, raw feature-owned colors, unlabelled icon buttons, and routed
screens without an explicit widget-test owner.

Updating a Golden without first reviewing the routed screen is not evidence of
an improvement.

## Documentation Synchronization

When a design-system rule changes:

1. update the owning V3 token, composition, form, or shell implementation;
2. update this Markdown contract in the same change set;
3. update the companion DOCX when product direction, architecture, hierarchy,
   or acceptance gates change;
4. replace and review only the affected Goldens;
5. record what is implemented, what is only specified, and what still requires
   physical-device verification.

The archived design documents remain historical evidence only. They may not be
used to reintroduce Premium/Royal compatibility components, ornamental palette
aliases, or superseded screen hierarchies.
