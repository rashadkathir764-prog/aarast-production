import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../marketplace/marketplace_api.dart' show QuoteRequest;
import '../providers/provider_dashboard_provider.dart';
import 'provider_request_parts.dart';

/// p19 «اسحب العرض» (B-03), asked once before it happens: the offer closes,
/// the customer reads one quiet line, and the request comes back to «جديد»
/// with seven new days to answer. Returns true when the offer was withdrawn.
Future<bool> showProviderWithdrawSheet(
  BuildContext context, {
  required QuoteRequest quote,
  required String offerId,
}) async {
  final withdrawn = await showJourneySheet<bool>(
    context: context,
    builder: (_) => _ProviderWithdrawSheet(quote: quote, offerId: offerId),
  );
  return withdrawn == true;
}

class _ProviderWithdrawSheet extends StatefulWidget {
  const _ProviderWithdrawSheet({required this.quote, required this.offerId});

  final QuoteRequest quote;
  final String offerId;

  @override
  State<_ProviderWithdrawSheet> createState() => _ProviderWithdrawSheetState();
}

class _ProviderWithdrawSheetState extends State<_ProviderWithdrawSheet> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final first = providerFirstName(providerCustomerName(widget.quote));
    return JourneySheetBody(
      title: 'تسحب عرضك ل$first؟',
      children: [
        Text(
          'يقفل العرض ويوصل $first سطر هادي إنه ما عاد متاح. '
          'ويرجع الطلب عندك في «جديد»: عندك 7 أيام ترسل عرض جديد أو تعتذر.',
          style: JourneyType.of(JourneyType.body, height: 1.55),
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 10),
          JourneyNote(
            text: error,
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
        ],
        const SizedBox(height: 14),
        JourneyButton(
          key: const Key('provider-offer-withdraw-confirm'),
          label: 'اسحب العرض',
          background: AarastV3Color.danger,
          expand: true,
          large: true,
          loading: _busy,
          onPressed: _withdraw,
        ),
        const SizedBox(height: 8),
        JourneyButton.quiet(
          key: const Key('provider-offer-withdraw-keep'),
          label: 'لا، خلّه',
          expand: true,
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  Future<void> _withdraw() async {
    final dashboard = context.read<ProviderDashboardProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    final withdrawn = await dashboard.withdrawQuoteOffer(widget.offerId);
    if (!mounted) return;
    if (!withdrawn) {
      setState(() {
        _busy = false;
        _error = dashboard.errorMessage ?? 'ما قدرنا نسحب العرض. حاول مرة ثانية.';
      });
      return;
    }
    AarastToast.showSuccess(context, 'سحبت العرض.');
    Navigator.of(context).pop(true);
  }
}
