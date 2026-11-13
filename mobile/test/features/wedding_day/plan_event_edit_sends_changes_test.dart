import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-286: editing an event sent every field as the phone had read it,
// and so did the invitation card when it saved the wedding's place. A save
// from a copy a little old undid what the partner had changed meanwhile.
// The server keeps what it is not sent, so an edit sends what it changed.

final _maqeel = PlanEvent(
  id: 'maqeel',
  type: PlanEventType.maqeel,
  date: DateTime(2027, 1, 20),
  slot: PlanEventSlot.afterDhuhr,
  placeLabel: 'بيت الوالد',
  note: 'القات عند صالح',
);

PlanEventDraft _draftOf(PlanEvent event, {String? placeLabel, String? note}) =>
    PlanEventDraft(
      title: event.title,
      date: event.date,
      slot: event.slot,
      exactTime: event.exactTime,
      placeLabel: placeLabel ?? event.placeLabel,
      responsibleName: event.responsibleName,
      note: note ?? event.note,
    );

void main() {
  test(
    'a corrected place sends the place, and nothing it did not touch',
    () async {
      final client = _Client();

      await PlanEventsApi(
        client,
      ).update('plan-1', _maqeel, _draftOf(_maqeel, placeLabel: 'الديوان'));

      expect(
        client.sent.single.path,
        '/api/v1/wedding-plans/plan-1/events/maqeel',
      );
      expect(client.sent.single.method, 'PATCH');
      expect(client.sent.single.data, {'placeLabel': 'الديوان'});
    },
  );

  test('a cleared note is sent as cleared', () async {
    final client = _Client();

    await PlanEventsApi(
      client,
    ).update('plan-1', _maqeel, _draftOf(_maqeel, note: ' '));

    expect(client.sent.single.data, {'note': null});
  });

  test('a save that changed nothing asks the server for nothing', () async {
    final client = _Client();

    final saved = await PlanEventsApi(
      client,
    ).update('plan-1', _maqeel, _draftOf(_maqeel));

    expect(client.sent, isEmpty);
    expect(saved.placeLabel, 'بيت الوالد');
  });
}

class _Client extends ApiClient {
  _Client() : super(tokenProvider: () async => 'token');

  final sent = <({String path, String method, Map<String, dynamic> data})>[];

  @override
  Future<Map<String, dynamic>> mutateJson(
    String path,
    Map<String, dynamic> data, {
    required String method,
    required String clientRequestId,
  }) async {
    sent.add((path: path, method: method, data: data));
    return {
      'id': 'maqeel',
      'type': 'MAQEEL',
      'date': '2027-01-20',
      'timeSlot': 'AFTER_DHUHR',
      'placeLabel': 'بيت الوالد',
      'note': 'القات عند صالح',
      ...data,
    };
  }
}
