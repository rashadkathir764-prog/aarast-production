import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../debts/data/debt_installment_api.dart';
import '../../debts/models/installment.dart';
import '../../home/providers/home_dashboard_provider.dart';
import '../../tasks/data/task_timeline_api.dart';
import '../../tasks/models/wedding_task.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({this.weddingPlanId, super.key});

  final String? weddingPlanId;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<_NotificationBundle>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.weddingPlanId == null) {
        context.read<HomeDashboardProvider>().loadDashboard();
      } else {
        setState(() {
          _future = _loadPlanAlerts(widget.weddingPlanId!);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId &&
        widget.weddingPlanId != null) {
      _future = _loadPlanAlerts(widget.weddingPlanId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AarastPageScaffold(
      title: 'التنبيهات',
      subtitle: 'مواعيد ومهام تحتاج انتباهك',
      child: widget.weddingPlanId == null ? _homeAlerts() : _planAlerts(),
    );
  }

  Widget _homeAlerts() {
    final provider = context.watch<HomeDashboardProvider>();
    if (provider.isLoading && provider.primaryPlan == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = [
      for (final task in (provider.tasks ?? []))
        if (!task.isDone && _isNear(task.dueDate)) _AlertEntry.task(task),
      for (final installment in (provider.dueInstallments ?? []))
        _AlertEntry.installment(installment),
    ];

    return _AlertsList(items: items, onRefresh: provider.loadDashboard);
  }

  Widget _planAlerts() {
    final future = _future;
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<_NotificationBundle>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            children: [
              AarastEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'تعذر تحميل التنبيهات',
                message: 'راجعي اتصالك وحاولي مرة أخرى.',
                action: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _future = _loadPlanAlerts(widget.weddingPlanId!);
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ),
            ],
          );
        }

        final bundle = snapshot.data ?? const _NotificationBundle();
        final items = [
          for (final task in bundle.tasks)
            if (!task.isDone && _isNear(task.dueDate)) _AlertEntry.task(task),
          for (final installment in bundle.installments)
            _AlertEntry.installment(installment),
        ];
        return _AlertsList(
          items: items,
          onRefresh: () async {
            setState(() {
              _future = _loadPlanAlerts(widget.weddingPlanId!);
            });
            await _future;
          },
        );
      },
    );
  }

  Future<_NotificationBundle> _loadPlanAlerts(String weddingPlanId) async {
    final tasksApi = context.read<TaskTimelineApi>();
    final debtsApi = context.read<DebtInstallmentApi>();
    final results = await Future.wait<Object>([
      tasksApi.getTasks(weddingPlanId),
      debtsApi.getDueInstallments(weddingPlanId),
    ]);
    return _NotificationBundle(
      tasks: results[0] as List<WeddingTask>,
      installments: results[1] as List<Installment>,
    );
  }
}

class _AlertsList extends StatelessWidget {
  const _AlertsList({required this.items, required this.onRefresh});

  final List<_AlertEntry> items;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 90),
            AarastEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'لا توجد تنبيهات الآن',
              message:
                  'كل شيء مرتب. ستظهر هنا المهام القريبة والأقساط المستحقة.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.dMaroon,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _AlertCard(entry: items[index]),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.entry});

  final _AlertEntry entry;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: entry.background,
      border: Border.all(color: entry.color.withAlpha(60)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.dCard2,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(entry.icon, color: entry.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: entry.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  entry.body,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
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

class _NotificationBundle {
  const _NotificationBundle({
    this.tasks = const [],
    this.installments = const [],
  });

  final List<WeddingTask> tasks;
  final List<Installment> installments;
}

class _AlertEntry {
  const _AlertEntry({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.background,
  });

  factory _AlertEntry.task(WeddingTask task) {
    return _AlertEntry(
      title: task.title,
      body: task.dueDate == null
          ? 'مهمة مفتوحة بدون تاريخ. حددي موعدًا لها من قائمة المهام.'
          : 'تستحق في ${_formatDate(task.dueDate!)}. الأولوية: ${_priority(task.priority)}.',
      icon: Icons.assignment_turned_in_outlined,
      color: task.priority == 'HIGH' ? AppTheme.danger : AppTheme.dMaroon,
      background: AppTheme.dPinkBg.withAlpha(180),
    );
  }

  factory _AlertEntry.installment(Installment installment) {
    return _AlertEntry(
      title: 'قسط مستحق',
      body: installment.dueDate == null
          ? 'قسط بقيمة ${installment.amount} يحتاج متابعة.'
          : 'قسط بقيمة ${installment.amount} مستحق في ${_formatDate(installment.dueDate!)}.',
      icon: Icons.credit_card_rounded,
      color: AppTheme.dGoldDeep,
      background: AppTheme.dCreamBg,
    );
  }

  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final Color background;
}

bool _isNear(DateTime? date) {
  if (date == null) return true;
  final today = DateTime.now();
  final due = DateTime(date.year, date.month, date.day);
  final current = DateTime(today.year, today.month, today.day);
  return due.difference(current).inDays <= 7;
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

String _priority(String value) {
  return switch (value) {
    'HIGH' => 'عالية',
    'LOW' => 'منخفضة',
    _ => 'متوسطة',
  };
}
