import '../../finance/models/cost_draft_intent.dart';
import 'marketplace_models.dart';

CostDraftIntent? costDraftIntentFromAcceptedQuote(
  QuoteRequest quote, {
  required String fallbackCurrency,
}) {
  final suggestion = quote.costSuggestion;
  final offer = quote.acceptedOffer;
  if (suggestion?.canCreateCost != true || offer == null) return null;

  final providerId = suggestion!.providerId.trim();
  final amount = suggestion.quotedAmount?.trim();
  final quoteOfferId = suggestion.quoteOfferId?.trim();
  if (providerId.isEmpty ||
      amount == null ||
      amount.isEmpty ||
      quoteOfferId == null ||
      quoteOfferId.isEmpty) {
    return null;
  }

  final providerName = suggestion.providerName.trim();
  final suggestionCurrency = suggestion.currency?.trim();
  final offerCurrency = offer.currency?.trim();
  return CostDraftIntent(
    title: _costTitle(quote),
    totalAmount: amount,
    providerId: providerId,
    providerName: providerName.isEmpty ? null : providerName,
    quoteOfferId: quoteOfferId,
    currency: suggestionCurrency?.isNotEmpty == true
        ? suggestionCurrency
        : offerCurrency?.isNotEmpty == true
        ? offerCurrency
        : fallbackCurrency,
    note: 'أُضيفت باختيارك من عرض سعر مقبول.',
  );
}

String _costTitle(QuoteRequest quote) {
  final offerTitle = quote.acceptedOffer?.title?.trim();
  if (offerTitle != null && offerTitle.isNotEmpty) return offerTitle;
  final serviceTitle = quote.service?.title.trim();
  if (serviceTitle != null && serviceTitle.isNotEmpty) return serviceTitle;
  final category = quote.costSuggestion?.category?.trim();
  if (category != null && category.isNotEmpty) return category;
  final providerName = quote.costSuggestion?.providerName.trim();
  return providerName?.isNotEmpty == true
      ? 'تكلفة $providerName'
      : 'تكلفة المورد';
}
