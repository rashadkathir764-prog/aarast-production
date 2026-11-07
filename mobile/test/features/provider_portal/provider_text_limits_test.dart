import 'package:aarast_mobile/features/provider_portal/data/provider_text_limits.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-BE-15: the server takes a package's features as up to 50 lines of up to
// 200 characters (create-provider-package.dto.ts); the phone stops them first,
// so «احفظ» is never refused for them.
void main() {
  test('features are sent one per line, empty lines dropped', () {
    expect(providerPackageItems(' تصوير \n\n فيديو\n  \n'), ['تصوير', 'فيديو']);
    expect(providerPackageItems(''), isEmpty);
  });

  test('up to 50 features of up to 200 characters are taken', () {
    expect(providerPackageItemsError(''), isNull);
    expect(
      providerPackageItemsError(List.filled(50, 'ميزة').join('\n')),
      isNull,
    );
    // 200 characters as read, its marks not counted.
    expect(providerPackageItemsError('مُ' * providerPackageItemMax), isNull);
  });

  test('more features, or a longer one, are stopped with what to change', () {
    expect(
      providerPackageItemsError(List.filled(51, 'ميزة').join('\n')),
      'خلّ المميزات 50 سطر أو أقل.',
    );
    expect(
      providerPackageItemsError('ا' * (providerPackageItemMax + 1)),
      'خلّ كل ميزة 200 حرف أو أقل.',
    );
  });
}
