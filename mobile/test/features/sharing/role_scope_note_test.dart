import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:flutter_test/flutter_test.dart';

// V1 checklist 4.10: the owner learns what each role sees before inviting.

void main() {
  test('the groom or the bride is a partner who sees the whole plan', () {
    for (final role in ['GROOM', 'BRIDE']) {
      final note = sharedMemberRoleScopeNote(role);
      expect(note, contains('يرى كل شيء مثلك'));
      expect(note, contains('ما عدا مصادر تمويلك وسلفك'));
    }
  });

  test('other roles see only what they add', () {
    expect(sharedMemberRoleScopeNote('FAMILY'), contains('ما أضافه هو فقط'));
    expect(sharedMemberRoleScopeNote('HELPER'), contains('ما أضافه هو فقط'));
    expect(sharedMemberRoleScopeNote('VIEWER'), contains('يتابع الخطة فقط'));
  });
}
