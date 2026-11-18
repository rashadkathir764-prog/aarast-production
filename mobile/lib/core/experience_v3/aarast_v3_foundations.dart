import 'package:flutter/material.dart';

/// Foundations for the rebuilt Aarast mobile experience.
///
/// Feature code consumes semantic roles from this file (or the V3 barrel).
/// The identity is the groom journey's teal with saffron accents (DECISIONS
/// 2026-10-22, D0). Text roles stay AA-readable on paper (D1): the lighter
/// prototype shades are fills only.
abstract final class AarastV3Color {
  // A quiet green-grey canvas lets white cards read as the content.
  static const canvas = Color(0xFFF2F4F3);
  static const paper = Color(0xFFFFFFFF);
  static const paperQuiet = Color(0xFFF7F8F8);
  static const ink = Color(0xFF13211F);
  static const inkSoft = Color(0xFF23332F);
  static const text = Color(0xFF13211F);
  static const textMuted = Color(0xFF55625E);
  static const textFaint = Color(0xFF8A9592);
  static const line = Color(0xFFE2E7E5);
  static const lineStrong = Color(0xFFC9D1CE);

  // Aarast identity roles. Names stay semantic so feature code never grows a
  // second local palette.
  static const primary = Color(0xFF0B6E69);
  static const primaryDark = Color(0xFF064B47);
  static const primarySoft = Color(0xFFDCEFEC);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryMuted = Color(0xFFDCEFEC);
  // Saffron: the light shade reads on teal, the strong shade reads on paper.
  static const brandAccent = Color(0xFFFBDFA6);
  static const brandAccentStrong = Color(0xFF9A5F0E);
  static const brandAccentSoft = Color(0xFFFCEFD8);
  // Decoration only (the wordmark dot, the lights): never text on paper.
  static const saffron = Color(0xFFF2A93B);

  // Status colours, each a readable text shade with a soft fill.
  static const cobalt = Color(0xFF2F6E9E);
  static const cobaltSoft = Color(0xFFE0EEF8);
  static const signal = brandAccentStrong;
  static const signalSoft = brandAccentSoft;
  static const mint = Color(0xFF25774F);
  static const mintSoft = Color(0xFFDDF1E6);
  static const amber = Color(0xFF9A5F0E);
  static const amberSoft = Color(0xFFFCEFD8);
  // The bride's colour, kept for her theme (D2).
  static const rose = Color(0xFFB4536A);
  static const roseSoft = Color(0xFFF8E4EA);
  static const danger = Color(0xFFB8432A);
  static const dangerSoft = Color(0xFFFBE5DF);
  // Lilac marks tentative states («مبدئي») and the guests section.
  static const lilac = Color(0xFF6A4FA3);
  static const lilacSoft = Color(0xFFECE6F6);
}

/// The one spacing grid (D74): every padding, gap and margin is a step of 4.
/// [hair] and [half] are for hairlines and the tight gap between a title and
/// its line; nothing else sits off the grid.
abstract final class AarastV3Space {
  static const hair = 1.0;
  static const half = 2.0;
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
  static const x12 = 48.0;
  static const x16 = 64.0;
}

/// The corner roles (D74). A tag or a small mark takes [xs]; a field, a
/// button or a chip [control]/[surface]; a card [card]; a sheet or the
/// home's feature card [sheet]/[feature]; anything round [pill].
abstract final class AarastV3Radius {
  static const xs = 6.0;
  static const control = 12.0;
  static const surface = 14.0;
  static const card = 18.0;
  static const sheet = 24.0;
  static const feature = 24.0;
  static const pill = 999.0;
}

/// Icon sizes (D118): inline with text, in a row or a button, a lead icon,
/// and three for art (an empty state, a picture's stand-in, the app's mark).
/// No icon takes a size of its own.
abstract final class AarastV3Icon {
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const feature = 40.0;
  static const hero = 56.0;
}

/// What a control measures (D118): one height for each kind of control, so
/// the same kind of thing is the same size on every screen. A screen never
/// sets a control's height; the kit takes it from here.
abstract final class AarastV3Size {
  /// The least a finger touches (D74).
  static const touch = AarastV3Space.x12;

  /// Every field, typed, picked or a phone: a small label over one line.
  static const field = 56.0;

  /// A typed amount, read large.
  static const fieldAmount = 64.0;

  /// Every button, and the search bar.
  static const action = AarastV3Space.x12;

  /// A chip as drawn; it is touched in a [touch] band.
  static const chip = 36.0;

  /// One box of a sign-in code.
  static const codeBox = field;

  /// A list row at its least.
  static const row = field;

  /// A tab of the bottom bar, above the system's gesture area.
  static const navigationTab = field;

  /// A day in a month's calendar.
  static const calendarDay = field;

  /// A mark (D118): a face, an icon on its tile, a logo, a round button. Four
  /// sizes: in a dense row, in a row, on a card or an empty state, and the
  /// one on a profile.
  static const markSmall = 32.0;
  static const mark = AarastV3Space.x10;
  static const markLarge = 56.0;
  static const markHero = 72.0;

  /// A status dot, and a legend's swatch.
  static const dot = AarastV3Space.x2;
  static const swatch = AarastV3Space.x3;

  /// A tick box or a choice circle.
  static const check = AarastV3Space.x6;

  /// A progress bar's thickness, and an accent rule's width.
  static const bar = 6.0;
  static const rule = AarastV3Space.x1;

  /// A sheet's handle.
  static const handleWidth = AarastV3Space.x10;
  static const handleHeight = AarastV3Space.x1;

  /// A door on the first screen (D75).
  static const door = markHero;

  /// The floating «+» (D33).
  static const quickAction = 52.0;

  /// The most lines a row's or a card's title takes; the rest is cut with
  /// an ellipsis and read in full on the page it opens (D118).
  static const titleLines = 2;

  /// A hairline edge, and the edge of something chosen, focused or wrong.
  static const line = AarastV3Space.hair;
  static const lineStrong = AarastV3Space.half;

  /// The person's card on the first screens (D75), and its picture.
  static const personaCard = 112.0;
  static const personaPicture = 96.0;

  /// A small chart in a row (the dues ahead).
  static const chart = markLarge;

  /// An on/off switch.
  static const toggleWidth = 44.0;
  static const toggleHeight = 26.0;
}

/// What a picture or a band of art measures (D118): a share of the width it
/// sits in, never a fixed height, so it keeps its proportion on a small and a
/// large phone and never takes half the screen. A frame that carries words
/// grows when the words need more ([JourneyArtFrame]).
abstract final class AarastV3Media {
  /// A photo: a provider's cover, a gallery picture, an invitation card.
  static const photo = 16 / 9;

  /// A photo in a card that sits beside others (a shelf of providers).
  static const cardPhoto = 16 / 10;

  /// A band of art over or under words (the wedding sky, a moment).
  static const band = 2.0;

  /// A slimmer band (the sky over a short question, an empty picture slot).
  static const slimBand = 5 / 2;

  /// An art card that carries its words on it (the wedding week, the day).
  static const feature = 4 / 3;

  /// The most of the screen's height a preview (a whole invitation card, a
  /// message to share) takes before it scrolls.
  static const previewShare = 0.4;

  /// A logo or a face: in a row, on a card, on a profile ([AarastV3Size]'s
  /// marks).
  static const logoSmall = AarastV3Size.mark;
  static const logo = AarastV3Size.markLarge;
  static const logoLarge = AarastV3Size.markHero;
}

/// One field for every form (D74): the kit's [JourneyTextField] and the
/// Material fields of the theme draw the same box, padding and corner.
abstract final class AarastV3Field {
  static const radius = AarastV3Radius.surface;

  /// Inside the kit's labelled box: the small label over the value, the box
  /// at least [AarastV3Size.field] tall.
  static const padding = EdgeInsets.symmetric(
    horizontal: AarastV3Space.x4,
    vertical: AarastV3Space.x2,
  );

  /// The label's line, kept tight so label and value fit the field.
  static const labelHeight = AarastV3Line.tight;

  /// The value's line.
  static const valueHeight = AarastV3Line.normal;

  /// Inside a Material field, which carries its label in the line.
  static const contentPadding = EdgeInsets.symmetric(
    horizontal: AarastV3Space.x4,
    vertical: AarastV3Space.x3,
  );

  /// Between a field's icon and its text.
  static const iconGap = AarastV3Space.x2;

  /// Between two fields of a form.
  static const gap = AarastV3Space.x3;
}

/// Line heights (D118): three, and a fourth for a big numeral. No text sets
/// its own.
abstract final class AarastV3Line {
  /// A big number set on its own line.
  static const numeral = 0.95;

  /// Titles, figures and one-line labels.
  static const tight = 1.2;

  /// Running text: the default of JourneyType.of.
  static const normal = 1.35;

  /// A paragraph of several lines (a note, a description).
  static const reading = 1.5;
}

abstract final class AarastV3Motion {
  static const quick = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 220);
  static const deliberate = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;
}

/// Density rules shared by every routed Mobile archetype.
///
/// These values keep the first real decision above the fold and prevent every
/// feature from inventing its own vertical rhythm.
abstract final class AarastV3Density {
  static const pageHorizontal = AarastV3Space.x4;

  /// The widest a page's column reads on a tablet or a wide window (D118):
  /// one width for every screen, never a number of its own.
  static const readableWidth = 560.0;

  /// The widest a centred panel reads (a lock pad, a toast, an empty state).
  static const narrowWidth = 400.0;
  static const pageTop = AarastV3Space.x3;
  static const pageBottom = 112.0;
  // Root plan tabs carry the floating «+» above the tabs (D33). Their lists
  // need enough trailing space for the last row to scroll clear of it.
  static const pageBottomWithQuickAction = 184.0;
  static const sectionGap = AarastV3Space.x4;
  static const compactGap = AarastV3Space.x3;
  static const rowMinHeight = AarastV3Size.row;
  static const metricMinHeight = 72.0;

  /// A scrolling screen's body: the gutter on each side, a step under the
  /// header, and room to scroll the last row clear (D74).
  static const pageInsets = EdgeInsets.fromLTRB(
    pageHorizontal,
    AarastV3Space.x2,
    pageHorizontal,
    AarastV3Space.x8,
  );

  /// Inside a chip or a choice pill.
  static const chipInsets = EdgeInsets.symmetric(
    horizontal: AarastV3Space.x3,
    vertical: AarastV3Space.x2,
  );

  /// Inside a small status tag.
  static const tagInsets = EdgeInsets.symmetric(
    horizontal: AarastV3Space.x3,
    vertical: AarastV3Space.x1,
  );

  /// The main action pinned under a screen or a form (D74).
  static const actionInsets = EdgeInsets.fromLTRB(
    pageHorizontal,
    AarastV3Space.x2,
    pageHorizontal,
    AarastV3Space.x3,
  );
}

abstract final class AarastV3Type {
  static const bodyFamily = 'Tajawal';
  static const displayFamily = 'IBMPlexSansArabic';

  static TextStyle display(BuildContext context) =>
      Theme.of(context).textTheme.displaySmall!.copyWith(
        color: AarastV3Color.ink,
        fontFamily: displayFamily,
        fontWeight: FontWeight.w700,
        height: AarastV3Line.tight,
        letterSpacing: -0.3,
      );

  static TextStyle title(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!.copyWith(
        color: AarastV3Color.ink,
        fontFamily: displayFamily,
        fontWeight: FontWeight.w700,
        height: AarastV3Line.tight,
      );

  static TextStyle section(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(
        color: AarastV3Color.ink,
        fontWeight: FontWeight.w800,
        height: AarastV3Line.tight,
      );

  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
        color: AarastV3Color.textMuted,
        fontWeight: FontWeight.w500,
        height: AarastV3Line.reading,
      );

  static TextStyle label(BuildContext context) => Theme.of(context)
      .textTheme
      .labelMedium!
      .copyWith(color: AarastV3Color.textMuted, fontWeight: FontWeight.w700);
}
