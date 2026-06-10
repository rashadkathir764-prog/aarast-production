import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/timeline.dart';
import '../models/wedding_task.dart';
import '../providers/task_timeline_provider.dart';

class TaskTimelineScreen extends StatefulWidget {
  const TaskTimelineScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<TaskTimelineScreen> createState() => _TaskTimelineScreenState();
}

class _TaskTimelineScreenState extends State<TaskTimelineScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

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
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskTimelineProvider>();

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRouter.home);
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.dCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.dLine),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: AppTheme.dMaroon),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'المهام والجدول الزمني',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.dMaroonDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: provider.isSubmitting
                        ? null
                        : () => context.push(AppRouter.createTask(widget.weddingPlanId)),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.heroGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.dMaroonDeep.withAlpha(50),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(LucideIcons.plus, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.dMaroon,
                onRefresh: () => provider.load(widget.weddingPlanId),
                child: _TaskTimelineContent(
                  provider: provider,
                  weddingPlanId: widget.weddingPlanId,
                  animationController: _animationController,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTimelineContent extends StatelessWidget {
  const _TaskTimelineContent({
    required this.provider,
    required this.weddingPlanId,
    required this.animationController,
  });

  final TaskTimelineProvider provider;
  final String weddingPlanId;
  final AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.tasks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.dMaroon),
      );
    }

    if (provider.errorMessage != null && provider.tasks.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(LucideIcons.alertTriangle, size: 48, color: AppTheme.danger.withAlpha(150)),
          const SizedBox(height: 16),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dMaroon),
              onPressed: () => provider.load(weddingPlanId),
              child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    }

    final timeline = provider.timeline;
    
    return ListView(
      padding: const EdgeInsets.only(bottom: 120), // Leave space for bottom nav
      children: [
        if (provider.errorMessage != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withAlpha(20),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.danger.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: AppTheme.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        _buildAnimated(0, _SummaryTimelineWidget(timeline: timeline, tasks: provider.tasks)),
        const SizedBox(height: 24),

        _buildAnimated(1, Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionTitle(
            title: 'قائمة المهام',
            emptyMessage: 'لم تقم بإضافة مهام بعد.',
            isEmpty: provider.tasks.isEmpty,
          ),
        )),

        ...provider.tasks.asMap().entries.map((entry) {
          final index = entry.key;
          final task = entry.value;
          return _buildAnimated(
            2 + index,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _ModernTaskCard(
                task: task,
                onMarkDone: provider.isSubmitting
                    ? null
                    : () => provider.markTaskDone(weddingPlanId, task),
                onDelete: () => _confirmDelete(context, provider, task.id),
              ),
            ),
          );
        }),

        const SizedBox(height: 32),
        _buildAnimated(provider.tasks.length + 3, _TimelineSections(timeline: timeline)),
      ],
    );
  }

  Widget _buildAnimated(int index, Widget child) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, childWidget) {
        final delay = (index * 0.1).clamp(0.0, 0.5);
        final value = (animationController.value - delay).clamp(0.0, 1.0);
        final curve = Curves.easeOutCubic.transform(value);
        return Transform.translate(
          offset: Offset(0, 30 * (1 - curve)),
          child: Opacity(
            opacity: curve,
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskTimelineProvider provider,
    String taskId,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.dCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.danger.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.trash2, color: AppTheme.danger, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'حذف المهمة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.dInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'هل أنت متأكد من رغبتك في حذف هذه المهمة؟ لا يمكن التراجع عن هذا الإجراء.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.dInkSoft,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        ),
                      ),
                      child: const Text('إلغاء', style: TextStyle(color: AppTheme.dMuted, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('نعم، احذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await provider.deleteTask(weddingPlanId, taskId);
    }
  }
}

class _SummaryTimelineWidget extends StatelessWidget {
  const _SummaryTimelineWidget({required this.timeline, required this.tasks});
  
  final Timeline timeline;
  final List<WeddingTask> tasks;

  @override
  Widget build(BuildContext context) {
    final doneTasks = tasks.where((t) => t.isDone).length;
    final totalTasks = tasks.length;
    final progress = totalTasks > 0 ? doneTasks / totalTasks : 0.0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.dMaroonDeep,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        gradient: AppTheme.heroGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroonDeep.withAlpha(60),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تقدم الإنجاز',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$doneTasks من $totalTasks مهام',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.sparkles, color: AppTheme.dGold, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.dGold,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.dGold.withAlpha(100),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModernTaskCard extends StatelessWidget {
  const _ModernTaskCard({
    required this.task,
    required this.onDelete,
    this.onMarkDone,
  });

  final WeddingTask task;
  final VoidCallback? onMarkDone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDone = task.isDone;
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDone ? AppTheme.dLine : AppTheme.dMaroon.withAlpha(30),
          width: 1,
        ),
        boxShadow: AppTheme.softShadow(opacity: isDone ? 0.01 : 0.04),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Stack(
          children: [
            if (!isDone)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  color: AppTheme.dMaroon,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onMarkDone,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? AppTheme.dGreen : Colors.transparent,
                        border: Border.all(
                          color: isDone ? AppTheme.dGreen : AppTheme.dMuted,
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDone ? AppTheme.dMuted : AppTheme.dInk,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (task.hasDescription) ...[
                          const SizedBox(height: 6),
                          Text(
                            task.description!,
                            style: TextStyle(
                              color: isDone ? AppTheme.dMuted.withAlpha(150) : AppTheme.dInkSoft,
                              fontSize: 13,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Badge(
                              label: _priorityLabel(task.priority),
                              color: _priorityColor(task.priority),
                            ),
                            if (task.dueDate != null)
                              _Badge(
                                label: _formatDate(task.dueDate!),
                                color: AppTheme.dMuted,
                                icon: LucideIcons.calendar,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(LucideIcons.moreVertical, color: AppTheme.dMuted),
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(LucideIcons.trash2, color: AppTheme.danger, size: 18),
                            SizedBox(width: 12),
                            Text('حذف المهمة', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineSections extends StatelessWidget {
  const _TimelineSections({required this.timeline});

  final Timeline timeline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            title: 'استحقاقات قادمة',
            emptyMessage: 'لا توجد استحقاقات قادمة.',
            isEmpty: timeline.upcomingTasks.isEmpty && timeline.dueDebts.isEmpty && timeline.dueInstallments.isEmpty,
          ),
          
          for (final task in timeline.upcomingTasks)
            _TimelineDueItemCard(
              title: task.title,
              subtitle: 'مهمة قادمة',
              status: task.status,
              dueDate: task.dueDate,
              icon: LucideIcons.listTodo,
              color: AppTheme.dMaroon,
            ),
          
          for (final debt in timeline.dueDebts)
            _TimelineDueItemCard(
              title: debt.title,
              subtitle: 'دين مستحق: ${debt.remainingAmount} YER',
              status: debt.status,
              dueDate: debt.dueDate,
              icon: LucideIcons.creditCard,
              color: AppTheme.danger,
            ),
            
          for (final installment in timeline.dueInstallments)
            _TimelineDueItemCard(
              title: 'قسط مستحق',
              subtitle: '${installment.amount} YER',
              status: installment.status,
              dueDate: installment.dueDate,
              icon: LucideIcons.wallet,
              color: AppTheme.warning,
            ),
        ],
      ),
    );
  }
}

class _TimelineDueItemCard extends StatelessWidget {
  const _TimelineDueItemCard({
    required this.title,
    required this.subtitle,
    required this.status,
    this.dueDate,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String status;
  final DateTime? dueDate;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.dInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (dueDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.dBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    dueDate!.day.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.dMaroon,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    dueDate!.month.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.dMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.dMaroonDeep,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.right,
          ),
          if (isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.dCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.dLine, style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.inbox, color: AppTheme.dMuted),
                  const SizedBox(width: 12),
                  Text(
                    emptyMessage,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: AppTheme.dMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

String _priorityLabel(String priority) {
  return switch (priority) {
    'LOW' => 'عادية',
    'MEDIUM' => 'متوسطة',
    'HIGH' => 'عاجلة',
    _ => priority,
  };
}

Color _priorityColor(String priority) {
  return switch (priority) {
    'LOW' => AppTheme.dBlue,
    'MEDIUM' => AppTheme.warning,
    'HIGH' => AppTheme.danger,
    _ => AppTheme.dMuted,
  };
}

String _formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
