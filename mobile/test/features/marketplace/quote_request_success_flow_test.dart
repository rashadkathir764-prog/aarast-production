import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful quote submission opens a deterministic results route', () {
    final source = File(
      'lib/features/marketplace/screens/quote_request_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('class _QuoteSentState')));
    expect(source, isNot(contains('setState(() => _sent = true)')));
    expect(source, contains("AarastToast.showSuccess"));
    expect(source, isNot(contains("context.pop(true)")));
    expect(source, contains('marketplace.lastCreatedQuote'));
    expect(source, contains('AppRouter.planProviders(planId'));
    expect(source, contains('AppRouter.providerMarketplace'));
  });
}
