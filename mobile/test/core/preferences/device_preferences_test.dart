import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:flutter/painting.dart' show TextScaler;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// g02: the look and privacy switches live on the phone.

void main() {
  test(
    'defaults: Hijri shown, normal text, photos load, amounts shown',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = DevicePreferences(
        await SharedPreferences.getInstance(),
      );

      expect(preferences.showHijri, isTrue);
      expect(preferences.largeText, isFalse);
      expect(preferences.dataSaver, isFalse);
      expect(preferences.hideAmounts, isFalse);
    },
  );

  // D30, D119: half of the phone's step, up to 1.15; «خط كبير» a step more,
  // up to 1.3.
  test(
    'the text size takes half the phone\'s step and «خط كبير», up to 1.3',
    () {
      double scale(double system, {bool largeText = false}) =>
          DevicePreferences.textScalerFor(
            TextScaler.linear(system),
            largeText: largeText,
          ).scale(10) /
          10;

      expect(scale(1), 1);
      expect(scale(1, largeText: true), closeTo(1.15, 1e-9));
      expect(scale(1.2), closeTo(1.1, 1e-9));
      expect(scale(1.25), closeTo(1.125, 1e-9));
      expect(scale(1.3), closeTo(1.15, 1e-9));
      expect(scale(1.5), closeTo(1.15, 1e-9));
      expect(scale(1.2, largeText: true), closeTo(1.265, 1e-9));
      expect(scale(1.5, largeText: true), closeTo(1.3, 1e-9));
      expect(scale(0.85), closeTo(0.85, 1e-9));
    },
  );

  // Q-49 (D124), RA-MO-366: above 1.5 the phone's own size is a need (low
  // vision), not a taste; WCAG 1.4.4 asks for 200%.
  test('above 1.5 the phone\'s text size passes through as it is', () {
    double scale(double system, {bool largeText = false}) =>
        DevicePreferences.textScalerFor(
          TextScaler.linear(system),
          largeText: largeText,
        ).scale(10) /
        10;

    expect(scale(1.51), closeTo(1.51, 1e-9));
    expect(scale(2), closeTo(2, 1e-9));
    expect(scale(3), closeTo(3, 1e-9));
    // «خط كبير» adds nothing on top of a size already that large.
    expect(scale(2, largeText: true), closeTo(2, 1e-9));
  });

  test('above 1.5 the system scaler itself is kept, nonlinear steps too', () {
    // Android 14 scales big text less than small text.
    const system = _NonlinearScaler();
    final scaler = DevicePreferences.textScalerFor(system, largeText: false);
    expect(identical(scaler, system), isTrue);
    expect(scaler.scale(10), system.scale(10));
    expect(scaler.scale(30), system.scale(30));
  });

  test('a switch outlives the app', () async {
    SharedPreferences.setMockInitialValues({});
    final stored = await SharedPreferences.getInstance();
    await DevicePreferences(stored).setDataSaver(true);
    await DevicePreferences(stored).setShowHijri(false);

    final again = DevicePreferences(stored);
    expect(again.dataSaver, isTrue);
    expect(again.showHijri, isFalse);
  });

  test('«أخفِ المبالغ» and the money eye are one switch', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = DevicePreferences(
      await SharedPreferences.getInstance(),
    );
    final money = FinanceProvider(
      FinanceApi(ApiClient(tokenProvider: () async => null)),
      preferences: preferences,
    );
    var notified = 0;
    money.addListener(() => notified += 1);

    await preferences.setHideAmounts(true);
    expect(money.amountsHidden, isTrue);
    expect(notified, greaterThan(0));

    money.toggleAmountsVisibility();
    await Future<void>.delayed(Duration.zero);
    expect(preferences.hideAmounts, isFalse);
    expect(money.amountsHidden, isFalse);
    money.dispose();
  });

  // A task given to someone: the phone asks first, until told otherwise.
  test('the task message asks by default and keeps the choice', () async {
    SharedPreferences.setMockInitialValues({});
    final stored = await SharedPreferences.getInstance();
    final preferences = DevicePreferences(stored);
    expect(preferences.taskMessageMode, TaskMessageMode.ask);

    var notified = 0;
    preferences.addListener(() => notified += 1);
    await preferences.setTaskMessageMode(TaskMessageMode.whatsApp);
    expect(notified, 1);
    expect(DevicePreferences(stored).taskMessageMode, TaskMessageMode.whatsApp);

    await preferences.setTaskMessageMode(TaskMessageMode.off);
    expect(DevicePreferences(stored).taskMessageMode, TaskMessageMode.off);
  });

  test('an unknown stored task message choice reads as «اسألني»', () async {
    SharedPreferences.setMockInitialValues({
      'aarast_pref_task_message': 'later',
    });
    final preferences = DevicePreferences(
      await SharedPreferences.getInstance(),
    );
    expect(preferences.taskMessageMode, TaskMessageMode.ask);
  });
}

/// 2.0 on a 10-point font, 1.5 on a 30-point one: the shape of the system's
/// nonlinear scaling.
class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 10 ? fontSize * 2 : fontSize * 1.5;

  @override
  double get textScaleFactor => 2;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) => this;

  @override
  bool operator ==(Object other) => other is _NonlinearScaler;

  @override
  int get hashCode => 7;
}
