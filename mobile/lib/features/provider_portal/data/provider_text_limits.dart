import 'package:flutter/widgets.dart' show StringCharacters;

// RA-BE-15: what the server takes for a provider's text (its request forms
// under backend/src/provider-dashboard/dto). Each field stops the provider
// here, counted as the server counts (a character as the reader sees it), so
// a long text is never refused after he presses send.

/// A service's, a package's or an offer's name; the business name.
const providerTitleMax = 160;

/// What a service or package includes; an offer's message; the about.
const providerDescriptionMax = 2000;

/// A service's price note («للساعة»، «لليوم»).
const providerPriceUnitMax = 120;

/// The shop's place, as the customer reads it.
const providerAddressMax = 300;

/// One line of what an offer covers.
const providerOfferLineMax = 120;

/// A package's features: up to 50 lines.
const providerPackageItemsMax = 50;

/// One feature of a package.
const providerPackageItemMax = 200;

/// A package's features as they are sent: one per line, empty lines dropped.
List<String> providerPackageItems(String value) => value
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

/// A package's features as the server takes them.
String? providerPackageItemsError(String value) {
  final items = providerPackageItems(value);
  if (items.length > providerPackageItemsMax) {
    return 'خلّ المميزات $providerPackageItemsMax سطر أو أقل.';
  }
  if (items.any((item) => item.characters.length > providerPackageItemMax)) {
    return 'خلّ كل ميزة $providerPackageItemMax حرف أو أقل.';
  }
  return null;
}
