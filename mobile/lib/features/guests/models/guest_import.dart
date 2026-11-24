import '../../../core/contacts/contact_duplicate_utils.dart';
import '../../../core/utils/arabic_sort.dart';
import '../../../core/utils/text_limits.dart';
import '../../../core/phone/phone_number_utils.dart';
import 'guest.dart';

/// One person about to be added, and whether they would be added twice.
class GuestCandidate {
  const GuestCandidate({
    required this.name,
    this.phone,
    this.existing,
    this.sameName,
    this.repeated = false,
    this.badPhone,
  });

  final String name;

  /// The normalized number, or null when there is none or it is not valid.
  final String? phone;

  /// What was written as a number but is not one; the guest is added
  /// without it rather than failing the whole list.
  final String? badPhone;

  /// The guest already in the plan with this number: the same person.
  final Guest? existing;

  /// A guest in the plan with the same name, neither with a number: maybe
  /// the same person, maybe another (two «أحمد علي» are common). Whoever adds
  /// decides (RA-MO-61: it was refused as «موجود من قبل»).
  final Guest? sameName;

  /// The same person appears earlier in the same list.
  final bool repeated;

  bool get isDuplicate => existing != null || repeated;
}

final _phonePattern = RegExp(r'\+?\d[\d\s-]{5,}\d');

/// RA-BE-15: a guest's name stops where the server's does (GUEST_NAME_MAX,
/// counted as the phone counts). A contact or a pasted line longer than that
/// was refused by the server and held the queued import as «السيرفر رفضه».
const guestNameMaxCharacters = 120;

String _withinGuestName(String name) =>
    clipToCharacters(name.trim(), guestNameMaxCharacters);

/// w28: a pasted list, one person per line, the number optional and in any
/// place on the line. Lines without a name are skipped
/// ([unnamedGuestLines] counts them, so the screen says so).
List<({String name, String? phone})> parseGuestLines(String text) {
  final people = <({String name, String? phone})>[];
  for (final raw in text.split('\n')) {
    final line = _parseLine(raw);
    if (line == null || line.name.isEmpty) continue;
    people.add(line);
  }
  return people;
}

/// RA-MO-231: the pasted lines that hold a number and no name, which
/// [parseGuestLines] leaves out; they fell away with no word.
int unnamedGuestLines(String text) => text
    .split('\n')
    .map(_parseLine)
    .where((line) => line != null && line.name.isEmpty)
    .length;

/// One pasted line: its first number is the phone, and no number stays in
/// the name (RA-MO-231: a second one did). Null for a blank line.
({String name, String? phone})? _parseLine(String raw) {
  final line = PhoneNumberUtils.toAsciiDigits(raw).trim();
  if (line.isEmpty) return null;
  final match = _phonePattern.firstMatch(line);
  final phone = match?.group(0)?.replaceAll(RegExp(r'[\s-]'), '');
  final name = line
      .replaceAll(_phonePattern, ' ')
      .replaceAll(RegExp(r'[,،:؛;|/\\\-–.]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return (name: name, phone: phone);
}

/// How a number is compared: [PhoneNumberUtils.comparisonKey]; tests pass
/// one that counts.
typedef GuestPhoneKey = String? Function(String? phone);

/// The plan's guests as an import compares them (RA-MO-362): each number
/// normalised once, into a map, instead of once for every contact.
class GuestMatchIndex {
  GuestMatchIndex(
    List<Guest> guests, {
    GuestPhoneKey phoneKey = PhoneNumberUtils.comparisonKey,
  }) {
    for (final guest in guests) {
      if (guest.hasPhone) {
        final key = phoneKey(guest.phone);
        if (key != null) _byPhone.putIfAbsent(key, () => guest);
      } else {
        final name = ContactDuplicateUtils.normalizeName(guest.name);
        if (name.isNotEmpty) {
          _byNameWithoutPhone.putIfAbsent(name, () => guest);
        }
      }
    }
  }

  /// The first guest with each number, in the list's order.
  final _byPhone = <String, Guest>{};

  /// The first guest without a number for each name as compared.
  final _byNameWithoutPhone = <String, Guest>{};

  /// The guest already in the plan with this normalized number.
  Guest? withPhone(String phoneKey) => _byPhone[phoneKey];

  /// A guest without a number whose name, as compared, is [normalizedName].
  Guest? withNameOnly(String normalizedName) =>
      normalizedName.isEmpty ? null : _byNameWithoutPhone[normalizedName];
}

/// Marks who the plan already has, and who repeats within the list itself.
List<GuestCandidate> markGuestCandidates(
  List<({String name, String? phone})> people,
  List<Guest> existing, {
  GuestPhoneKey phoneKey = PhoneNumberUtils.comparisonKey,
}) => markAgainst(
  people,
  GuestMatchIndex(existing, phoneKey: phoneKey),
  phoneKey: phoneKey,
);

/// [markGuestCandidates] against an index already built for the plan: one
/// normalisation per person listed.
List<GuestCandidate> markAgainst(
  List<({String name, String? phone})> people,
  GuestMatchIndex plan, {
  GuestPhoneKey phoneKey = PhoneNumberUtils.comparisonKey,
}) {
  final seen = <String>{};
  final candidates = <GuestCandidate>[];
  for (final listed in people) {
    final name = _withinGuestName(listed.name);
    final raw = listed.phone?.trim() ?? '';
    final phone = raw.isEmpty ? null : phoneKey(raw);
    final nameKey = ContactDuplicateUtils.normalizeName(name);
    candidates.add(
      GuestCandidate(
        name: name,
        phone: phone,
        badPhone: raw.isNotEmpty && phone == null ? raw : null,
        existing: phone == null ? null : plan.withPhone(phone),
        sameName: phone == null ? plan.withNameOnly(nameKey) : null,
        repeated: !seen.add(phone ?? 'name:$nameKey'),
      ),
    );
  }
  return candidates;
}

/// The import's list kept between builds (RA-MO-362). The plan's index is
/// built once per guests version (the provider replaces its list on every
/// change, so the same list is the same version), and the candidates once
/// per (people version, guests version): a tick or a letter typed in the
/// search changes neither.
class GuestImportMatcher {
  GuestImportMatcher(
    this.weddingPlanId, {
    this.phoneKey = PhoneNumberUtils.comparisonKey,
  });

  final String weddingPlanId;
  final GuestPhoneKey phoneKey;

  List<Guest>? _allGuests;
  List<Guest> _planGuests = const [];
  GuestMatchIndex? _index;

  Object? _peopleVersion;
  List<Guest>? _listGuests;
  GuestImportList? _list;

  /// The plan's guests out of [allGuests], the provider's whole list.
  List<Guest> guestsOf(List<Guest> allGuests) {
    if (!identical(allGuests, _allGuests)) {
      _allGuests = allGuests;
      _planGuests = [
        for (final guest in allGuests)
          if (guest.weddingPlanId == weddingPlanId) guest,
      ];
      _index = null;
    }
    return _planGuests;
  }

  /// [people] marked against the plan. [peopleVersion] is what they are
  /// read from (the contacts list, the pasted text), compared by `==`.
  GuestImportList listFor({
    required Object peopleVersion,
    required List<({String name, String? phone})> Function() people,
    required List<Guest> allGuests,
  }) {
    final guests = guestsOf(allGuests);
    final kept = _list;
    if (kept != null &&
        _peopleVersion == peopleVersion &&
        identical(_listGuests, allGuests)) {
      return kept;
    }
    final index = _index ??= GuestMatchIndex(guests, phoneKey: phoneKey);
    _peopleVersion = peopleVersion;
    _listGuests = allGuests;
    return _list = GuestImportList(
      markAgainst(people(), index, phoneKey: phoneKey),
    );
  }
}

/// The candidates with what the screen reads of them on every build, each
/// worked out once: every name's search key, and the families.
class GuestImportList {
  GuestImportList(this.candidates)
    : searchKeys = [
        for (final candidate in candidates) arabicSearchKey(candidate.name),
      ];

  final List<GuestCandidate> candidates;

  /// [arabicSearchKey] of each candidate's name, by position.
  final List<String> searchKeys;

  /// [groupByFamily] of the names; only the contacts list reads it.
  late final List<({String? family, List<int> members})> families =
      groupByFamily([for (final candidate in candidates) candidate.name]);
}

/// e03 «آل الحمدي»: the family a contact belongs to, read from the last
/// word of the name when it is a family name (starts with «ال»).
String? guestFamilyOf(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.length < 2) return null;
  final last = words.last;
  return last.startsWith('ال') && last.length > 3 ? 'آل $last' : null;
}

/// Contacts in families of two or more, the rest together at the end.
List<({String? family, List<int> members})> groupByFamily(List<String> names) {
  final families = <String, List<int>>{};
  for (var i = 0; i < names.length; i++) {
    final family = guestFamilyOf(names[i]);
    if (family != null) (families[family] ??= []).add(i);
  }
  final grouped = <int>{};
  final sections = <({String? family, List<int> members})>[];
  final keys = families.keys.toList()..sort();
  for (final family in keys) {
    final members = families[family]!;
    if (members.length < 2) continue;
    grouped.addAll(members);
    sections.add((family: family, members: members));
  }
  final rest = [
    for (var i = 0; i < names.length; i++)
      if (!grouped.contains(i)) i,
  ];
  if (rest.isNotEmpty) sections.add((family: null, members: rest));
  return sections;
}
