import '../../../core/contacts/contact_duplicate_utils.dart';
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
/// place on the line. Lines without a name are skipped.
List<({String name, String? phone})> parseGuestLines(String text) {
  final people = <({String name, String? phone})>[];
  for (final raw in text.split('\n')) {
    final line = PhoneNumberUtils.toAsciiDigits(raw).trim();
    if (line.isEmpty) continue;
    final match = _phonePattern.firstMatch(line);
    final phone = match?.group(0)?.replaceAll(RegExp(r'[\s-]'), '');
    final name =
        (match == null ? line : line.replaceRange(match.start, match.end, ' '))
            .replaceAll(RegExp(r'[,،:؛;|\-–.]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (name.isEmpty) continue;
    people.add((name: name, phone: phone));
  }
  return people;
}

/// Marks who the plan already has, and who repeats within the list itself.
List<GuestCandidate> markGuestCandidates(
  List<({String name, String? phone})> people,
  List<Guest> existing,
) {
  final seen = <String>{};
  final candidates = <GuestCandidate>[];
  for (final listed in people) {
    final person = (name: _withinGuestName(listed.name), phone: listed.phone);
    final raw = person.phone?.trim() ?? '';
    final phone = PhoneNumberUtils.comparisonKey(raw);
    final clean = (name: person.name, phone: phone);
    candidates.add(
      GuestCandidate(
        name: person.name,
        phone: phone,
        badPhone: raw.isNotEmpty && phone == null ? raw : null,
        existing: _samePhone(clean, existing),
        sameName: _sameNameWithoutPhone(clean, existing),
        repeated: !seen.add(
          phone ?? 'name:${ContactDuplicateUtils.normalizeName(person.name)}',
        ),
      ),
    );
  }
  return candidates;
}

Guest? _samePhone(({String name, String? phone}) person, List<Guest> existing) {
  if ((person.phone ?? '').trim().isEmpty) return null;
  return ContactDuplicateUtils.findByPhone(
    existing,
    candidatePhone: person.phone!,
    phoneOf: (guest) => guest.phone,
  );
}

Guest? _sameNameWithoutPhone(
  ({String name, String? phone}) person,
  List<Guest> existing,
) {
  if ((person.phone ?? '').trim().isNotEmpty) return null;
  for (final guest in existing) {
    if (!guest.hasPhone &&
        ContactDuplicateUtils.sameName(guest.name, person.name)) {
      return guest;
    }
  }
  return null;
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
