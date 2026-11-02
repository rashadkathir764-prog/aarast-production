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
    expect(launchBackground, contains('@drawable/launch_image'));
    expect(android12Style, contains('@drawable/ic_launcher_foreground'));
    // Teal identity (DECISIONS 2026-10-22, D0).
    expect(colors, contains('<color name="splash_color">#0B6E69</color>'));
    expect(storyboard, contains('image="LaunchImage"'));
    expect(storyboard, contains('green="0.4313725490"'));
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

    expect(manifest, contains('android:value="aarast_updates"'));
    expect(manifest, contains('android:resource="@drawable/ic_stat_aarast"'));
    expect(activity, contains('NotificationManager.IMPORTANCE_HIGH'));
    expect(activity, contains('setShowBadge(true)'));
    expect(notificationIcon, contains('M12,2.4L14.15,9.85'));
    expect(
      colors,
      contains('<color name="notification_accent">#0B6E69</color>'),
    );
  });
}
