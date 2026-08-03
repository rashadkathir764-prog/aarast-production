import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/contribution_history.dart';
import '../providers/contribution_history_provider.dart';

class ContributionHistoryScreen extends StatefulWidget {
  const ContributionHistoryScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<ContributionHistoryScreen> createState() =>
      _ContributionHistoryScreenState();
}

class _ContributionHistoryScreenState extends State<ContributionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant ContributionHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    await context.read<ContributionHistoryProvider>().load(
      widget.weddingPlanId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ContributionHistoryProvider>();
    return AarastPageScaffold(
      key: const Key('contribution-history-screen'),
      title: 'سجل مساهماتي',
      subtitle: 'نسخة تاريخية محفوظة لا تتغير بتعديلات الخطة اللاحقة',
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: _load,
        child: _body(provider),
      ),
    );
  }

  Widget _body(ContributionHistoryProvider provider) {
    final response = provider.response;
    final isLoading = provider.isLoading;
    final errorMessage = provider.errorMessage;
    if (isLoading && response == null) {
      return const AarastScreenLoading(label: 'جارٍ تحميل السجل التاريخي...');
    }
    if (errorMessage != null && response == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AarastErrorState(
            title: 'تعذر تحميل سجل المساهمات',
            message: errorMessage,
            onRetry: _load,
          ),
        ],
      );
    }
    final events = response?.events ?? const <ContributionHistoryEvent>[];
    if (events.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          AarastEmptyState(
            icon: LucideIcons.history,
            title: 'لا توجد مساهمات محفوظة بعد',
            message:
                'ستظهر هنا الأعمال التي أنشأتها أو أُسندت إليك أو أنجزتها داخل الخطة.',
          ),
        ],
      );
    }
    final showPagination =
        provider.hasMore ||
        provider.isLoadingMore ||
        provider.loadMoreError != null;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: events.length + 1 + (showPagination ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CoverageNotice(date: response!.historyCoverageStartsAt);
        }
        if (index > events.length) {
          return _HistoryPaginationControl(provider: provider, onReload: _load);
        }
        return _ContributionEventCard(event: events[index - 1]);
      },
    );
  }
}

class _HistoryPaginationControl extends StatelessWidget {
  const _HistoryPaginationControl({
    required this.provider,
    required this.onReload,
  });

  final ContributionHistoryProvider provider;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: AarastInlineSpinner()),
      );
    }
    return Column(
      children: [
        if (provider.loadMoreError != null) ...[
          Text(
            provider.loadMoreError!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.danger),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          key: const Key('contribution-history-load-more'),
          onPressed: provider.requiresReload ? onReload : provider.loadMore,
          icon: Icon(
            provider.requiresReload
                ? LucideIcons.refreshCw
                : LucideIcons.chevronsDown,
          ),
          label: Text(
            provider.requiresReload
                ? 'تحديث السجل من البداية'
                : 'تحميل المزيد من السجل',
          ),
        ),
      ],
    );
  }
}

class _CoverageNotice extends StatelessWidget {
  const _CoverageNotice({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.burgundy.withValues(alpha: 0.06),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.shieldCheck, color: AppTheme.burgundy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'السجل موثّق منذ ${date.year}/${date.month}/${date.day}. البيانات الأقدم لا تُنسب إليك إلا إذا وُجد دليل صريح عليها.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionEventCard extends StatelessWidget {
  const _ContributionEventCard({required this.event});

  final ContributionHistoryEvent event;

  @override
  Widget build(BuildContext context) {
    final title =
        _snapshotTitle(event.snapshot) ?? _entityLabel(event.entityType);
    final details = event.snapshot.entries
        .where(
          (entry) => entry.value != null && entry.value.toString().isNotEmpty,
        )
        .skip(
          title == event.snapshot['title'] ||
                  title == event.snapshot['displayName']
              ? 1
              : 0,
        )
        .take(3)
        .map((entry) => entry.value.toString())
        .join(' • ');
    return AarastCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.burgundy.withValues(alpha: 0.08),
            foregroundColor: AppTheme.burgundy,
            child: Icon(_sectionIcon(event.section), size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_actionLabel(event.action)} • ${_sectionLabel(event.section)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(details, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _snapshotTitle(Map<String, dynamic> snapshot) {
  for (final key in [
    'title',
    'displayName',
    'providerDisplayLabel',
    'planTitle',
  ]) {
    final value = snapshot[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String _sectionLabel(String value) => switch (value) {
  'TASKS' => 'المهام',
  'GUESTS' => 'الضيوف',
  'MONEY' => 'المال',
  'PROVIDERS' => 'الموردون',
  'MEMBERS' => 'المساهمون',
  _ => 'الخطة',
};

IconData _sectionIcon(String value) => switch (value) {
  'TASKS' => LucideIcons.listChecks,
  'GUESTS' => LucideIcons.users,
  'MONEY' => LucideIcons.wallet,
  'PROVIDERS' => LucideIcons.store,
  'MEMBERS' => LucideIcons.userCheck,
  _ => LucideIcons.clipboardList,
};

String _entityLabel(String value) => switch (value) {
  'TASK' => 'مهمة محفوظة',
  'GUEST' => 'ضيف محفوظ',
  'MONEY_ITEM' || 'WEDDING_COST' || 'COST_PAYMENT' => 'سجل مالي محفوظ',
  'PROVIDER_ITEM' || 'QUOTE_REQUEST' => 'مورد محفوظ',
  _ => 'مساهمة محفوظة',
};

String _actionLabel(String value) => switch (value) {
  'CREATED' => 'أنشأها',
  'ASSIGNED' => 'أُسندت إليه',
  'COMPLETED' => 'أنجزها',
  'PAYMENT_RECORDED' => 'سجّل دفعتها',
  _ => 'مساهمة محفوظة',
};
