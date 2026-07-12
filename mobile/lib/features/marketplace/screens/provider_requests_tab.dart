import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/quote_status_chip.dart';

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
      color: AppTheme.burgundy,
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
                TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
                onOffer: quote.lifecycleStatus == 'PENDING_PROVIDER'
                    ? () => _showOfferDialog(context, quote)
                    : null,
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
  });

  final QuoteRequest quote;
  final VoidCallback onChat;
  final VoidCallback? onOffer;

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
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
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
              style: const TextStyle(color: AppTheme.muted, height: 1.45),
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
                    icon: const Icon(LucideIcons.send),
                    label: const Text('إرسال عرض'),
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
  final message = TextEditingController();
  final amount = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AarastDialog(
      title: const Text('إرسال عرض السعر'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'المبلغ (${currencyLabelAr(defaultCurrencyCode)})',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: message,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'تفاصيل العرض'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('إرسال'),
        ),
      ],
    ),
  );
  if (submitted == true && context.mounted) {
    await context.read<ProviderDashboardProvider>().createQuoteOffer(
      quoteRequestId: quote.id,
      message: message.text,
      amount: amount.text,
    );
  }
  message.dispose();
  amount.dispose();
}
