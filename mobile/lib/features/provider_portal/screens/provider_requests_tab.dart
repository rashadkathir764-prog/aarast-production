import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../marketplace/marketplace_api.dart'
    show QuoteRequest, QuoteStatusChip;
import '../providers/provider_dashboard_provider.dart';

class ProviderRequestsTab extends StatefulWidget {
  const ProviderRequestsTab({super.key});

  @override
  State<ProviderRequestsTab> createState() => _ProviderRequestsTabState();
}

class _ProviderRequestsTabState extends State<ProviderRequestsTab> {
  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final quotes = dashboard.quoteRequests.where(_matches).toList();
    return RefreshIndicator(
      color: AppTheme.brand,
      onRefresh: dashboard.loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 128),
        children: [
          const AarastSectionHeader(
            title: 'طلبات الأسعار',
            subtitle: 'راجع الطلب، أرسل عرضك، ثم ناقش التفاصيل داخل أعرست.',
            icon: LucideIcons.mailQuestion,
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 4),
              ),
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontWeight: FontWeight.w800),
              ),
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: 'ALL',
                label: Text('الكل', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: 'NEW',
                label: Text('جديد', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: 'OFFERED',
                label: Text('تم العرض', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: 'CLOSED',
                label: Text('مغلق', maxLines: 1, softWrap: false),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (value) =>
                setState(() => _filter = value.first),
          ),
          const SizedBox(height: 16),
          if (dashboard.isLoading && dashboard.quoteRequests.isEmpty)
            const AarastScreenLoading(label: 'جارٍ تحميل الطلبات...')
          else if (quotes.isEmpty)
            const AarastEmptyState(
              icon: LucideIcons.inbox,
              title: 'لا توجد طلبات في هذا القسم',
              message: 'ستظهر الطلبات الجديدة هنا فور وصولها.',
            )
          else
            for (final quote in quotes) ...[
              _ProviderRequestCard(
                quote: quote,
                onChat: () =>
                    context.push(AppRouter.quoteConversation(quote.id)),
                onOffer:
                    quote.lifecycleStatus == 'PENDING_PROVIDER' ||
                        quote.pendingOffer != null
                    ? () => _showOfferDialog(context, quote)
                    : null,
                isEditingOffer: quote.pendingOffer != null,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  bool _matches(QuoteRequest quote) {
    if (_filter == 'ALL') return true;
    if (_filter == 'NEW') {
      return quote.lifecycleStatus == 'PENDING_PROVIDER';
    }
    if (_filter == 'OFFERED') {
      return quote.lifecycleStatus == 'RECEIVED';
    }
    return const {
      'ACCEPTED',
      'REJECTED',
      'CANCELLED',
    }.contains(quote.lifecycleStatus);
  }
}

class _ProviderRequestCard extends StatelessWidget {
  const _ProviderRequestCard({
    required this.quote,
    required this.onChat,
    this.onOffer,
    this.isEditingOffer = false,
  });

  final QuoteRequest quote;
  final VoidCallback onChat;
  final VoidCallback? onOffer;
  final bool isEditingOffer;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quote.service?.title ?? 'طلب عرض سعر',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              QuoteStatusChip(status: quote.lifecycleStatus, compact: true),
            ],
          ),
          if (quote.message?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              quote.message!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(LucideIcons.messageCircle),
                  label: const Text('محادثة'),
                ),
              ),
              if (onOffer != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOffer,
                    icon: Icon(
                      isEditingOffer ? LucideIcons.fileEdit : LucideIcons.send,
                    ),
                    label: Text(isEditingOffer ? 'تعديل العرض' : 'إرسال عرض'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showOfferDialog(BuildContext context, QuoteRequest quote) async {
  final existingOffer = quote.pendingOffer;
  final message = TextEditingController(text: existingOffer?.message);
  final amount = TextEditingController(text: existingOffer?.amount);
  final formKey = GlobalKey<FormState>();
  final currency =
      quote.weddingPlanCurrency?.trim().toUpperCase() ??
      existingOffer?.currency?.trim().toUpperCase() ??
      defaultCurrencyCode;
  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      var isSubmitting = false;
      String? errorMessage;
      return StatefulBuilder(
        builder: (context, setDialogState) => AarastDialog(
          title: Text(
            existingOffer == null ? 'إرسال عرض السعر' : 'تعديل عرض السعر',
          ),
          content: Form(
            key: formKey,
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
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'المبلغ (${currencyLabelAr(currency)})',
                    helperText:
                        'عملة العرض مرتبطة بعملة الخطة ولا يمكن تغييرها هنا.',
                  ),
                  validator: validateProviderOfferAmount,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('provider-offer-message'),
                  controller: message,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'تفاصيل العرض'),
                  validator: (value) => value?.trim().isEmpty != false
                      ? 'اكتب تفاصيل العرض.'
                      : null,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
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
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              key: const Key('provider-offer-submit'),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() != true) return;
                      setDialogState(() {
                        isSubmitting = true;
                        errorMessage = null;
                      });
                      final dashboard = context
                          .read<ProviderDashboardProvider>();
                      final normalizedAmount = amount.text.trim().replaceAll(
                        ',',
                        '',
                      );
                      final success = existingOffer == null
                          ? await dashboard.createQuoteOffer(
                              quoteRequestId: quote.id,
                              message: message.text,
                              amount: normalizedAmount,
                              currency: currency,
                            )
                          : await dashboard.updateQuoteOffer(
                              quoteOfferId: existingOffer.id,
                              message: message.text,
                              amount: normalizedAmount,
                              currency: currency,
                              title: existingOffer.title,
                              validUntil: existingOffer.validUntil,
                            );
                      if (!dialogContext.mounted) return;
                      if (success) {
                        Navigator.pop(dialogContext, true);
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = false;
                        errorMessage =
                            dashboard.errorMessage ??
                            'تعذر حفظ عرض السعر. حاول مرة أخرى.';
                      });
                    },
              child: Text(
                isSubmitting
                    ? 'جارٍ الحفظ...'
                    : existingOffer == null
                    ? 'إرسال'
                    : 'حفظ التعديل',
              ),
            ),
          ],
        ),
      );
    },
  );
  if (submitted == true && context.mounted) {
    AarastToast.showSuccess(
      context,
      existingOffer == null ? 'تم إرسال عرض السعر.' : 'تم تحديث عرض السعر.',
    );
  }
  message.dispose();
  amount.dispose();
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
