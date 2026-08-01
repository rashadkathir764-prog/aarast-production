import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acceptInvite preserves the backend contributor contextKey', () async {
    late RequestOptions request;
    final api = SharingApi(
      _client((options) {
        request = options;
        return _acceptedInviteJson(contextKey: 'plan:plan-1:contributor');
      }),
    );

    final result = await api.acceptInvite('invite-token');

    expect(request.method, 'POST');
    expect(request.path, '/api/v1/invites/invite-token/accept');
    expect(result.invite.weddingPlanId, 'plan-1');
    expect(result.contextKey, 'plan:plan-1:contributor');
  });

  test('acceptInvite rejects a missing or mismatched contextKey', () async {
    final missing = SharingApi(
      _client((_) => _acceptedInviteJson(contextKey: null)),
    );
    final mismatched = SharingApi(
      _client((_) => _acceptedInviteJson(contextKey: 'plan:other:contributor')),
    );

    await expectLater(
      missing.acceptInvite('invite-token'),
      throwsFormatException,
    );
    await expectLater(
      mismatched.acceptInvite('invite-token'),
      throwsFormatException,
    );
  });

  test(
    'accepted current-user invite without context marks an ended membership',
    () async {
      Map<String, dynamic> acceptedInvite({String? contextKey}) {
        final json = Map<String, dynamic>.from(
          _acceptedInviteJson(contextKey: contextKey)['invite'] as Map,
        );
        if (contextKey != null) json['contextKey'] = contextKey;
        return json;
      }

      final withContext = SharingApi(
        _client((_) => [acceptedInvite(contextKey: 'plan:plan-1:contributor')]),
      );
      final missingContext = SharingApi(_client((_) => [acceptedInvite()]));

      final invites = await withContext.getMyInvites();
      expect(invites.single.contextKey, 'plan:plan-1:contributor');
      final endedMembership = await missingContext.getMyInvites();
      expect(endedMembership.single.contextKey, isNull);
      expect(endedMembership.single.hasEndedMembership, isTrue);
    },
  );
}

Map<String, dynamic> _acceptedInviteJson({required String? contextKey}) {
  final json = <String, dynamic>{
    'invite': {
      'id': 'invite-1',
      'weddingPlanId': 'plan-1',
      'token': 'invite-token',
      'role': 'HELPER',
      'status': 'ACCEPTED',
      'expiresAt': '2026-08-01T00:00:00.000Z',
    },
    'member': {
      'id': 'member-1',
      'weddingPlanId': 'plan-1',
      'userId': 'invitee-1',
      'role': 'HELPER',
      'createdAt': '2026-07-29T00:00:00.000Z',
      'updatedAt': '2026-07-29T00:00:00.000Z',
    },
  };
  if (contextKey != null) {
    json['contextKey'] = contextKey;
  }
  return json;
}

ApiClient _client(Object? Function(RequestOptions options) responder) {
  final client = ApiClient(tokenProvider: () async => 'token');
  client.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: responder(options),
          ),
        );
      },
    ),
  );
  return client;
}
