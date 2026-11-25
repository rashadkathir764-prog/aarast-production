import '../../../core/phone/phone_number_utils.dart';
import 'plan_role_permissions.dart';

/// The ready roles of g01 and g06, each one of today's backend roles (C63).
/// «العروسة» and «كاتب الرفد» are not offered: the partner role sees money
/// and the rafd book is not built.
enum ParticipantPreset {
  helper('HELPER', 'مساعد', 'المهام والضيوف والمزودين'),
  family('FAMILY', 'أهل', 'المهام والضيوف، ويشوف المال إذا سمحت'),
  viewer('VIEWER', 'يشوف بس', 'يشوف الخطة، وما يعدّل شي');

  const ParticipantPreset(this.role, this.label, this.description);

  final String role;
  final String label;
  final String description;

  /// The flags the server gives this role by default.
  PlanRolePermissions get permissions => PlanRolePermissions.forRole(role);

  static ParticipantPreset? ofRole(String role) {
    for (final preset in values) {
      if (preset.role == role) return preset;
    }
    return null;
  }
}

/// «يشوف بس» edits nothing: the server refuses it with any editing right
/// (J2-05, D52). The editor still let the owner open «يعدّل» for a viewer,
/// and the save came back with a refusal that did not say what to change
/// (RA-MO-269). Opening an editing level for a viewer makes them «مساعد»,
/// which is what the owner has just described; the chip moves with it.
String participantRoleForLevels(String role, PlanRolePermissions levels) {
  if (role != 'VIEWER') return role;
  final edits =
      levels.canManageTasks ||
      levels.canManageGuests ||
      levels.canManageProviders ||
      levels.canManageMoney;
  return edits ? ParticipantPreset.helper.role : role;
}

/// Money has three levels; the other sections have two (g06).
enum MoneyLevel { none, view, manage }

extension ParticipantLevels on PlanRolePermissions {
  MoneyLevel get moneyLevel => canManageMoney
      ? MoneyLevel.manage
      : canViewMoney
      ? MoneyLevel.view
      : MoneyLevel.none;

  PlanRolePermissions withMoneyLevel(MoneyLevel level) => copyWith(
    canManageMoney: level == MoneyLevel.manage,
    canViewMoney: level != MoneyLevel.none,
  );
}

/// The one line under a participant's name, built from the stored flags
/// (g01): «المهام والضيوف · بدون المال». Critique ش1: said without a verb,
/// so it reads right under «أم العريس» as under «أخو العريس» (it was «يساعد…
/// يشوف المال» for everyone).
String participantSummary(PlanRolePermissions permissions) {
  final sections = [
    if (permissions.canManageTasks) 'المهام',
    if (permissions.canManageGuests) 'الضيوف',
    if (permissions.canManageProviders) 'المزودين',
  ];
  final money = switch (permissions.moneyLevel) {
    MoneyLevel.manage => 'تسجيل في المال',
    MoneyLevel.view => 'مع المال',
    MoneyLevel.none => 'بدون المال',
  };
  if (sections.isEmpty) {
    // One name per role: the viewer is «يشوف بس» everywhere («متابعة بس»
    // stood beside it).
    return permissions.moneyLevel == MoneyLevel.none
        ? ParticipantPreset.viewer.label
        : money;
  }
  return '${sections.join(' و')} · $money';
}

/// An invite's role said to the one invited before we know who they are
/// (D75). One name per role: the role's own name, as the owner's list says
/// it beside a man's or a woman's name («دورك: مساعد», «دورك: يشوف بس»);
/// «مساعدة في الترتيب» and «متابعة بس» were second names for the same roles.
String participantRoleDuty(String? role) => switch (role) {
  'FAMILY' => 'دورك: من الأهل',
  'HELPER' => 'دورك: ${ParticipantPreset.helper.label}',
  'VIEWER' => 'دورك: ${ParticipantPreset.viewer.label}',
  'CONTRIBUTOR' => 'دورك: مساهمة في الترتيب',
  'MANAGER' => 'دورك: إدارة الخطة',
  'GROOM' || 'BRIDE' => 'دورك: شراكة في الخطة',
  _ => 'دورك: مشاركة في الخطة',
};

/// The role word beside a participant's name.
String participantRoleLabel(String role) {
  final preset = ParticipantPreset.ofRole(role);
  if (preset != null) return preset.label;
  return switch (role) {
    'OWNER' => 'صاحب الخطة',
    'GROOM' => 'شريك',
    // «العروسة · شريك» said a woman in the masculine.
    'BRIDE' => 'شريكة',
    'MANAGER' => 'مدير',
    'CONTRIBUTOR' => 'مساهم',
    _ => 'مشارك',
  };
}

/// «أنت مساعد» beside the plan's name on a participant's own screens; a
/// bride's plan speaks to a woman («أنتِ مساعدة», q17). The role words are
/// said about someone («يشوف بس» beside a name), so a sentence to the
/// participant turns the same word to them: «أنت تشوف بس», «أنت من الأهل».
String participantRoleTag(String? role, {bool feminine = false}) =>
    '${feminine ? 'أنتِ' : 'أنت'} '
    '${participantOwnRoleWord(role, feminine: feminine)}';

/// The reader's own role as a short word, said to them as who they are:
/// «مساعدة», «من الأهل», «تشوفين بس». «حسابي» showed a woman the
/// third-person «مساعد» and «يشوف بس» (RA-MO-277); «تتابع بس» was a second
/// name for «يشوف بس».
String participantOwnRoleWord(String? role, {bool feminine = false}) =>
    switch (role) {
      'VIEWER' => feminine ? 'تشوفين بس' : 'تشوف بس',
      'FAMILY' => 'من الأهل',
      'HELPER' => feminine ? 'مساعدة' : 'مساعد',
      'CONTRIBUTOR' => feminine ? 'مساهمة' : 'مساهم',
      'MANAGER' => feminine ? 'مديرة' : 'مدير',
      'GROOM' || 'BRIDE' => feminine ? 'شريكة' : 'شريك',
      _ => feminine ? 'مشاركة' : 'مشارك',
    };

/// «لأمينة», «للوالد»: «ل» joined to a name, the article's alif dropped
/// («لـالوالد» is not written).
String toPerson(String name) {
  final value = name.trim();
  if (value.startsWith('ال')) return 'ل${value.substring(1)}';
  return 'لـ$value';
}

/// «771 554 220»: a Yemeni mobile the way it is read out at home; any other
/// number as it is displayed elsewhere.
String? participantPhone(String? phone) {
  final display = PhoneNumberUtils.display(phone);
  if (display == null) return null;
  // The display joins its groups with no-break spaces (D118).
  const prefix = '+967\u00a0';
  return display.startsWith(prefix)
      ? display.substring(prefix.length)
      : display;
}
