import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_plan_id.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// D116 closing round: D1/D10 (a list «not read yet» is not «no guests»),
// D28 (an older answer never lands over a newer one) and D25 (one rule for
// a plan kept on the phone).

void main() {
  test('an empty plan is told from a plan not read yet (D1, D10)', () async {
    final api = _Api();
    final provider = GuestsProvider(api);
    expect(provider.hasRead('plan-1'), isFalse);

    final load = provider.loadGuests('plan-1');
    expect(provider.hasRead('plan-1'), isFalse);
    api.answer('plan-1', const []);
    await load;

    expect(provider.guests, isEmpty);
    expect(provider.hasRead('plan-1'), isTrue);
    expect(provider.hasRead('plan-2'), isFalse);
  });

  test('a list that could not be read is not marked read', () async {
    final api = _Api();
    final provider = GuestsProvider(api);
    final load = provider.loadGuests('plan-1');
    api.fail('plan-1');
    await load;

    expect(provider.hasRead('plan-1'), isFalse);
    expect(provider.loadErrorMessage, isNotNull);
  });

  test(
    'an older answer arriving last does not replace the newer (D28)',
    () async {
      final api = _Api();
      final provider = GuestsProvider(api);

      final first = provider.loadGuests('plan-1');
      final second = provider.loadGuests('plan-2');
      api.answer('plan-2', [_guest('g2', 'plan-2')]);
      await second;
      api.answer('plan-1', [_guest('g1', 'plan-1')]);
      await first;

      expect(provider.guests.map((guest) => guest.id), ['g2']);
      expect(provider.hasRead('plan-2'), isTrue);
      expect(provider.hasRead('plan-1'), isFalse);
      expect(provider.isLoading, isFalse);
    },
  );

  test('opening another plan forgets that the first was read', () async {
    final api = _Api();
    final provider = GuestsProvider(api);
    final first = provider.loadGuests('plan-1');
    api.answer('plan-1', [_guest('g1', 'plan-1')]);
    await first;
    expect(provider.hasRead('plan-1'), isTrue);

    unawaited(provider.loadGuests('plan-2'));
    expect(provider.hasRead('plan-1'), isFalse);
    expect(provider.hasRead('plan-2'), isFalse);
  });

  test('one rule says which plans are kept on the phone (D25)', () {
    for (final id in [
      null,
      '',
      '  ',
      'local-guest-plan',
      'guest-plan-1',
      'local-guest-7',
    ]) {
      expect(isLocalPlanId(id), isTrue, reason: '$id');
    }
    for (final id in ['plan-1', 'cmabc123', 'wedding_plan-1']) {
      expect(isLocalPlanId(id), isFalse, reason: id);
    }
  });
}

Guest _guest(String id, String planId) => Guest(
  id: id,
  weddingPlanId: planId,
  name: 'ياسر',
  side: 'GROOM',
  status: 'INVITED',
  attendanceStatus: 'PENDING',
  invitationStatus: 'NOT_SENT',
  seatsCount: 1,
  createdAt: DateTime.utc(2026, 10, 15),
  updatedAt: DateTime.utc(2026, 10, 15),
);

/// Answers each plan's read when the test says, so the order is the test's.
class _Api extends GuestsApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  final _reads = <String, Completer<List<Guest>>>{};

  Completer<List<Guest>> _read(String planId) =>
      _reads.putIfAbsent(planId, Completer<List<Guest>>.new);

  void answer(String planId, List<Guest> guests) =>
      _read(planId).complete(guests);

  void fail(String planId) => _read(
    planId,
  ).completeError(const ApiException('ما وصلنا', statusCode: 503));

  @override
  Future<List<Guest>> cachedGuests(String weddingPlanId) async => const [];

  @override
  Future<List<GuestGroup>> cachedGroups(String weddingPlanId) async => const [];

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) =>
      _read(weddingPlanId).future;

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async => GuestSummary.fromGuests(
    weddingPlanId: weddingPlanId,
    guests: localGuests ?? const [],
  );
}
