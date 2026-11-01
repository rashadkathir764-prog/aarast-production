import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// A failed action (here, removing a guest) says why where it happened; it is
// not a list that could not be read, so no «old copy» notice follows it.

void main() {
  test('a failed removal is not a failed read', () async {
    final api = _Api();
    final provider = GuestsProvider(api);
    await provider.loadGuests('plan-1');
    expect(provider.loadErrorMessage, isNull);

    api.failDelete = true;
    final removed = await provider.deleteGuest(api.guest);

    expect(removed, isFalse);
    expect(provider.errorMessage, 'ما ينشال الحين');
    expect(provider.loadErrorMessage, isNull);
  });

  test(
    'a failed read is the only «old copy», cleared by the next one',
    () async {
      final api = _Api()..failRead = true;
      final provider = GuestsProvider(api);
      await provider.loadGuests('plan-1');
      expect(provider.loadErrorMessage, isNotNull);

      api.failRead = false;
      await provider.loadGuests('plan-1');
      expect(provider.loadErrorMessage, isNull);
    },
  );
}

class _Api extends GuestsApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  bool failRead = false;
  bool failDelete = false;

  final guest = Guest(
    id: 'g1',
    weddingPlanId: 'plan-1',
    name: 'ياسر',
    side: 'GROOM',
    status: 'INVITED',
    attendanceStatus: 'PENDING',
    invitationStatus: 'NOT_SENT',
    seatsCount: 1,
    createdAt: DateTime.utc(2026, 10, 15),
    updatedAt: DateTime.utc(2026, 10, 15),
  );

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async {
    if (failRead) throw const ApiException('ما وصلنا', statusCode: 503);
    return [guest];
  }

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

  @override
  Future<void> deleteGuest(String id) async {
    if (failDelete) throw const ApiException('ما ينشال الحين', statusCode: 400);
  }
}
