import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staging invite links use the explicit staging host', () {
    const environment = String.fromEnvironment('AARAST_ENVIRONMENT');
    if (environment != 'staging') return;
    const configuredHost = String.fromEnvironment('AARAST_INVITE_HOST');
    expect(configuredHost, isNotEmpty);
    expect(configuredHost, isNot('aarast.shadowgardn.com'));
    expect(AppRouter.inviteHttpsLink('qa-token').host, configuredHost);
    expect(AppRouter.inviteCustomLink('qa-token').scheme, 'aarast-qa');
  });
}
