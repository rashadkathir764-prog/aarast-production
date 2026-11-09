import '../../../core/experience_v3/aarast_journey_profile.dart';
import '../../../core/utils/name_letter.dart';
import 'money_summary.dart';
import 'wedding_cost.dart' show moneyValue;

// G14 and D59: how the plan's people are named as payers, and how what they
// paid is said. One place, read by w20 «مين دفع ايش», c01's summary, c02's
// rows and the shared summary.

/// One payer group's key: its payer and the name written with it.
String payerKey(String? payer, String? payerName) =>
    '${payer ?? ''}|${payerName?.trim() ?? ''}';

/// The payer as the reader says it: «أنا» for the plan's own party when the
/// owner reads, the other party by their word, the family or someone else
/// by the name written with it.
String payerLabel(
  String? payer,
  String? payerName, {
  required bool bridePlan,
  required bool owner,
}) {
  final name = payerName?.trim();
  final named = name != null && name.isNotEmpty;
  return switch (payer) {
    'GROOM' => owner && !bridePlan ? 'أنا' : 'العريس',
    'BRIDE' => owner && bridePlan ? 'أنا' : 'العروسة',
    'FAMILY' => named ? name : 'الأهل',
    'SHARED' => 'المشترك',
    'OTHER' => named ? name : 'شخص ثاني',
    _ => 'ما تحدد',
  };
}

/// D59 (backend `paidFromOwnerMoney`): whether an agreement's payer pays
/// from the plan owner's own money: none written, a shared one, or the
/// plan's own side. Anyone else's rest is theirs, not «عليك».
bool payerIsOwner(String? payer, {required bool bridePlan}) =>
    payer == null ||
    payer.isEmpty ||
    payer == 'SHARED' ||
    payer == (bridePlan ? 'BRIDE' : 'GROOM');

/// J1-17, D59: on whom an agreement's rest is, as «الملخص» says it: the
/// owner's («عليك»; to a helper «عليه» or «عليها»), or the family's or
/// someone else's by the name written with it («على الوالد»).
String restOnWhom(String? payer, String? payerName, JourneyProfile profile) =>
    payerIsOwner(payer, bridePlan: profile.isBride)
    ? profile.ownerDid('عليك', 'عليك', groom: 'عليه', bride: 'عليها')
    : 'على ${payerLabel(payer, payerName, bridePlan: profile.isBride, owner: profile.readerIsOwner)}';

/// w20's line over a payer's total, its verb agreeing with who paid
/// («العروسة دفعت», «الأهل دفعوا», «الوالد دفع»); what is shared is said
/// without a doer («المدفوع المشترك»).
String payerPaidLine(String? payer, String label, JourneyProfile profile) {
  if (label == 'أنا') return profile.say('دفعت أنا', 'دفعتِ أنا');
  return switch (payer) {
    'BRIDE' => '$label دفعت',
    'FAMILY' when label == 'الأهل' => 'الأهل دفعوا',
    'SHARED' => 'المدفوع المشترك',
    null => 'ما تحدد مين دفع',
    _ => '$label دفع',
  };
}

/// The avatar's letter for a payer («الوالد» و).
String payerAvatarLetter(String label) => nameLetter(label);

/// D59: who paid for the plan's owner, as the server grouped them: the
/// groups whose money was not the owner's and that paid something.
List<MoneyPayerSummary> payersForOwner(MoneySummary summary) => [
  for (final group in summary.payers)
    if (!group.ownerMoney && moneyValue(group.paid) > 0) group,
];

/// «دفع عنك الوالد 1.3 مليون»: one payer who paid for the owner, the verb
/// first (a woman's payment «دفعت»), «عنك» to the owner and the owner's
/// pronoun to anyone else.
String paidForOwnerPhrase(
  MoneyPayerSummary group,
  String amount,
  JourneyProfile profile,
) {
  final label = payerLabel(
    group.payer,
    group.payerName,
    bridePlan: profile.isBride,
    owner: profile.readerIsOwner,
  );
  final verb = group.payer == 'BRIDE' ? 'دفعت' : 'دفع';
  final forWhom = profile.ownerDid('عنك', 'عنك', groom: 'عنه', bride: 'عنها');
  return '$verb $forWhom $label $amount';
}
