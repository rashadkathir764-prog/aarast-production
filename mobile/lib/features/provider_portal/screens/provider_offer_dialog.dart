import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show QuoteRequest;
import '../providers/provider_dashboard_provider.dart';

/// How long an offer stays open, in days (prototype p17: 10 by default).
const _offerValidityDays = [7, 10, 14];
const _defaultOfferValidityDays = 10;

String _validityLabel(int days) => days <= 10 ? '$days أيام' : '$days يوم';

/// Sends, edits or renews the provider's offer on [quote].
Future<void> showProviderOfferDialog(
  BuildContext context,
  QuoteRequest quote,
) async {
  // An expired offer is renewed in place: same offer, a new end date, and
  // the price kept or changed.
  final renewing = quote.pendingOffer == null && quote.expiredOffer != null;
  final existingOffer = quote.pendingOffer ?? quote.expiredOffer;
  final submitted = await showDialog<bool>(
    context: context,
    builder: (_) => _ProviderOfferDialog(quote: quote, renewing: renewing),
  );
  if (submitted == true && context.mounted) {
    AarastToast.showSuccess(
      context,
      renewing
          ? 'تجدّد العرض، ورجع مفتوح للعميل.'
          : existingOffer == null
          ? 'تم إرسال عرض السعر.'
          : 'تم تحديث عرض السعر.',
    );
  }
}

/// The offer form. It owns its fields, so they outlive the closing animation.
class _ProviderOfferDialog extends StatefulWidget {
  const _ProviderOfferDialog({required this.quote, required this.renewing});

  final QuoteRequest quote;
  final bool renewing;

  @override
  State<_ProviderOfferDialog> createState() => _ProviderOfferDialogState();
}

class _ProviderOfferDialogState extends State<_ProviderOfferDialog> {
  late final _existingOffer =
      widget.quote.pendingOffer ?? widget.quote.expiredOffer;
  late final _message = TextEditingController(text: _existingOffer?.message);
  late final _amount = TextEditingController(text: _existingOffer?.amount);
  final _formKey = GlobalKey<FormState>();
  late final String _currency =
      widget.quote.weddingPlanCurrency?.trim().toUpperCase() ??
      _existingOffer?.currency?.trim().toUpperCase() ??
      defaultCurrencyCode;

  // Editing an open offer keeps its end date unless another length is
  // picked (null); a new or renewed offer starts with ten days.
  late int? _validityDays = _existingOffer != null && !widget.renewing
      ? null
      : _defaultOfferValidityDays;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _message.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final existingOffer = _existingOffer;
    final renewing = widget.renewing;
    return AarastDialog(
      title: Text(
        renewing
            ? 'جدّد العرض'
            : existingOffer == null
            ? 'إرسال عرض السعر'
            : 'تعديل عرض السعر',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AarastV3FocusPrompt(
              question: existingOffer == null
                  ? 'ما العرض الحقيقي الذي ستقدمه؟'
                  : 'ما الذي تريد تعديله في عرضك؟',
              supportingText:
                  'اكتب المبلغ والتفاصيل بوضوح؛ هذا عرض سعر وليس تأكيد حجز أو دفع.',
              icon: LucideIcons.fileCheck,
            ),
            const SizedBox(height: 14),
            if (quote.weddingPlanTitle?.trim().isNotEmpty == true) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'الخطة: ${quote.weddingPlanTitle}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextFormField(
              key: const Key('provider-offer-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'المبلغ (${currencyLabelAr(_currency)})',
                helperText:
                    'عملة العرض مرتبطة بعملة الخطة ولا يمكن تغييرها هنا.',
              ),
              validator: validateProviderOfferAmount,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('provider-offer-message'),
              controller: _message,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'تفاصيل العرض'),
              validator: (value) =>
                  value?.trim().isEmpty != false ? 'اكتب تفاصيل العرض.' : null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                renewing ? 'العرض الجديد صالح لمدة' : 'العرض صالح لمدة',
                style: JourneyType.of(
                  JourneyType.bodySmall,
                  weight: JourneyType.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (existingOffer != null && !renewing)
                  JourneyChip(
                    key: const Key('provider-offer-validity-keep'),
                    label: existingOffer.validUntil == null
                        ? 'كما هي'
                        : 'كما هي (${formatArabicCompactDate(existingOffer.validUntil!)})',
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
            if (_errorMessage case final error?) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          key: const Key('provider-offer-submit'),
          onPressed: _isSubmitting ? null : _submit,
          child: Text(
            _isSubmitting
                ? 'جارٍ الحفظ...'
                : renewing
                ? 'جدّد العرض'
                : existingOffer == null
                ? 'إرسال'
                : 'حفظ التعديل',
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final dashboard = context.read<ProviderDashboardProvider>();
    final existingOffer = _existingOffer;
    final normalizedAmount = _amount.text.trim().replaceAll(',', '');
    final days = _validityDays;
    final validUntil = days == null
        ? existingOffer?.validUntil
        : DateTime.now().add(Duration(days: days));
    final success = existingOffer == null
        ? await dashboard.createQuoteOffer(
            quoteRequestId: widget.quote.id,
            message: _message.text,
            amount: normalizedAmount,
            currency: _currency,
            validUntil: validUntil,
          )
        : await dashboard.updateQuoteOffer(
            quoteOfferId: existingOffer.id,
            message: _message.text,
            amount: normalizedAmount,
            currency: _currency,
            title: existingOffer.title,
            validUntil: validUntil,
          );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _isSubmitting = false;
      _errorMessage =
          dashboard.errorMessage ?? 'تعذر حفظ عرض السعر. حاول مرة أخرى.';
    });
  }
}

@visibleForTesting
String? validateProviderOfferAmount(String? value) {
  final normalized = value?.trim().replaceAll(',', '') ?? '';
  if (normalized.isEmpty) return 'أدخل مبلغ العرض.';
  if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(normalized)) {
    return 'أدخل مبلغًا صحيحًا بحد أقصى منزلتين عشريتين.';
  }
  final parsed = num.tryParse(normalized);
  if (parsed == null || parsed <= 0) return 'يجب أن يكون المبلغ أكبر من صفر.';
  return null;
}
