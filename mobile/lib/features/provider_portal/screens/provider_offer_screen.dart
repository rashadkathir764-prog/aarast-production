import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show ProviderPackage, QuoteOfferLine, QuoteRequest;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_offer_lines.dart';
import '../widgets/provider_request_parts.dart';

/// How long an offer stays open, in days (p17: 10 by default, D35).
const _offerValidityDays = [7, 10, 14];
const _defaultOfferValidityDays = 10;

String _validityLabel(int days) => days <= 10 ? '$days أيام' : '$days يوم';

/// p17 «عرضك لمحمد»: a package fills the title and the price, the price in
/// the plan's currency, what it includes and leaves out in his own words,
/// and how long it stays open. Sends, edits or renews his one offer (F6):
/// an expired offer is renewed in place with a new end date (D35). The
/// deposit and the remaining are not drawn (no such fields, B-07).
class ProviderOfferScreen extends StatefulWidget {
  const ProviderOfferScreen({required this.quoteId, super.key});

  final String quoteId;

  @override
  State<ProviderOfferScreen> createState() => _ProviderOfferScreenState();
}

class _ProviderOfferScreenState extends State<ProviderOfferScreen> {
  final _amount = TextEditingController();
  final _message = TextEditingController();
  QuoteRequest? _quote;
  String? _packageId;
  String? _title;

  // Editing an open offer keeps its end date unless another length is
  // picked (null); a new or renewed offer starts with ten days.
  int? _validityDays = _defaultOfferValidityDays;
  String? _amountError;
  String? _messageError;

  /// B-07: what the price covers; B-23: the delivery days after the wedding.
  List<QuoteOfferLine> _lines = const [];
  int? _deliveryDays;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Opening the offer form on a new request tells the customer it was
      // seen (D35).
      context.read<ProviderDashboardProvider>().markQuoteViewed(widget.quoteId);
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _message.dispose();
    super.dispose();
  }

  /// Reads the request once, and fills the form from its offer.
  QuoteRequest? _read(ProviderDashboardProvider dashboard) {
    if (_quote != null) return _quote;
    for (final quote in dashboard.quoteRequests) {
      if (quote.id != widget.quoteId) continue;
      _quote = quote;
      final offer = quote.pendingOffer ?? quote.expiredOffer;
      if (offer != null) {
        _amount.text = providerGroupedAmount(offer.amount) ?? '';
        _message.text = offer.message ?? '';
        _title = offer.title;
        _lines = offer.lines;
        _deliveryDays = offer.deliveryDays;
        if (quote.pendingOffer != null) _validityDays = null;
        for (final package in providerOfferPackages(
          dashboard.packages,
          quote,
        )) {
          if (package.title.trim() == offer.title?.trim()) {
            _packageId = package.id;
          }
        }
      }
      return quote;
    }
    return null;
  }

  void _pick(ProviderPackage? package) {
    setState(() {
      _packageId = package?.id;
      if (package == null) return;
      _title = package.title.trim();
      _amount.text = providerGroupedAmount(package.price) ?? '';
      _amountError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final quote = _read(dashboard);
    if (quote == null) {
      return AarastScreenFrame(
        maxWidth: 520,
        backgroundColor: AarastV3Color.canvas,
        child: ListView(
          padding: AarastV3Density.pageInsets,
          children: [
            const JourneySubHeader(title: 'عرضك'),
            JourneyListState(
              phase: dashboard.isLoading
                  ? JourneyListPhase.loading
                  : JourneyListPhase.error,
              section: JourneySection.home,
              onRetry: dashboard.loadDashboard,
            ),
          ],
        ),
      );
    }
    final first = providerFirstName(providerCustomerName(quote));
    final packages = providerOfferPackages(dashboard.packages, quote);
    final open = quote.pendingOffer;
    final line = providerRequestLine(quote);
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AarastV3Density.pageInsets,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                JourneySubHeader(
                  title: 'عرضك ل$first',
                  subtitle: line.isEmpty ? null : line,
                ),
                if (packages.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final package in packages)
                        JourneyChip(
                          key: Key('provider-offer-package-${package.id}'),
                          label: package.title.trim(),
                          selected: _packageId == package.id,
                          onTap: () => _pick(package),
                        ),
                      JourneyChip(
                        key: const Key('provider-offer-package-custom'),
                        label: 'مخصص',
                        selected: _packageId == null,
                        onTap: () => _pick(null),
                      ),
                    ],
                  ),
                  const SizedBox(height: AarastV3Space.x3),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: JourneyTextField(
                        key: const Key('provider-offer-amount'),
                        label: 'السعر',
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        errorText: _amountError,
                        onChanged: (_) {
                          if (_amountError != null) {
                            setState(() => _amountError = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AarastV3Space.x2),
                    Expanded(
                      flex: 2,
                      child: _CurrencyField(
                        currency: providerOfferCurrency(quote),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AarastV3Space.x3),
                JourneyTextField(
                  key: const Key('provider-offer-message'),
                  label: 'ايش يشمل وايش ما يشمل',
                  controller: _message,
                  minLines: 4,
                  maxLines: 8,
                  errorText: _messageError,
                  onChanged: (_) {
                    if (_messageError != null) {
                      setState(() => _messageError = null);
                    }
                  },
                ),
                const SizedBox(height: AarastV3Space.x3),
                ProviderOfferLinesEditor(
                  lines: _lines,
                  onChanged: (lines) => setState(() => _lines = lines),
                ),
                const SizedBox(height: AarastV3Space.x3),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'التسليم بعد العرس',
                      style: JourneyType.of(
                        JourneyType.bodySmall,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    for (final days in providerOfferDeliveryChoices)
                      JourneyChip(
                        key: Key('provider-offer-delivery-${days ?? 0}'),
                        label: providerOfferDeliveryLabel(days),
                        selected: _deliveryDays == days,
                        onTap: () => setState(() => _deliveryDays = days),
                      ),
                  ],
                ),
                const SizedBox(height: AarastV3Space.x3),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'صالح لـ',
                      style: JourneyType.of(
                        JourneyType.bodySmall,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    if (open?.validUntil case final until?)
                      JourneyChip(
                        key: const Key('provider-offer-validity-keep'),
                        label:
                            'كما هو (${formatArabicDayMonth(until.toLocal())})',
                        selected: _validityDays == null,
                        onTap: () => setState(() => _validityDays = null),
                      ),
                    for (final days in _offerValidityDays)
                      JourneyChip(
                        key: Key('provider-offer-validity-$days'),
                        label: _validityLabel(days),
                        selected: _validityDays == days,
                        onTap: () => setState(() => _validityDays = days),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const Key('provider-offer-preview'),
              label: 'شوف العرض قبل ما يوصله',
              icon: LucideIcons.eye,
              expand: true,
              large: true,
              onPressed: () => _preview(quote),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _validUntil(QuoteRequest quote) {
    final days = _validityDays;
    if (days == null) return quote.pendingOffer?.validUntil;
    return DateTime.now().add(Duration(days: days));
  }

  Future<void> _preview(QuoteRequest quote) async {
    final amountError = validateProviderOfferAmount(_amount.text);
    final messageError = _message.text.trim().isEmpty
        ? 'اكتب ايش يشمل العرض.'
        : null;
    if (amountError != null || messageError != null) {
      setState(() {
        _amountError = amountError;
        _messageError = messageError;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    final sent = await showJourneySheet<bool>(
      context: context,
      builder: (_) => _OfferPreviewSheet(
        quote: quote,
        title: _title,
        amount: _amount.text.trim().replaceAll(',', ''),
        message: _message.text.trim(),
        validUntil: _validUntil(quote),
        lines: _lines,
        deliveryDays: _deliveryDays,
      ),
    );
    if (sent != true || !mounted) return;
    // An offer opened from a link lands on its request.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.providerRequest(quote.id));
    }
  }
}

/// The plan's currency, which the offer cannot change (the server refuses
/// another).
class _CurrencyField extends StatelessWidget {
  const _CurrencyField({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'العملة: ${currencySpokenLabelAr(currency)}',
      excludeSemantics: true,
      child: JourneyBox(
        radius: 18,
        padding: AarastV3Density.actionInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'العملة',
              style: JourneyType.of(
                JourneyType.label,
                color: AarastV3Color.textMuted,
              ),
            ),
            Text(
              currencyLabelAr(currency),
              style: JourneyType.of(JourneyType.lead, weight: JourneyType.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// «شوف العرض قبل ما يوصله»: the offer as the customer will read it, then
/// it is sent, saved or renewed.
class _OfferPreviewSheet extends StatefulWidget {
  const _OfferPreviewSheet({
    required this.quote,
    required this.title,
    required this.amount,
    required this.message,
    required this.validUntil,
    this.lines = const [],
    this.deliveryDays,
  });

  final QuoteRequest quote;
  final String? title;
  final String amount;
  final String message;
  final DateTime? validUntil;
  final List<QuoteOfferLine> lines;
  final int? deliveryDays;

  @override
  State<_OfferPreviewSheet> createState() => _OfferPreviewSheetState();
}

class _OfferPreviewSheetState extends State<_OfferPreviewSheet> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final first = providerFirstName(providerCustomerName(quote));
    final renewing = quote.pendingOffer == null && quote.expiredOffer != null;
    final editing = quote.pendingOffer != null;
    final currency = providerOfferCurrency(quote);
    final until = widget.validUntil;
    return JourneySheetBody(
      title: 'كذا يوصل $first',
      children: [
        JourneyBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.title?.trim().isNotEmpty == true)
                Text(
                  widget.title!.trim(),
                  style: JourneyType.of(
                    JourneyType.lead,
                    weight: JourneyType.bold,
                  ),
                ),
              Text(
                providerMoneyLabel(widget.amount, currency),
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                  color: AarastV3Color.primary,
                ),
              ),
              const SizedBox(height: AarastV3Space.x2),
              Text(
                widget.message,
                style: JourneyType.of(JourneyType.body, height: 1.5),
              ),
              if (until != null) ...[
                const SizedBox(height: AarastV3Space.x2),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.clock,
                      size: 18,
                      color: AarastV3Color.textMuted,
                    ),
                    const SizedBox(width: AarastV3Space.x2),
                    Expanded(
                      child: Text(
                        'صالح لين ${formatArabicDayMonth(until.toLocal())}',
                        style: JourneyType.of(JourneyType.bodySmall),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (_error case final error?) ...[
          const SizedBox(height: AarastV3Space.x2),
          JourneyNote(
            text: error,
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
        ],
        const SizedBox(height: AarastV3Space.x3),
        JourneyButton(
          key: const Key('provider-offer-submit'),
          label: renewing
              ? 'جدّد العرض'
              : editing
              ? 'احفظ التعديل'
              : 'أرسل العرض',
          icon: LucideIcons.send,
          expand: true,
          large: true,
          loading: _busy,
          onPressed: () => _submit(renewing: renewing),
        ),
      ],
    );
  }

  Future<void> _submit({required bool renewing}) async {
    final dashboard = context.read<ProviderDashboardProvider>();
    final quote = widget.quote;
    final existing = quote.pendingOffer ?? quote.expiredOffer;
    setState(() {
      _busy = true;
      _error = null;
    });
    final currency = providerOfferCurrency(quote);
    // A new offer waits on the phone with no network (p43); an edit or a
    // renewal needs the server's answer.
    final result = existing == null
        ? await dashboard.createQuoteOffer(
            quoteRequestId: quote.id,
            title: widget.title,
            message: widget.message,
            amount: widget.amount,
            currency: currency,
            validUntil: widget.validUntil,
            lines: widget.lines,
            deliveryDays: widget.deliveryDays,
          )
        : await dashboard.updateQuoteOffer(
            quoteOfferId: existing.id,
            title: widget.title ?? existing.title,
            message: widget.message,
            amount: widget.amount,
            currency: currency,
            validUntil: widget.validUntil,
            lines: widget.lines,
            deliveryDays: widget.deliveryDays,
          )
        ? ProviderOfferSend.sent
        : ProviderOfferSend.failed;
    if (!mounted) return;
    if (result == ProviderOfferSend.failed) {
      setState(() {
        _busy = false;
        _error =
            dashboard.errorMessage ?? 'ما قدرنا نحفظ العرض. جرّب مرة ثانية.';
      });
      return;
    }
    AarastToast.showSuccess(
      context,
      result == ProviderOfferSend.queued
          ? providerQueuedOfferToast
          : renewing
          ? 'تجدّد العرض، ورجع مفتوح له.'
          : existing == null
          ? 'وصل عرضك.'
          : 'تعدّل العرض.',
    );
    Navigator.of(context).pop(true);
  }
}

@visibleForTesting
String? validateProviderOfferAmount(String? value) {
  final normalized = value?.trim().replaceAll(',', '') ?? '';
  if (normalized.isEmpty) return 'اكتب سعر العرض.';
  if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(normalized)) {
    return 'اكتب سعر صحيح، وبحد أقصى رقمين بعد الفاصلة.';
  }
  final parsed = num.tryParse(normalized);
  if (parsed == null || parsed <= 0) return 'السعر لازم يكون أكبر من صفر.';
  return null;
}
