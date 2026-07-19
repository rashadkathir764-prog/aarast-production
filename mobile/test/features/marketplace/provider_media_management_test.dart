import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'provider logo can be updated without unrelated profile fields',
    () async {
      final client = _ProfileMediaApiClient();
      final api = ProviderDashboardApi(client);

      final profile = await api.updateProfileMedia(
        logoUrl: 'https://media.example.test/provider-logo/u1/logo.webp',
      );

      expect(client.lastPath, '/api/v1/provider/me/profile');
      expect(client.lastBody, {
        'logoUrl': 'https://media.example.test/provider-logo/u1/logo.webp',
      });
      expect(profile.logoUrl, client.lastBody?['logoUrl']);
    },
  );

  test('provider media update rejects an empty mutation locally', () async {
    final api = ProviderDashboardApi(_ProfileMediaApiClient());

    expect(() => api.updateProfileMedia(), throwsA(isA<ArgumentError>()));
  });
}

class _ProfileMediaApiClient extends ApiClient {
  _ProfileMediaApiClient() : super(tokenProvider: () async => 'token');

  String? lastPath;
  Map<String, dynamic>? lastBody;

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    lastPath = path;
    lastBody = Map<String, dynamic>.from(data);
    return {
      'id': 'provider-1',
      'userId': 'user-1',
      'businessName': 'قاعة أعرست',
      'status': 'APPROVED',
      'isVerified': true,
      'logoUrl': data['logoUrl'],
      'coverUrl': data['coverUrl'],
    };
  }
}
