import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release cannot fall back to debug signing', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('validateReleaseDartDefines('));
    expect(gradle, contains('Release signing is not configured'));
    expect(gradle, contains('Debug signing is forbidden'));
    expect(gradle, contains('AARAST_ANDROID_STORE_FILE'));
    expect(gradle, contains('AARAST_ANDROID_KEY_PASSWORD'));
    expect(
      gradle,
      contains('val hasUsableReleaseKeystore = invalidSigningKeys.isEmpty()'),
    );
    expect(
      gradle,
      isNot(
        contains(
          'val hasUsableReleaseKeystore = keystorePropertiesFile.isFile',
        ),
      ),
    );
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
  });

  test('Android store bundle fails closed without Sentry release inputs', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('storeReleaseTaskRequested'));
    expect(gradle, contains('requireStoreObservability'));
    expect(gradle, contains('AARAST_SENTRY_DSN'));
    expect(gradle, contains('AARAST_SENTRY_TRACES_SAMPLE_RATE'));
    expect(gradle, contains('SENTRY_RELEASE'));
    expect(gradle, contains('SENTRY_AUTH_TOKEN'));
    expect(gradle, contains('SENTRY_ORG'));
    expect(gradle, contains('SENTRY_PROJECT'));
    expect(
      gradle,
      contains('Store app bundles require AARAST_ENVIRONMENT=production'),
    );
  });

  test(
    'Android QA release can coexist without changing production identity',
    () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(gradle, contains('com.aarast.aarast_mobile'));
      expect(gradle, contains('AARAST_ANDROID_APPLICATION_ID'));
      expect(gradle, contains('AARAST_ANDROID_APP_LABEL'));
      expect(gradle, contains('applicationId = releaseApplicationId'));
      expect(
        gradle,
        contains('manifestPlaceholders["aarastAppLabel"] = releaseAppLabel'),
      );
      expect(manifest, contains(r'android:label="${aarastAppLabel}"'));
    },
  );

  test('iOS release executes the same fail-closed configuration gate', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final script = File(
      'ios/scripts/validate_release_config.sh',
    ).readAsStringSync();

    expect(project, contains('Validate Release Configuration'));
    expect(project, contains('Runner/Runner.entitlements'));
    expect(script, contains('AARAST_API_BASE_URL'));
    expect(script, contains('AARAST_DEV_BYPASS_LOGIN_GATES'));
    expect(script, contains('https://'));
    expect(script, contains('must use a DNS host or public IPv4 address'));
    expect(script, contains('contains an invalid IPv4 address'));
  });

  test('mobile platform privacy and backup declarations are explicit', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(info, contains('<key>NSContactsUsageDescription</key>'));
    expect(info, contains('<string>اعّرست</string>'));
  });
}
