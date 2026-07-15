import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/marketplace_models.dart';
import 'quote_status_chip.dart';

class PlanQuoteRequestsSection extends StatelessWidget {
  const PlanQuoteRequestsSection({
    required this.quotes,
    required this.canManageProviders,
    required this.canManageMoney,
    required this.isSubmitting,
    required this.onOpenConversation,
    required this.onAccept,
    required this.onReject,
    required this.onCreateCost,
    super.key,
  });

  final List<QuoteRequest> quotes;
  final bool canManageProviders;
  final bool canManageMoney;
  final bool isSubmitting;
  final ValueChanged<QuoteRequest> onOpenConversation;
  final ValueChanged<QuoteRequest> onAccept;
  final ValueChanged<QuoteRequest> onReject;
  final ValueChanged<QuoteRequest> onCreateCost;

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) return const SizedBox.shrink();

    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileCheck2, color: AppTheme.burgundy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'عروض الأسعار',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'راجع العرض واقبله أو ارفضه من هنا. قبول العرض يربط المورد بالخطة فقط ولا ينشئ تكلفة أو دفعة تلقائيًا.',
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < quotes.length; index += 1) ...[
            _PlanQuoteCard(
              quote: quotes[index],
              canManageProviders: canManageProviders,
              canManageMoney: canManageMoney,
              isSubmitting: isSubmitting,
              onOpenConversation: () => onOpenConversation(quotes[index]),
              onAccept: () => onAccept(quotes[index]),
              onReject: () => onReject(quotes[index]),
              onCreateCost: () => onCreateCost(quotes[index]),
            ),
            if (index != quotes.length - 1)
              const Divider(height: 24, color: AppTheme.border),
          ],
        ],
      ),
    );
  }
}

class _PlanQuoteCard extends StatelessWidget {
  const _PlanQuoteCard({
    required this.quote,
    required this.canManageProviders,
    required this.canManageMoney,
    required this.isSubmitting,
    required this.onOpenConversation,
    required this.onAccept,
    required this.onReject,
    required this.onCreateCost,
  });

  final QuoteRequest quote;
  final bool canManageProviders;
  final bool canManageMoney;
  final bool isSubmitting;
  final VoidCallback onOpenConversation;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCreateCost;

  @override
  Widget build(BuildContext context) {
    final providerName = _providerName(quote);
    final serviceName = _serviceName(quote);
    final offer = quote.acceptedOffer ?? quote.pendingOffer;
    final amount = _amountLabel(offer);
    final suggestion = quote.costSuggestion;
    final canCreateCost = suggestion?.canCreateCost == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    providerName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    amount == null ? serviceName : '$serviceName · $amount',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            QuoteStatusChip(status: quote.lifecycleStatus, compact: true),
          ],
        ),
        if (quote.canAcceptOrReject) ...[
          const SizedBox(height: 12),
          if (canManageProviders)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: Key('quote-accept-${quote.id}'),
                  onPressed: isSubmitting ? null : onAccept,
                  icon: const Icon(LucideIcons.check, size: 18),
                  label: const Text('قبول العرض'),
                ),
                OutlinedButton.icon(
                  key: Key('quote-reject-${quote.id}'),
                  onPressed: isSubmitting ? null : onReject,
                  icon: const Icon(LucideIcons.x, size: 18),
                  label: const Text('رفض العرض'),
                ),
              ],
            )
          else
            const _PermissionMessage(
              message: 'تحتاج صلاحية إدارة الموردين لقبول العرض أو رفضه.',
            ),
        ],
        if (quote.lifecycleStatus == 'ACCEPTED') ...[
          const SizedBox(height: 12),
          const _TruthMessage(
            message: 'تم ربط المورد بالخطة. لم تُنشأ تكلفة أو دفعة تلقائيًا.',
          ),
          if (canCreateCost) ...[
            const SizedBox(height: 10),
            if (canManageMoney)
              FilledButton.icon(
                key: Key('quote-create-cost-${quote.id}'),
                onPressed: isSubmitting ? null : onCreateCost,
                icon: const Icon(LucideIcons.receipt, size: 18),
                label: const Text('إضافة التكلفة إلى المال'),
              )
            else
              const _PermissionMessage(
                message: 'تحتاج صلاحية إدارة المال لإضافة هذه التكلفة.',
              ),
          ],
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: Key('quote-open-conversation-${quote.id}'),
          onPressed: onOpenConversation,
          icon: const Icon(LucideIcons.messageCircle, size: 18),
          label: const Text('فتح محادثة المورد'),
        ),
      ],
    );
  }
}

class _TruthMessage extends StatelessWidget {
  const _TruthMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.successSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.22)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppTheme.ink,
          fontWeight: FontWeight.w800,
          height: 1.4,
        ),
      ),
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: AppTheme.muted,
        fontWeight: FontWeight.w800,
        height: 1.4,
      ),
    );
  }
}

String _providerName(QuoteRequest quote) {
  final suggestion = quote.costSuggestion?.providerName.trim();
  if (suggestion != null && suggestion.isNotEmpty) return suggestion;
  final provider = quote.provider?.businessName.trim();
  if (provider != null && provider.isNotEmpty) return provider;
  return 'مورد العرض';
}

String _serviceName(QuoteRequest quote) {
  final service = quote.service?.title.trim();
  if (service != null && service.isNotEmpty) return service;
  final category = quote.costSuggestion?.category?.trim();
  if (category != null && category.isNotEmpty) return category;
  return 'خدمة زفاف';
}

String? _amountLabel(QuoteOffer? offer) {
  final amount = offer?.amount?.trim();
  if (amount == null || amount.isEmpty) return null;
  final currency = offer?.currency?.trim();
  if (currency == null || currency.isEmpty) return amount;
  return '$amount ${currencyLabelAr(currency)}';
}
