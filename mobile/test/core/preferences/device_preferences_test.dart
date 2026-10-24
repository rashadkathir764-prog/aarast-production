import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
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
}
