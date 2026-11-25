import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> decodePng(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native launcher assets have every required production size', () async {
    final expectedSizes = <String, int>{
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
              'Icon-App-1024x1024@1x.png':
          1024,
    };

    for (final entry in expectedSizes.entries) {
      final image = await decodePng(entry.key);
      expect(image.width, entry.value, reason: entry.key);
      expect(image.height, entry.value, reason: entry.key);
      image.dispose();
    }
  });

  test(
    'the launch name is drawn at every density inside the kept circle',
    () async {
      // Android 12+ keeps a 192dp circle of a 288dp canvas; the name stays
      // inside it with room (D123).
      final densities = {
        'mdpi': 288,
        'hdpi': 432,
        'xhdpi': 576,
        'xxhdpi': 864,
        'xxxhdpi': 1152,
      };
      for (final entry in densities.entries) {
        final image = await decodePng(
          'android/app/src/main/res/drawable-${entry.key}/splash_wordmark.png',
        );
        expect(image.width, entry.value, reason: entry.key);
        expect(image.height, entry.value, reason: entry.key);
        image.dispose();
      }
    },
  );

  test('native splash and adaptive-icon contracts use Aarast branding', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final launchBackground = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final android12Style = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    final colors = File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();

    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    // The launch is the name «اعّرست» on the opening's night (D123), the
    // same on Android 12+ (light and dark) and before it.
    expect(launchBackground, contains('@drawable/splash_wordmark'));
    expect(android12Style, contains('@drawable/splash_wordmark'));
    expect(android12Style, contains('android:windowBackground'));
    final android12NightStyle = File(
      'android/app/src/main/res/values-night-v31/styles.xml',
    ).readAsStringSync();
    expect(android12NightStyle, contains('@drawable/splash_wordmark'));
    expect(
      android12NightStyle,
      contains('android:windowSplashScreenBackground'),
    );
    // The launch is the opening's night, the page after it carries on from
    // it (D0 amended 2026-11-23, D122); the name «اعّرست» is on it (D123).
    expect(colors, contains('<color name="splash_color">#0E2A33</color>'));
    expect(storyboard, contains('image="LaunchImage"'));
    expect(storyboard, contains('green="0.1647058824"'));
    // The identity at rest stays teal: the notifications' accent.
    expect(
      colors,
      contains('<color name="notification_accent">#0B6E69</color>'),
    );
  });

  test('Android push uses the branded high-importance heads-up channel', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/aarast/aarast_mobile/MainActivity.kt',
    ).readAsStringSync();
    final notificationIcon = File(
      'android/app/src/main/res/drawable/ic_stat_aarast.xml',
    ).readAsStringSync();
    final colors = File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();

    // RA-MO-360: one channel per kind of alert, so the phone's settings can
    // quiet one without the others; a message with no channel of its own
    // falls to «رسائل».
    expect(manifest, contains('android:value="aarast_messages"'));
    expect(manifest, isNot(contains('aarast_updates')));
    expect(manifest, contains('android:resource="@drawable/ic_stat_aarast"'));
    expect(activity, contains('NotificationManager.IMPORTANCE_HIGH'));
    expect(activity, contains('setShowBadge(true)'));
    for (final (id, name) in const [
      ('aarast_messages', 'رسائل'),
      ('aarast_tasks', 'مهام وتذكيرات'),
      ('aarast_money', 'المال'),
    ]) {
      expect(activity, matches(RegExp('"$id",\\s*"$name"')), reason: id);
    }
    // The one old channel is carried over (the person's own importance) and
    // then removed, so «رسائل ومهام اعّرست» does not stay in the settings.
    expect(activity, contains('deleteNotificationChannel(oldChannelId)'));
    expect(activity, contains('getNotificationChannel(oldChannelId)'));
    expect(notificationIcon, contains('M12,2.4L14.15,9.85'));
    expect(
      colors,
      contains('<color name="notification_accent">#0B6E69</color>'),
    );
  });
}
