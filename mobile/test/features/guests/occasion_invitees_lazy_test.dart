import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/widgets/occasion_invitees_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-367: an occasion's invitees sheet built a row for every guest at
// once; a plan holds up to 5000 (D99). Its rows are built as they come into
// view; the last guest is still reached by scrolling.

const _planId = 'plan-1';
const _count = 150;

class _Guests extends GuestsProvider {
  _Guests() : super(GuestsApi(ApiClient(tokenProvider: () async => null)));

  final List<Guest> _list = [
    for (var index = 0; index < _count; index++)
      Guest.fromJson({
        'id': 'guest-$index',
        'weddingPlanId': _planId,
        // Zero-padded, so the Arabic sort keeps this order.
        'name': 'ضيف ${(index + 1).toString().padLeft(3, '0')}',
        'side': 'GROOM',
        'status': 'INVITED',
        'seatsCount': 1,
        'createdAt': '2026-11-01T00:00:00.000Z',
        'updatedAt': '2026-11-01T00:00:00.000Z',
      }),
  ];

  @override
  List<Guest> get guests => _list;
}

void main() {
  testWidgets('the invitees sheet builds its guests as they come into view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final guests = _Guests();

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showJourneySheet<int>(
                    context: context,
                    builder: (_) => OccasionInviteesSheet(
                      provider: guests,
                      weddingPlanId: _planId,
                      eventId: 'event-1',
                      label: 'الغداء',
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('مدعوين الغداء'), findsOneWidget);
    final built = find.byType(CheckboxListTile).evaluate().length;
    expect(built, greaterThan(0));
    expect(
      built,
      lessThan(_count ~/ 2),
      reason: 'every guest was built at once ($built of $_count)',
    );

    final last = find.text('ضيف ${_count.toString().padLeft(3, '0')}');
    await tester.scrollUntilVisible(
      last,
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(last, findsOneWidget);
    await tester.tap(last);
    await tester.pump();
    expect(find.text('حفظ المدعوين (ضيف واحد)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
