import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/sharing/screens/invite_decision_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('custom and HTTPS invite links preserve the GoRouter path', () {
    final custom = AppRouter.inviteCustomLink('token-1');
    final https = AppRouter.inviteHttpsLink('token-1');

    expect(custom.toString(), 'aarast://open/invites/token-1');
    expect(custom.path, AppRouter.inviteDecision('token-1'));
    expect(https.host, AppRouter.inviteAppLinkHost);
    expect(https.path, AppRouter.inviteDecision('token-1'));
  });

  testWidgets('router matches both external invite URI forms', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
    final auth = AuthController(AuthRepository(apiClient, storage));
    final router = AppRouter.create();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    for (final link in [
      AppRouter.inviteCustomLink('custom-token'),
      AppRouter.inviteHttpsLink('https-token'),
    ]) {
      router.go(link.toString());
      await tester.pump();
      await tester.pump();

      expect(router.state.uri.path, link.path);
      expect(router.state.pathParameters['token'], link.pathSegments.last);
      expect(find.byType(InviteDecisionScreen), findsOneWidget);
    }
  });

  test('native platform contracts use the same hosts and invite path', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final iosInfo = File('ios/Runner/Info.plist').readAsStringSync();
    final iosEntitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();

    expect(androidManifest, contains('android:scheme="aarast"'));
    expect(
      androidManifest,
      contains('android:host="${AppRouter.inviteCustomSchemeHost}"'),
    );
    expect(androidManifest, contains('android:pathPrefix="/invites"'));
    expect(
      androidManifest,
      contains('android:host="${AppRouter.inviteAppLinkHost}"'),
    );
    expect(iosInfo, contains('<string>aarast</string>'));
    expect(iosInfo, contains('<key>NSContactsUsageDescription</key>'));
    expect(
      iosEntitlements,
      contains('applinks:${AppRouter.inviteAppLinkHost}'),
    );
  });
}
