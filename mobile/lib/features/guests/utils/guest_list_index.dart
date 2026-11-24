import '../../../core/phone/phone_number_utils.dart';
import '../../../core/utils/arabic_sort.dart';
import '../models/guest.dart';

/// A plan's guests as the list screen reads them on every build
/// (RA-MO-363): each guest's search key, sort key and number digits worked
/// out once, the list in name order once, and who shares a number once. A
/// search was folding every name for every letter typed and sorting with
/// [arabicSortKey] inside the comparator: 82ms a letter for 1500 guests and
/// 258ms for 5000 on a desktop.
///
/// The index is built for one version of the list: the provider replaces
/// its list on every change, so [GuestListIndex.of] keeps the index while it
/// is handed the same list.
class GuestListIndex {
  GuestListIndex(
    this.weddingPlanId,
    this.source, {
    String Function(String name) searchKey = arabicSearchKey,
    String Function(String name) sortKey = arabicSortKey,
    String? Function(String? phone) phoneKey = PhoneNumberUtils.comparisonKey,
  }) {
    final entries = <_Entry>[
      for (final guest in source)
        if (guest.weddingPlanId == weddingPlanId)
          _Entry(
            guest,
            sortKey: sortKey(guest.name),
            searchKey: searchKey(guest.name),
            digits: _digitsOf(guest.phone),
          ),
    ];
    guests = [for (final entry in entries) entry.guest];
    entries.sort((a, b) {
      final byKey = a.sortKey.compareTo(b.sortKey);
      return byKey != 0 ? byKey : a.guest.name.compareTo(b.guest.name);
    });
    _sorted = entries;
    sorted = [for (final entry in entries) entry.guest];
    duplicates = _sharingANumber(guests, phoneKey);
  }

  /// The index for [source], the one kept in [previous] while [source] is
  /// the same list.
  static GuestListIndex of(
    GuestListIndex? previous,
    String weddingPlanId,
    List<Guest> source,
  ) {
    if (previous != null &&
        previous.weddingPlanId == weddingPlanId &&
        identical(previous.source, source)) {
      return previous;
    }
    return GuestListIndex(weddingPlanId, source);
  }

  final String weddingPlanId;

  /// The provider's whole list this index was built from.
  final List<Guest> source;

  /// The plan's guests, in the provider's order.
  late final List<Guest> guests;

  /// The plan's guests by name, as [compareArabicNames] orders them.
  late final List<Guest> sorted;

  /// The ids of guests who share a number with another guest.
  late final Set<String> duplicates;

  late final List<_Entry> _sorted;

  /// The guests whose name or number holds [query], by name.
  ///
  /// The name is matched on its search key, not letter for letter: typing
  /// «احمد» used to find no «أحمد», «عبدالله» no «عبد الله» and «فاطمه» no
  /// «فاطمة» — in a list of hundreds that reads as «the guest is not
  /// there». Both spellings are everyday, and the person typing cannot know
  /// which one was saved. A number is matched from three digits.
  List<Guest> search(String query) {
    final digits = _digitsOf(query);
    final name = arabicSearchKey(query);
    return [
      for (final entry in _sorted)
        if ((name.isNotEmpty && entry.searchKey.contains(name)) ||
            (digits.length >= 3 && entry.digits.contains(digits)))
          entry.guest,
    ];
  }

  static String _digitsOf(String? value) => PhoneNumberUtils.toAsciiDigits(
    value ?? '',
  ).replaceAll(RegExp(r'[^0-9]'), '');

  static Set<String> _sharingANumber(
    List<Guest> guests,
    String? Function(String? phone) phoneKey,
  ) {
    final firstByPhone = <String, String>{};
    final duplicates = <String>{};
    for (final guest in guests) {
      if (!guest.hasPhone) continue;
      final key = phoneKey(guest.phone);
      if (key == null) continue;
      final first = firstByPhone[key];
      if (first == null) {
        firstByPhone[key] = guest.id;
      } else {
        duplicates
          ..add(first)
          ..add(guest.id);
      }
    }
    return duplicates;
  }
}

class _Entry {
  _Entry(
    this.guest, {
    required this.sortKey,
    required this.searchKey,
    required this.digits,
  });

  final Guest guest;
  final String sortKey;
  final String searchKey;
  final String digits;
}
