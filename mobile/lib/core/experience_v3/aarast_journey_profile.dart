import 'package:flutter/widgets.dart';

import 'aarast_v3_foundations.dart';

/// Whose wedding the open plan is, and who reads it
/// (`docs/project/JOURNEY_PROFILE.md`, B5).
///
/// The bride's path is the groom's, screen by screen; only three things
/// change. Two follow the plan: its colour ([accent]) and its words (her
/// items, her «ضيفات», [plan]). One follows the reader: the grammatical
/// gender the app speaks to them in ([say]). They are one and the same for
/// the owner of a groom's or a bride's plan; they part when a groom reads
/// the bride's plan or a bride the groom's (q09, q17): the plan keeps its
/// colours and words, and each reader is spoken to as who they are.
@immutable
class JourneyProfile {
  const JourneyProfile._({
    required this.isBride,
    required this.feminine,
    this.readerIsOwner = true,
  });

  /// The groom's plan, read by the groom.
  static const groom = JourneyProfile._(isBride: false, feminine: false);

  /// The bride's plan, read by the bride.
  static const bride = JourneyProfile._(isBride: true, feminine: true);

  /// The plan persona the server and the phone plan store («GROOM»,
  /// «BRIDE»), read by its own owner; anything else is the groom's profile.
  static JourneyProfile fromPersona(String? persona) =>
      _isBridePersona(persona) ? JourneyProfile.bride : JourneyProfile.groom;

  /// Whose plan it is ([planPersona]), who reads it ([readerFeminine]) and
  /// whether the reader is the plan's owner ([readerIsOwner]).
  static JourneyProfile of({
    required String? planPersona,
    required bool readerFeminine,
    bool readerIsOwner = true,
  }) => JourneyProfile._(
    isBride: _isBridePersona(planPersona),
    feminine: readerFeminine,
    readerIsOwner: readerIsOwner,
  );

  /// The bride's plan: her colour and her words.
  final bool isBride;

  /// The reader is spoken to in the feminine.
  final bool feminine;

  /// The reader owns the plan; a participant reads the owner's money with
  /// the owner named ([ownerDid]).
  final bool readerIsOwner;

  /// The plan's own colour: teal for the groom, rose for the bride.
  JourneyAccent get accent =>
      isBride ? JourneyAccent.bride : JourneyAccent.groom;

  /// The same plan, read by someone spoken to in [feminine]'s form.
  JourneyProfile readBy({required bool feminine}) => JourneyProfile._(
    isBride: isBride,
    feminine: feminine,
    readerIsOwner: readerIsOwner,
  );

  /// One sentence to the reader in its two forms: masculine or feminine
  /// address («سجّل», «سجّلي»).
  String say(String masculine, String feminine) =>
      this.feminine ? feminine : masculine;

  /// One of the plan's words in its two forms: the groom's (his items, his
  /// «ضيوف», his «القاعة») or the bride's.
  String plan(String groom, String bride) => isBride ? bride : groom;

  /// What the plan's owner did with the money, said to this reader (D59):
  /// to the owner in their own form («دفعت», «دفعتِ»), to anyone else with
  /// the owner named («العريس دفع», «العروسة دفعت»), never as if the reader
  /// had done it.
  String ownerDid(
    String masculine,
    String feminine, {
    required String groom,
    required String bride,
  }) => readerIsOwner ? say(masculine, feminine) : plan(groom, bride);

  static bool _isBridePersona(String? persona) =>
      persona?.trim().toUpperCase() == 'BRIDE';

  @override
  bool operator ==(Object other) =>
      other is JourneyProfile &&
      other.isBride == isBride &&
      other.feminine == feminine &&
      other.readerIsOwner == readerIsOwner;

  @override
  int get hashCode => Object.hash(isBride, feminine, readerIsOwner);

  @override
  String toString() =>
      'JourneyProfile(${isBride ? 'bride' : 'groom'} plan, '
      '${feminine ? 'feminine' : 'masculine'} reader'
      '${readerIsOwner ? '' : ', not its owner'})';
}

/// B5: how a reader is spoken to where the server has not said it: outside
/// a plan, or in a plan still kept on the phone. The account's own persona
/// (the person chose «عريس» or «عروسة»), else the plan's own party: the
/// bride's plan is the women's wedding, so the feminine. Inside a plan the
/// server resolves it once, the member's partner role included
/// (`readerForm`, `addressFormOf`, D59), and the phone takes that.
bool readerIsFeminine({String? accountPersona, String? planPersona}) {
  return switch (accountPersona?.trim().toUpperCase()) {
    'GROOM' => false,
    'BRIDE' => true,
    _ => planPersona?.trim().toUpperCase() == 'BRIDE',
  };
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
  /// The open plan's profile, with its reader.
  JourneyProfile get journeyProfile => JourneyProfileScope.of(this);

  /// The open plan's colour.
  JourneyAccent get accent => journeyProfile.accent;

  /// One sentence to the reader in its masculine and feminine forms (see
  /// [JourneyProfile.say]).
  String say(String masculine, String feminine) =>
      journeyProfile.say(masculine, feminine);

  /// One of the plan's words in its groom and bride forms (see
  /// [JourneyProfile.plan]).
  String planWord(String groom, String bride) =>
      journeyProfile.plan(groom, bride);

  /// What the plan's owner did, said to this reader (see
  /// [JourneyProfile.ownerDid]).
  String ownerDid(
    String masculine,
    String feminine, {
    required String groom,
    required String bride,
  }) => journeyProfile.ownerDid(
    masculine,
    feminine,
    groom: groom,
    bride: bride,
  );
}
