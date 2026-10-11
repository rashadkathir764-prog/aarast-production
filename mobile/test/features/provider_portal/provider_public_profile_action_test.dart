import 'package:aarast_mobile/features/provider_portal/widgets/provider_public_profile_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F03: a provider that is not ACTIVE has no public profile yet, so the
// preview must not open a page that can only fail.
void main() {
  Future<int> pumpFor(WidgetTester tester, String status) async {
    var previews = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ProviderPublicProfileAction(
              status: status,
              onPreview: () => previews += 1,
            ),
          ),
        ),
      ),
    );
    final preview = find.text('معاينة الملف العام');
    if (preview.evaluate().isNotEmpty) await tester.tap(preview);
    return previews;
  }

  for (final status in ['PENDING', 'NEEDS_CHANGES', 'REJECTED', 'SUSPENDED']) {
    testWidgets('$status provider is told when the profile becomes public', (
      tester,
    ) async {
      final previews = await pumpFor(tester, status);

      expect(previews, 0);
      expect(find.text('معاينة الملف العام'), findsNothing);
      expect(
        find.text('يظهر ملفك العام للعملاء بعد اعتماد حسابك.'),
        findsOneWidget,
      );
    });
  }

  testWidgets('ACTIVE provider can preview the public profile', (tester) async {
    final previews = await pumpFor(tester, 'ACTIVE');

    expect(previews, 1);
  });
}
