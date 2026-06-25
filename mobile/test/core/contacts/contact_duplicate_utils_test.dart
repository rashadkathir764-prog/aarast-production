import 'package:aarast_mobile/core/contacts/contact_duplicate_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds duplicate phones across different Yemen input formats', () {
    final items = [
      const _Contact('first', '+967777758200'),
      const _Contact('second', '+967711111111'),
    ];

    final duplicate = ContactDuplicateUtils.findByPhone(
      items,
      candidatePhone: '0777 758 200',
      phoneOf: (item) => item.phone,
    );

    expect(duplicate?.id, 'first');
  });

  test('can exclude the record currently being edited', () {
    final items = [const _Contact('first', '+967777758200')];

    final duplicate = ContactDuplicateUtils.findByPhone(
      items,
      candidatePhone: '777758200',
      phoneOf: (item) => item.phone,
      exclude: (item) => item.id == 'first',
    );

    expect(duplicate, isNull);
  });

  test('normalizes repeated whitespace when comparing names', () {
    expect(
      ContactDuplicateUtils.sameName('  أحمد   محمد ', 'أحمد محمد'),
      isTrue,
    );
  });
}

class _Contact {
  const _Contact(this.id, this.phone);

  final String id;
  final String phone;
}
