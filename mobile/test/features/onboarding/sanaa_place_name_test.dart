import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-335 (rest): «أمانة العاصمة» is the capital, Sana'a; with its city
// typed «صنعاء» the phone said «أمانة العاصمة - صنعاء» where the rest said
// «صنعاء». The two are one place, said once, as the server says it.

void main() {
  test("the capital and its city are one place, said «صنعاء»", () {
    const location = WeddingLocationDraft(
      governorate: 'أمانة العاصمة',
      cityOrDistrict: 'صنعاء',
      areaOrNeighborhood: 'حدة',
    );
    expect(location.shortLabel, 'صنعاء');
    expect(location.mediumLabel, 'صنعاء - حدة');
    expect(location.displayLabel, 'صنعاء - حدة');
    expect(location.toJson()['governorate'], 'أمانة العاصمة');
  });

  test('the capital with a district of its own keeps its name', () {
    const location = WeddingLocationDraft(
      governorate: 'أمانة العاصمة',
      cityOrDistrict: 'السبعين',
    );
    expect(location.shortLabel, 'أمانة العاصمة - السبعين');
  });
}
