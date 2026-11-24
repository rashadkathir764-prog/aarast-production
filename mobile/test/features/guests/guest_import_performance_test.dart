import 'package:aarast_mobile/core/phone/phone_number_utils.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/models/guest_import.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-362: the import matched every contact against every guest, each
// number normalised again, on every build: 2000 contacts and 500 guests
// took 1348ms a build on a desktop, and every tick and letter rebuilt it.

Guest _guest(int i, {String? phone}) {
  final now = DateTime.utc(2026, 10, 15);
  return Guest(
    id: 'g$i',
    weddingPlanId: 'plan-1',
    name: 'ضيف $i',
    phone: phone,
    side: 'OTHER',
    status: 'INVITED',
    seatsCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}

List<Guest> _guests(int count) => [
  for (var i = 0; i < count; i++)
    _guest(i, phone: '+96777${1000000 + i * 37}'),
];

List<({String name, String? phone})> _contacts(int count) => [
  for (var i = 0; i < count; i++)
    (name: 'جهة $i', phone: '077${2000000 + i * 53}'),
];

void main() {
  test('each number is normalised once per guests and contacts version', () {
    var normalised = 0;
    String? counting(String? phone) {
      normalised++;
      return PhoneNumberUtils.comparisonKey(phone);
    }

    final matcher = GuestImportMatcher('plan-1', phoneKey: counting);
    final guests = [..._guests(5), _guest(99)];
    final contacts = _contacts(8);
    List<({String name, String? phone})> read() => contacts;

    final first = matcher.listFor(
      peopleVersion: contacts,
      people: read,
      allGuests: guests,
    );
    // Five guest numbers once into the index, eight contacts once each; the
    // guest without a number is matched by name, not normalised.
    expect(normalised, 5 + 8);

    // A rebuild (a tick, a letter in the search) reads the kept list.
    final again = matcher.listFor(
      peopleVersion: contacts,
      people: read,
      allGuests: guests,
    );
    expect(identical(again, first), isTrue);
    expect(normalised, 5 + 8);

    // Other people against the same guests: the plan's index is kept.
    final pasted = _contacts(3);
    matcher.listFor(
      peopleVersion: pasted,
      people: () => pasted,
      allGuests: guests,
    );
    expect(normalised, 5 + 8 + 3);

    // A new guests version (the provider replaced its list) builds the index
    // again, once.
    final changed = [...guests, _guest(6, phone: '+967771234999')];
    matcher.listFor(
      peopleVersion: pasted,
      people: () => pasted,
      allGuests: changed,
    );
    expect(normalised, 5 + 8 + 3 + (6 + 3));
  });

  test('the index marks as the pairwise match did', () {
    final guests = [
      _guest(1, phone: '+967777123456'),
      _guest(2, phone: '777123456'),
      _guest(3),
    ];
    final candidates = markGuestCandidates([
      (name: 'أحد', phone: '0777123456'),
      (name: 'ضيف 3', phone: null),
      (name: ' ضيف  3 ', phone: '   '),
      (name: 'جديد', phone: '771000000'),
    ], guests);
    // The first guest with the number, as the list holds them.
    expect(candidates[0].existing?.id, 'g1');
    expect(candidates[1].sameName?.id, 'g3');
    expect(candidates[2].sameName?.id, 'g3');
    expect(candidates[2].repeated, isTrue);
    expect(candidates[3].isDuplicate, isFalse);
    expect(candidates[3].sameName, isNull);
  });

  test('2000 contacts against 500 guests are marked within budget', () {
    final guests = _guests(500);
    final contacts = _contacts(2000);
    // Warm the JIT the way a second build would find it.
    markGuestCandidates(contacts, guests);
    final watch = Stopwatch()..start();
    final candidates = markGuestCandidates(contacts, guests);
    watch.stop();
    expect(candidates, hasLength(2000));
    // The old pairwise match took well over a second here; one map of the
    // plan's numbers makes it one normalisation per contact.
    expect(watch.elapsedMilliseconds, lessThan(250));
  });
}
