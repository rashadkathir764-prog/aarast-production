import 'package:aarast_mobile/core/utils/arabic_sort.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/utils/guest_list_index.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-363: the guest list folded every name for every letter typed and
// sorted with the sort key worked out inside the comparator, and counted the
// summary and the duplicates again on every build: 82ms a letter for 1500
// guests and 258ms for 5000 on a desktop.

Guest _guest(String id, String name, {String? phone, String plan = 'plan-1'}) {
  final now = DateTime.utc(2026, 10, 15);
  return Guest(
    id: id,
    weddingPlanId: plan,
    name: name,
    phone: phone,
    side: 'OTHER',
    status: 'INVITED',
    seatsCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}

const _first = [
  'محمد',
  'عبد الله',
  'أحمد',
  'علي',
  'فاطمة',
  'عائشة',
  'خديجة',
  'يحيى',
  'عبد الرحمن',
  'صالح',
];
const _last = [
  'الحوثي',
  'العمري',
  'الأهدل',
  'باوزير',
  'السقاف',
  'المقطري',
  'الشامي',
  'الحداد',
];

List<Guest> _many(int count) => [
  for (var i = 0; i < count; i++)
    _guest(
      'g$i',
      '${_first[i % 10]} ${_first[(i * 7) % 10]} ${_last[(i * 3) % 8]} $i',
      phone: '+96777${1000000 + i}',
    ),
];

void main() {
  test('each guest is folded and keyed once, not for every letter', () {
    var searchKeys = 0;
    var sortKeys = 0;
    final guests = [
      _guest('1', 'أحمد علي'),
      _guest('2', 'احمد صالح'),
      _guest('3', 'عبدالله يحيى'),
      _guest('4', 'فاطمه', plan: 'plan-2'),
    ];
    final index = GuestListIndex(
      'plan-1',
      guests,
      searchKey: (name) {
        searchKeys++;
        return arabicSearchKey(name);
      },
      sortKey: (name) {
        sortKeys++;
        return arabicSortKey(name);
      },
    );
    expect((searchKeys, sortKeys), (3, 3));

    for (final query in ['ا', 'اح', 'احم', 'احمد']) {
      index.search(query);
    }
    expect((searchKeys, sortKeys), (3, 3));
    expect(index.search('احمد').map((guest) => guest.id), ['2', '1']);
    expect(index.search('عبد الله').map((guest) => guest.id), ['3']);
    expect(index.sorted.map((guest) => guest.id), ['2', '1', '3']);

    // The provider's same list is the same version: the index is kept.
    expect(identical(GuestListIndex.of(index, 'plan-1', guests), index), true);
    expect(
      identical(GuestListIndex.of(index, 'plan-1', [...guests]), index),
      isFalse,
    );
  });

  test('who shares a number is found once per version', () {
    final index = GuestListIndex('plan-1', [
      _guest('1', 'أ', phone: '+967777123456'),
      _guest('2', 'ب', phone: '0777123456'),
      _guest('3', 'ج', phone: '771000000'),
      _guest('4', 'د'),
    ]);
    expect(index.duplicates, {'1', '2'});
    expect(index.search('7771').map((guest) => guest.id), ['1', '2']);
    // Fewer than three digits match no number.
    expect(index.search('77'), isEmpty);
  });

  test('a letter searched in 5000 guests stays within budget', () {
    final index = GuestListIndex('plan-1', _many(5000));
    index.search('محم');
    const letters = ['م', 'مح', 'محم', 'محمد', 'محمد ع'];
    final watch = Stopwatch()..start();
    for (final query in letters) {
      index.search(query);
    }
    watch.stop();
    // Was 258ms a letter: the names folded and the list sorted each time.
    expect(watch.elapsedMilliseconds / letters.length, lessThan(25));
  });

  testWidgets('the search waits for the typing to pause', (tester) async {
    final heard = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GuestSearchField(onChanged: heard.add)),
      ),
    );
    final field = find.byKey(const ValueKey('guests-search-field'));

    await tester.enterText(field, 'م');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'مح');
    await tester.pump(const Duration(milliseconds: 149));
    expect(heard, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(heard, ['مح']);
  });
}
