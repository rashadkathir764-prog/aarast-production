import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../marketplace/marketplace_api.dart'
    show ProviderPackage, QuoteRequest;
import '../providers/provider_dashboard_provider.dart';
import 'provider_request_parts.dart';

/// How long a quick offer stays open, as the offer form's default (D35).
const providerQuickOfferDays = 10;

/// The line a package offers by default; the provider can change it.
String providerPackageMessage(ProviderPackage package) {
  final parts = [
    package.description?.trim() ?? '',
    package.items?.trim() ?? '',
  ].where((part) => part.isNotEmpty);
  return parts.isEmpty ? package.title.trim() : parts.join('\n');
}

/// p45 «رد سريع»: one of his packages answers a new request, with its title,
/// price and line, open for ten days. «آخر 5 عرسان…», the season price and
/// the voice note are not drawn: the server has none of them (B-07, B-29).
Future<void> showProviderQuickOffer(
  BuildContext context,
  QuoteRequest quote,
  List<ProviderPackage> packages,
) async {
  final dashboard = context.read<ProviderDashboardProvider>();
  // Opening a new request is what the customer reads as «شاف طلبك» (D35).
  dashboard.markQuoteViewed(quote.id);
  await showJourneySheet<void>(
    context: context,
    builder: (_) => _ProviderQuickOfferSheet(quote: quote, packages: packages),
  );
}

class _ProviderQuickOfferSheet extends StatefulWidget {
  const _ProviderQuickOfferSheet({required this.quote, required this.packages});

  final QuoteRequest quote;
  final List<ProviderPackage> packages;

  @override
  State<_ProviderQuickOfferSheet> createState() =>
      _ProviderQuickOfferSheetState();
}

class _ProviderQuickOfferSheetState extends State<_ProviderQuickOfferSheet> {
  late ProviderPackage _package = widget.packages.first;
  late final _message = TextEditingController(
    text: providerPackageMessage(_package),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _pick(ProviderPackage package) {
    setState(() {
      _package = package;
      _message.text = providerPackageMessage(package);
    });
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final subtitle = [
      providerCustomerName(quote),
      if (providerRequestLine(quote) case final line when line.isNotEmpty) line,
    ].join(' · ');
    return JourneySheetBody(
      title: 'رد سريع',
      subtitle: subtitle,
      children: [
        for (final package in widget.packages) ...[
          JourneyOption(
            key: Key('provider-quick-offer-package-${package.id}'),
            title:
                '${package.title.trim()} · ${providerGroupedAmount(package.price) ?? package.price}',
            selected: package.id == _package.id,
            onTap: _busy ? null : () => _pick(package),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        JourneyTextField(
          key: const Key('provider-quick-offer-message'),
          label: 'رسالتك مع العرض',
          controller: _message,
          minLines: 2,
          maxLines: 5,
          errorText: _error,
        ),
        const SizedBox(height: 12),
        JourneyButton(
          key: const Key('provider-quick-offer-send'),
          label: 'أرسل',
          icon: LucideIcons.send,
          expand: true,
          large: true,
          loading: _busy,
          onPressed: _send,
        ),
        const SizedBox(height: 8),
        Text(
          'العرض صالح $providerQuickOfferDays أيام، وتقدر تعدّله من الطلب.',
          style: JourneyType.of(
            JourneyType.label,
            color: AarastV3Color.textMuted,
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final message = _message.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'اكتب سطر مع العرض.');
      return;
    }
    final dashboard = context.read<ProviderDashboardProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    final sent = await dashboard.createQuoteOffer(
      quoteRequestId: widget.quote.id,
      title: _package.title.trim(),
      message: message,
      amount: (_package.price ?? '').trim().replaceAll(',', ''),
      currency: providerOfferCurrency(widget.quote),
      validUntil: DateTime.now().add(
        const Duration(days: providerQuickOfferDays),
      ),
    );
    if (!mounted) return;
    if (!sent) {
      setState(() {
        _busy = false;
        _error =
            dashboard.errorMessage ?? 'ما قدرنا نرسل العرض. جرّب مرة ثانية.';
      });
      return;
    }
    AarastToast.showSuccess(context, 'وصل عرضك.');
    Navigator.of(context).pop();
  }
}
