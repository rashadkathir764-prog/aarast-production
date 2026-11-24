# Aarast Adaptive Experience System V3

Snapshot date: 2026-10-31

Status: the one active Mobile design reference. The look is **frozen on
«فيروز»** until the first real users are on the app (AGENTS.md, D67).

Where this file and the code disagree, the code in the boundary below wins and
this file is corrected in the same change.

## Product Direction

Aarast is an Arabic-first wedding planning workspace whose centre is the money.
It should feel calm and useful: a quiet grey-green canvas, white cards, and one
colour for the whole plan across every tab (D68).

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
| `textFaint` | `#66726F` | Hints only (4.5:1 on the canvas, D124) |
| `line` / `lineStrong` | `#E2E7E5` / `#838E8B` | Dividers / the edge of a field (3:1 on paper and canvas, D124) |
| `primary` | `#0B6E69` | The identity, main actions |
| `primaryDark` | `#064B47` | The countdown card's deep end |
| `primarySoft` | `#DCEFEC` | Soft fills |
| `brandAccentStrong` | `#9A5F0E` | Saffron as text: attention and waiting |
| `brandAccentSoft` | `#FCEFD8` | Saffron fill |
| `saffron` | `#F2A93B` | Decoration only, never text on paper |
| `cobalt` | `#2F6E9E` | Money and event categories only, never a tab |
| `lilac` | `#6A4FA3` | Tentative states such as promised money, never a tab |
| `mint` | `#25774F` | Done, good |
| `danger` | `#B8432A` | Overdue, short, destructive |
| `rose` | `#B4536A` | The bride's identity |

One colour per plan (D68): every tab and its actions take the plan's colour,
`context.accent` (teal for the groom, rose for the bride). No tab has a colour
of its own. Other colours carry a status or a category, never a section.
Status colour always comes with text or an icon. One gradient exists, the
countdown card (D45).

### Typography

Tajawal is the app's text family (`JourneyType.family`). Sizes come from
`JourneyType`; a screen never passes a number, and a test fails if one does.
The app takes half of the phone's text size above normal, up to 1.15, and
«خط كبير» a step more, up to 1.3 (`DevicePreferences.textScalerFor`, D119).
Above a system size of 1.5 the system's own scaler passes through unchanged
(D126).

Numbers, dates and phone values keep their direction inside RTL text.

### Spacing And Shape

One system, one source (`aarast_v3_foundations.dart`, D74). The legacy
`AarastDesignTokens` names are aliases of it and add no values.

- Spacing grid `AarastV3Space`: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, plus
  `hair` 1 and `half` 2 for hairlines and a title's tight line. Nothing sits
  off the grid.
- Screen gutter 16 (`AarastV3Density.pageHorizontal`). A scrolling screen's
  body is `AarastV3Density.pageInsets` (16 · 8 · 16 · 32); the action pinned
  under a screen or form is `actionInsets` (16 · 8 · 16 · 12); a chip is
  `chipInsets` (12 · 8), a status tag `tagInsets` (12 · 4); a card is
  `EdgeInsets.all(AarastV3Space.x4)`.
- Radius roles `AarastV3Radius`: xs 6, control 12, surface 14, card 18,
  sheet 24 (the sheet shell keeps its 28 top), feature 24, pill 999.
- Icons `AarastV3Icon`: 16 inline, 20 in a row or field, 24 lead, and 32,
  40, 56 for art (an empty state, a picture's stand-in, the mark). No other
  icon size.
- Forms: one field (`JourneyFieldBox`, D118). Every field, typed
  (`JourneyTextField`, with `validator:` inside a `Form`), picked
  (`JourneyPickerField`), chosen from a list (`JourneyChoiceField`, a sheet
  of choices) or a phone (`JourneyPhoneField`), is the same white box: a
  hairline that turns the plan's colour at 2 on focus and coral on an
  error, a 14 corner, the small label over the value, and one height, 56
  (a typed amount 64). A tool at the end (the password eye) is a full 48
  inside it. Fields in a form are 12 apart. There is no other field.
- Type scale `JourneyType` (D118), nine roles for 360-400 wide phones:
  home count 52, count 32, hero 24 (a tab's title, a question, a typed
  amount), page title 19 (a pushed screen, a sheet, a figure in a card),
  lead 16 (a card's title, a field's value, a main action), body 14.5,
  small 12.5 (secondary lines, chips, a field's label), caption 11, badge 9.
  It was twenty-two sizes half a point apart. Line heights `AarastV3Line`:
  numeral 0.95, tight 1.2, normal 1.35, reading 1.5.

### Sizes (D118)

What a thing measures comes from the foundations, never from the screen. A
test (`test/core/widgets/aarast_size_ratchet_test.dart`) fails on any height,
width or size written as a number in `lib`, and on any named fixed height.

- Controls `AarastV3Size`: touch 48; a field 56, an amount 64; a button and
  the search bar 48; a chip drawn 36 in a 48 band; a list row at least 56; a
  bottom-bar tab 56; a calendar day 56; the floating «+» 52.
- Marks `AarastV3Size`: a face, an icon tile, a logo or a round button is 32
  (dense row), 40 (row), 56 (card, empty state) or 72 (profile). A dot 8, a
  swatch 12, a tick box 24, a bar 6, a rule 4, a line 1 and a strong line 2,
  a sheet's handle 40 x 4.
- Pictures `AarastV3Media`: a share of the width, never a fixed height. A
  photo 16:9 (a cover, a gallery picture), a card photo 16:10, a band 2:1
  (the sky, a moment), a slim band 5:2, a feature card 4:3. Art that carries
  words is a `JourneyArtFrame`: at least its ratio tall, taller only when the
  words need it. A preview (a whole invitation card) takes at most 40% of
  the screen's height.
- Page widths `AarastV3Density`: a page's column reads at most 560 wide
  (`readableWidth`, the screen frame's default; no screen passes its own), a
  centred panel 400 (`narrowWidth`).
- A row's or a card's title takes at most two lines (`titleLines`) and a
  secondary line one; the rest is read on the page it opens.
- A row with an end (an amount, a tag, an action) is a `JourneyEndRow`: the
  end takes what it needs, up to 40% of the row (an amount beside its title
  up to 50%), and the words the rest. The end is never scaled, so a button
  keeps its touch target; a figure in it may sit in a FittedBox.
- A button's words keep the reader's text size and wrap to a second line
  rather than shrink.
- An amount and a phone number never break across lines: every reading of
  the money formatter goes through `keepCurrencyOnLine`, and
  `PhoneNumberUtils.display` joins its groups with no-break spaces.
- The bottom bar (D117) rests on the screen's edge in the shape of the app's
  sheets; every tab is one width, its icon over its name, the chosen one
  filled in the plan's colour.

- Every sheet is `showJourneySheet` with a `JourneySheetBody`. A sheet
  wears the profile of the context that opens it; a screen whose own scope
  sits below its State passes `profile:`.

### Entry screens (D75)

The start, saving the plan, signing in, invites and the provider's sign-up
share one kit (`aarast_journey_entry.dart`) on top of the journey kit:

- `JourneyStepBar` (back, and the three questions' progress: done full,
  current half), `JourneyEntryQuestion` (question at hero 24, help at lead 16) and
  `JourneyEntryActions` (main button, and a second way out that keeps its
  room so the button never moves).
- `JourneyDoor` (72 high, 40 tile), `JourneyPersonaCard` (112 high, 96
  picture), `JourneySkyBand` (the wedding sky melting into the page, no
  gradient).
- `JourneyPhoneField`: one labelled field, +967 then the number left to
  right, grouped in threes as typed; `JourneyKeptPlanStrip`.
- `JourneyCodeHelpSheet` and `JourneyCodeResendRow` for every code screen.
- The journey kit took what these needed instead of copies: `JourneyNote`
  tones (`tinted`, `paper`, `warn`, `bare`), `JourneyTextAction.sub`,
  `JourneyListRow.subtitleMaxLines`, `JourneyButton.outline` and a readable
  disabled state (pale fill, grey words), `JourneyChip.large` (48, pill),
  `JourneyPickerField.iconAtEnd`, `JourneyTextField.trailing`.
- Fields 16, typed amounts 24. A bride's small text is `accent.primaryDark`.
- The profile: before an account, the plan kept on the phone gives the app
  its owner's colour and voice (`GuestOnboardingStorage.keptPlanPersona`
  at the root); a provider's sign-up and code are always the app's own
  (router); an invite wears its plan's colour and speaks to the one invited
  in words that fit a man or a woman.

No file in `lib` writes a spacing, radius or type-size number by hand
(`test/core/widgets/aarast_design_ratchet_test.dart`), nor a height, width or
size (`aarast_size_ratchet_test.dart`, D118): it takes a token. A width that
belongs to one layout (a label column) may be named, a fixed height may not.
Both counts are zero and the tests keep them zero.

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
