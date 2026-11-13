import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/guests/utils/guest_display.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-236: the owner's words were said to a helper («ضيوفك»), and the
// guest's gender followed the reader's.

void main() {
  test('«ضيوفك» is the owner\'s; a helper reads «الضيوف»', () {
    final owner = GuestWords(
      JourneyProfile.of(
        planPersona: 'BRIDE',
        readerFeminine: true,
        readerIsOwner: true,
      ),
    );
    final helper = GuestWords(
      JourneyProfile.of(
        planPersona: 'BRIDE',
        readerFeminine: false,
        readerIsOwner: false,
      ),
    );
    expect(owner.yourGuests, 'ضيفاتك');
    expect(helper.yourGuests, 'الضيفات');
  });
}
