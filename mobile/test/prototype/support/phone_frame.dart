// The one frame every review picture is drawn in: a real Android phone's
// screen (360×800 points at 3×, 1080×2400 pixels), with its status bar on
// top and its gesture bar at the bottom taking their real room
// (`MediaQuery.viewPadding`), so a picture shows the space the content has
// on a phone, the app's bottom navigation included when the screen has it.
//
// Two pictures per state: `<name>.png` is what the phone shows before any
// scroll; `<name>_full.png` is the whole page, as tall as its content.

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/app_text_scale.dart';

/// A phone's screen in points.
class PhoneSize {
  const PhoneSize(this.width, this.height);

  final double width;
  final double height;

  /// The common Android phone the pictures are judged on.
  static const standard = PhoneSize(360, 800);

  /// The narrowest phone the app supports.
  static const narrow = PhoneSize(320, 690);

  /// A large phone.
  static const large = PhoneSize(412, 915);
}

const _statusBar = 32.0;
const _gestureBar = 24.0;
const _pixelRatio = 3.0;

/// Draws [home] on the phone and writes `out/<name>.png` (the first screen)
/// and, unless [fullPage] is false, `out/<name>_full.png` (the whole page).
Future<void> phoneShot(
  WidgetTester tester,
  String name,
  Widget home, {
  PhoneSize size = PhoneSize.standard,
  double textScale = 1,
  List<SingleChildWidget> providers = const [],
  bool fullPage = true,
  double fullHeight = 2400,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
      textScale,
    ).scale(1);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  for (final (suffix, height) in [
    ('', size.height),
    if (fullPage) ('_full', fullHeight),
  ]) {
    tester.view.physicalSize = Size(
      size.width * _pixelRatio,
      height * _pixelRatio,
    );
    tester.view.devicePixelRatio = _pixelRatio;
    tester.view.padding = FakeViewPadding(
      top: _statusBar * _pixelRatio,
      bottom: _gestureBar * _pixelRatio,
    );
    tester.view.viewPadding = FakeViewPadding(
      top: _statusBar * _pixelRatio,
      bottom: _gestureBar * _pixelRatio,
    );
    addTearDown(tester.view.reset);
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: _PhoneBars(child: child!),
      ),
      home: home,
    );
    await tester.pumpWidget(
      providers.isEmpty ? app : MultiProvider(providers: providers, child: app),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (act != null) {
      await act(tester);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    expect(tester.takeException(), isNull, reason: '$name$suffix');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/$name$suffix.png'),
    );
  }
}

/// The phone's own bars drawn over the app, in the room the app leaves them.
class _PhoneBars extends StatelessWidget {
  const _PhoneBars({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _statusBar,
          child: IgnorePointer(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      '9:41',
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                      ),
                    ),
                    const Spacer(),
                    const Icon(LucideIcons.signal, size: 14),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.wifi, size: 14),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.batteryFull, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: _gestureBar,
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: 108,
                height: 4,
                decoration: BoxDecoration(
                  color: AarastV3Color.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
