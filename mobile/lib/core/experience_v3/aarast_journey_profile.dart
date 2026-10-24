import 'package:flutter/widgets.dart';

import 'aarast_v3_foundations.dart';

/// Whose wedding the open plan is: the groom's or the bride's
/// (`docs/project/JOURNEY_PROFILE.md`).
///
/// The bride's path is the groom's, screen by screen; only three things
/// change, and all three are read from here: the plan's colour ([accent]),
/// the grammatical gender of the copy ([say]) and her items (the starter
/// catalogs, which take the plan's persona). Everything else stays shared.
enum JourneyProfile {
  groom(JourneyAccent.groom),
  bride(JourneyAccent.bride);

  const JourneyProfile(this.accent);

  /// The plan's own colour: teal for the groom, rose for the bride.
  final JourneyAccent accent;

  bool get isBride => this == JourneyProfile.bride;

  /// The plan persona the server and the phone plan store («GROOM»,
  /// «BRIDE»); anything else is the groom's profile.
  static JourneyProfile fromPersona(String? persona) =>
      persona?.trim().toUpperCase() == 'BRIDE'
      ? JourneyProfile.bride
      : JourneyProfile.groom;

  /// One string in its two forms: the groom's words (masculine address, his
  /// items) or the bride's (feminine address, her items).
  String say(String groom, String bride) => isBride ? bride : groom;
}

/// The plan's colour roles. Section colours (tasks, guests, providers) and
/// status colours are the same for both profiles and stay in
/// [AarastV3Color].
@immutable
class JourneyAccent {
  const JourneyAccent({
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.primaryMid,
    required this.onPrimaryMuted,
    required this.night,
  });

  /// The groom's teal (D0).
  static const groom = JourneyAccent(
    primary: AarastV3Color.primary,
    primaryDark: AarastV3Color.primaryDark,
    primarySoft: AarastV3Color.primarySoft,
    primaryMid: Color(0xFF7FC3BC),
    onPrimaryMuted: AarastV3Color.onPrimaryMuted,
    night: Color(0xFF0E2A33),
  );

  /// The bride's rose (JOURNEY_PROFILE.md §1).
  static const bride = JourneyAccent(
    primary: AarastV3Color.rose,
    primaryDark: Color(0xFF7A2E45),
    primarySoft: AarastV3Color.roseSoft,
    primaryMid: Color(0xFFE39AAE),
    onPrimaryMuted: AarastV3Color.roseSoft,
    night: Color(0xFF2E1624),
  );

  /// Main actions, links, the active tab and the plan's hero.
  final Color primary;

  /// The deep shade of the hero and its pressed states.
  final Color primaryDark;

  /// The plan's soft fill (selected chips, the money card).
  final Color primarySoft;

  /// The middle shade (the second budget segment, the lights' glow).
  final Color primaryMid;

  /// Quiet text on [primary].
  final Color onPrimaryMuted;

  /// The night sky behind the wedding lights and fireworks.
  final Color night;
}

/// Hands the open plan's profile to every screen, sheet and dialog below it.
///
/// The app root provides the selected plan's profile; a flow that makes a
/// plan (the welcome steps) provides the profile being chosen. Without a
/// scope the groom's profile applies, which keeps the provider portal, the
/// admin and the shared start screens on the app's teal.
class JourneyProfileScope extends InheritedWidget {
  const JourneyProfileScope({
    required this.profile,
    required super.child,
    super.key,
  });

  final JourneyProfile profile;

  static JourneyProfile of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<JourneyProfileScope>()
          ?.profile ??
      JourneyProfile.groom;

  @override
  bool updateShouldNotify(JourneyProfileScope oldWidget) =>
      profile != oldWidget.profile;
}

extension JourneyProfileContext on BuildContext {
  /// The open plan's profile.
  JourneyProfile get journeyProfile => JourneyProfileScope.of(this);

  /// The open plan's colour.
  JourneyAccent get accent => journeyProfile.accent;

  /// One string in its groom and bride forms (see [JourneyProfile.say]).
  String say(String groom, String bride) => journeyProfile.say(groom, bride);
}
