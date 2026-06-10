import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/timeline.dart';
import '../providers/task_timeline_provider.dart';
import '../widgets/task_card.dart';
import '../widgets/timeline_due_item_card.dart';
import '../widgets/timeline_summary_card.dart';

class TaskTimelineScreen extends StatefulWidget {
  const TaskTimelineScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<TaskTimelineScreen> createState() => _TaskTimelineScreenState();
}

class _TaskTimelineScreenState extends State<TaskTimelineScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskTimelineProvider>().load(widget.weddingPlanId);
    });
  }

  @override
  void didUpdateWidget(covariant TaskTimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<TaskTimelineProvider>().load(widget.weddingPlanId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('المهام والجدول الزمني')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.load(widget.weddingPlanId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _TaskTimelineContent(
              provider: provider,
              weddingPlanId: widget.weddingPlanId,
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskTimelineContent extends StatelessWidget {
  const _TaskTimelineContent({
    required this.provider,
    required this.weddingPlanId,
  });

  final TaskTimelineProvider provider;
  final String weddingPlanId;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.tasks.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.load(weddingPlanId),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    final timeline = provider.timeline;
    return ListView(
      children: [
        TimelineSummaryCard(timeline: timeline),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: provider.isSubmitting
              ? null
              : () => context.push(AppRouter.createTask(weddingPlanId)),
          icon: const Icon(Icons.add),
          label: const Text('إضافة مهمة'),
        ),
        if (provider.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.right,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'قائمة المهام',
          emptyMessage: 'لا توجد مهام بعد.',
          isEmpty: provider.tasks.isEmpty,
        ),
        for (final task in provider.tasks)
          TaskCard(
            task: task,
            onMarkDone: provider.isSubmitting
                ? null
                : () => provider.markTaskDone(weddingPlanId, task),
            onDelete: () => _confirmDelete(context, provider, task.id),
          ),
        const SizedBox(height: 16),
        _TimelineSections(timeline: timeline),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskTimelineProvider provider,
    String taskId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المهمة'),
        content: const Text('هل تريد حذف هذه المهمة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteTask(weddingPlanId, taskId);
    }
  }
}

class _TimelineSections extends StatelessWidget {
  const _TimelineSections({required this.timeline});

  final Timeline timeline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: 'المهام القادمة',
          emptyMessage: 'لا توجد مهام قادمة بتاريخ استحقاق.',
          isEmpty: timeline.upcomingTasks.isEmpty,
        ),
        for (final task in timeline.upcomingTasks)
          TimelineDueItemCard(
            title: task.title,
            subtitle: task.description?.trim().isNotEmpty == true
                ? task.description!
                : 'مهمة مرتبطة بالخطة',
            status: task.status,
            dueDate: task.dueDate,
          ),
        const SizedBox(height: 12),
        _SectionTitle(
          title: 'الديون القريبة',
          emptyMessage: 'لا توجد ديون قريبة ظاهرة لك.',
          isEmpty: timeline.dueDebts.isEmpty,
        ),
        for (final debt in timeline.dueDebts)
          TimelineDueItemCard(
            title: debt.title,
            subtitle:
                '${debt.creditorName} - المتبقي ${debt.remainingAmount} YER',
            status: debt.status,
            dueDate: debt.dueDate,
          ),
        const SizedBox(height: 12),
        _SectionTitle(
          title: 'الأقساط القريبة',
          emptyMessage: 'لا توجد أقساط قريبة ظاهرة لك.',
          isEmpty: timeline.dueInstallments.isEmpty,
        ),
        for (final installment in timeline.dueInstallments)
          TimelineDueItemCard(
            title: 'قسط مستحق',
            subtitle: '${installment.amount} YER',
            status: installment.status,
            dueDate: installment.dueDate,
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.emptyMessage,
    required this.isEmpty,
  });

  final String title;
  final String emptyMessage;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.dMaroon,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
          if (isEmpty) ...[
            const SizedBox(height: 8),
            Text(emptyMessage, textAlign: TextAlign.right),
          ],
        ],
      ),
    );
  }
}
