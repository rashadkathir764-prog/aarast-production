# Aarast Adaptive Experience System V3

Snapshot date: 2026-10-31

Status: the one active Mobile design reference. The look is **frozen on
«فيروز»** until the first real users are on the app (AGENTS.md, D67). The
August burgundy system and the unapproved `DESIGN_DIRECTION.md` draft are
archived under `docs/archive/2026-10-burgundy-direction/` and must not be used.

Where this file and the code disagree, the code in the boundary below wins and
this file is corrected in the same change.

## Product Direction

Aarast is an Arabic-first wedding planning workspace whose centre is the money.
It should feel calm and useful: a quiet grey-green canvas, white cards, one teal
identity with saffron accents, and each section keeping its own colour.

The app earns trust by knowing the wedding, not by decoration. Every screen says
what is true now and what to do next, in the reader's own gender.

## Source Of Truth

| Concern | Owner |
| --- | --- |
| Colour, space, radius, motion, density | `mobile/lib/core/experience_v3/aarast_v3_foundations.dart` |
| Type scale and the journey kit (`JourneyBox`, `JourneyButton`, `JourneyListRow`, `JourneySubHeader`, `JourneyTabHeader`, `JourneySectionTitle`) | `mobile/lib/core/experience_v3/aarast_journey.dart` |
| Loading, empty, error and notice states (`JourneyListState`, `JourneyListNotice`) | `mobile/lib/core/experience_v3/aarast_journey_states.dart` |
| Groom and bride accents, words by gender (`JourneyAccent`, `context.accent`, `context.say`, `context.planWord`) | `mobile/lib/core/experience_v3/aarast_journey_profile.dart`, rules in `docs/project/JOURNEY_PROFILE.md` |
| Sheets (`showJourneySheet`, `JourneySheetBody`) | the journey kit |
| Material theme | `mobile/lib/core/theme/app_theme.dart` through `aarast_design_tokens.dart` |

New screens use the journey kit. The older `Aarast*` and `AarastV3*` widgets
that remain are leftovers from earlier generations: do not add new uses of them,
except the live `AarastScreenFrame`, `AarastToast` and `AarastPressable`.

**The prototypes are a reference for logic, not a law of pixels.** The renders
in `mobile/test/prototype/` show what a screen is meant to know and do. They are
drawn with a separate kit, so a pixel difference proves nothing. Anything drawn
from now on is drawn with the app's own widgets.

## Screen Contract

Before a screen is built or changed, fill its card:
`.claude/skills/aarast-screen/SKILL.md`.

Every routed view must answer without guessing:

1. Which plan am I in?
2. Which part of the product is this?
3. What needs me now, and why?
4. What is the one primary action, and where does it lead?

Each routed screen has one location anchor, at most one dominant attention item,
and the one primary action. The same fact does not repeat in adjacent regions.
A next step names the concrete action and its reason («سجّل الدفعة · لأن موعدها
قريب»), never a generic «تنفيذ الآن». If the server does not hold the data a
screen needs, that is recorded before building, not drawn around.

Sections are linked: a task, a payment, an offer and a guest lead to each other
through real data and real routes. A list of unconnected screens is a defect.

## Visual Foundations

### Color

Feature code uses `AarastV3Color` roles or `context.accent`, never a hex value.

| Role | Value | Use |
| --- | --- | --- |
| `canvas` | `#F2F4F3` | Screen background |
| `paper` | `#FFFFFF` | Cards |
| `paperQuiet` | `#F7F8F8` | Quiet fills |
| `ink` / `text` | `#13211F` | Main text |
| `textMuted` | `#55625E` | Secondary text |
| `textFaint` | `#8A9592` | Hints only |
| `line` / `lineStrong` | `#E2E7E5` / `#C9D1CE` | Dividers and field edges |
| `primary` | `#0B6E69` | The identity, main actions |
| `primaryDark` | `#064B47` | The countdown card's deep end |
| `primarySoft` | `#DCEFEC` | Soft fills |
| `brandAccentStrong` | `#9A5F0E` | Saffron as text, the tasks section |
| `brandAccentSoft` | `#FCEFD8` | Saffron fill |
| `saffron` | `#F2A93B` | Decoration only, never text on paper |
| `cobalt` | `#2F6E9E` | The providers section |
| `lilac` | `#6A4FA3` | The guests section, tentative states |
| `mint` | `#25774F` | Done, good |
| `danger` | `#B8432A` | Overdue, short, destructive |
| `rose` | `#B4536A` | The bride's identity |

Section colours are fixed: home and money take the plan's colour (teal for the
groom, rose for the bride), tasks are saffron, guests lilac, providers cobalt.
Status colour always comes with text or an icon. One gradient exists, the
countdown card (D45).

### Typography

Tajawal is the app's text family (`JourneyType.family`). Sizes come from
`JourneyType`; a screen never passes a number, and a test fails if one does.
The text scale on top stops at 1.3 (`DevicePreferences.textScalerFor`).

Numbers, dates and phone values keep their direction inside RTL text.

### Spacing And Shape

- Spacing scale `AarastV3Space`: 4, 8, 12, 16, 20, 24, 32, 40, 48.
- The screen edge is 20 (`AarastV3Density.pageHorizontal`).
- Radius roles: control 12, surface 16, card 22, sheet 28, feature 30, pill 999.
- Touch targets are at least 48.
- Main actions are at least 52 tall.
- Every sheet is `showJourneySheet` with a `JourneySheetBody`.

New code takes spacing and radius from these constants. A ratchet test stops
new hand-written numbers in `lib/features`; the existing ones are cleaned when
their screen is touched (`test/core/widgets/aarast_design_ratchet_test.dart`).

### Motion

Quick 120ms, standard 220ms, deliberate 360ms (`AarastV3Motion`). Motion explains
a change; it never decorates, and it respects reduced motion.

## Navigation

Five tabs: الرئيسية، المال، المهام، الضيوف، المزودين. The participant and the
provider have their own shells on the same foundations.

The floating «+» stays by the owner's order (D33). Its page must keep enough
bottom space that it never covers content
(`AarastV3Density.pageBottomWithQuickAction`).

A screen pushed from inside the plan shell must not push a second copy of the
shell.

## Truth And State

- Null is not zero. Hidden or forbidden data is not an empty result.
- A reminder is not a payment. A quote is not a booking.
- Counts, prices and progress are never invented to fill a composition.
- Loading, empty, error, offline, locked and read-only are designed states, not
  afterthoughts. A failed load never reads as «ما عندك شي».
- Private money stays absent unless `canViewMoney` permits it; write controls
  stay absent unless the matching write permission permits them.

## Accessibility And Arabic

- RTL is the composition default, not a final mirroring pass.
- Icon-only controls need a tooltip or a semantic label.
- Text scaling must not clip totals, navigation or a main action.
- Text roles meet AA contrast on their intended surface.
- Every screen holds at 320px and at 420px wide without clipping or sideways
  scrolling.
- Words follow the reader's gender and never expose an enum or an API name.

## Verification

A screen is done with three proofs: checks run, a shot from the real app with
real data, and a walk with the user's eyes. Updating a golden without looking at
the routed screen proves nothing. Goldens run on Windows only and most of them
render prototypes, so they are not a gate for logic; the journey walks in
`mobile/integration_test/journeys` are.
