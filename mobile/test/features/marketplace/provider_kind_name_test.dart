import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_marketplace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Rashad 2026-11-18: the catalog's one hall kind is «صالة» for the groom and
// the bride, while the groom's app says «قاعة» everywhere else.
void main() {
  const hall = ProviderCategory(
    id: 'cat-hall',
    nameAr: 'صالة',
    slug: 'wedding-halls',
  );
  const photo = ProviderCategory(
    id: 'cat-photo',
    nameAr: 'تصوير',
    slug: 'photography',
  );

  Future<List<String>> namesFor(WidgetTester tester, JourneyProfile p) async {
    late List<String> names;
    await tester.pumpWidget(
      JourneyProfileScope(
        profile: p,
        child: Builder(
          builder: (context) {
            names = [
              providerKindName(context, hall),
              providerKindName(context, photo),
              providerKindName(context, null),
            ];
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return names;
  }

  testWidgets('the hall is the plan\'s word, the rest the catalog\'s', (
    tester,
  ) async {
    expect(await namesFor(tester, JourneyProfile.groom), ['قاعة', 'تصوير', '']);
    expect(await namesFor(tester, JourneyProfile.bride), ['صالة', 'تصوير', '']);
  });
}
