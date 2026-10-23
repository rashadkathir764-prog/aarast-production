class CostDraftIntent {
  const CostDraftIntent({
    this.budgetCategoryId,
    this.title,
    this.totalAmount,
    this.initialPaymentAmount,
    this.providerId,
    this.providerName,
    this.externalPartyName,
    this.externalPartyPhone,
    this.quoteOfferId,
    this.currency,
    this.note,
    this.outsideParty = false,
  }) : assert(
         providerId == null || (externalPartyName == null && !outsideParty),
         'A cost cannot target a provider and an external party together.',
       );

  final String? budgetCategoryId;
  final String? title;
  final String? totalAmount;
  final String? initialPaymentAmount;
  final String? providerId;
  final String? providerName;
  final String? externalPartyName;
  final String? externalPartyPhone;
  final String? quoteOfferId;
  final String? currency;
  final String? note;

  /// Opens «مع مين؟» on someone outside اعّرست before a name is typed
  /// (x22 «حجزت برا اعّرست»).
  final bool outsideParty;

  /// Optional convenience used by the form to offer creating the first
  /// payment schedule after the cost itself is saved. It is never sent as a
  /// cost field because a payment date belongs to a schedule, not to a cost.

  bool get isProviderLinked => providerId?.trim().isNotEmpty == true;
  bool get isExternalParty => externalPartyName?.trim().isNotEmpty == true;
  bool get cameFromAcceptedQuote => quoteOfferId?.trim().isNotEmpty == true;
}
