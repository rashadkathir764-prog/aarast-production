import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/local_database.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../home/home_api.dart' show LocalGuestDashboardSummarySource;
import '../../onboarding/onboarding_api.dart' show GuestOnboardingStorage;
import '../../tasks/tasks_api.dart' show TaskTimelineProvider, WeddingTask;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummary, DashboardSummaryProvider, publishTaskPlanPulse;
import '../widgets/wedding_day_mode_view.dart';

class WeddingDayModeScreen extends StatefulWidget {
  const WeddingDayModeScreen({
    required this.weddingPlanId,
    this.initialSummary,
    super.key,
  });

  final String weddingPlanId;
  final DashboardSummary? initialSummary;

  @override
  State<WeddingDayModeScreen> createState() => _WeddingDayModeScreenState();
}

class _WeddingDayModeScreenState extends State<WeddingDayModeScreen> {
  DashboardSummary? _localSummary;
  bool _localLoading = false;
  String? _localError;

  bool get _isLocalPlan =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  @override
  void didUpdateWidget(covariant WeddingDayModeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final tasks = context.read<TaskTimelineProvider>();
    if (_isLocalPlan) {
      await Future.wait([
        _loadLocalSummary(),
        tasks.load(widget.weddingPlanId),
      ]);
      return;
    }
    await Future.wait([
      context.read<DashboardSummaryProvider>().loadDashboard(
        widget.weddingPlanId,
      ),
      tasks.load(widget.weddingPlanId),
    ]);
  }

  Future<void> _loadLocalSummary() async {
    if (mounted) {
      setState(() {
        _localLoading = true;
        _localError = null;
      });
    }
    try {
      final source = LocalGuestDashboardSummarySource(
        context.read<GuestOnboardingStorage>(),
        database: _localDatabaseOrNull(),
      );
      final summary = await source.loadSummary();
      if (!mounted) return;
      if (summary == null) {
        throw StateError('Local wedding plan summary is unavailable.');
      }
      setState(() => _localSummary = summary.toDashboardSummary());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localError = 'تعذر تحديث بيانات اليوم الكبير؛ نعرض آخر بيانات محفوظة.';
      });
    } finally {
      if (mounted) setState(() => _localLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardSummaryProvider>();
    final tasks = context.watch<TaskTimelineProvider>();
    final providerSummary = dashboard.summary?.planId == widget.weddingPlanId
        ? dashboard.summary
        : null;
    final summary = _isLocalPlan
        ? _localSummary ?? widget.initialSummary
        : providerSummary ?? widget.initialSummary;
    final planTasks = tasks.tasks
        .where((task) => task.weddingPlanId == widget.weddingPlanId)
        .toList();
    final loading = _localPlanLoading(dashboard, tasks);
    final notice = _notice(dashboard, tasks);

    return AarastScreenFrame(
      maxWidth: 600,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: AarastPageHeader(
              title: 'اليوم الكبير',
              showBack: true,
              onBack: () => context.pop(),
            ),
          ),
          Expanded(
            child: summary == null
                ? _MissingSummaryState(
                    loading: loading,
                    message:
                        _localError ??
                        dashboard.errorMessage ??
                        'تعذر تحميل الخطة.',
                    onRetry: _load,
                  )
                : WeddingDayModeView(
                    summary: summary,
                    tasks: planTasks,
                    isLoading: loading,
                    notice: notice,
                    onRefresh: _load,
                    onCompleteTask: _completeTask,
                    onCopyPhone: _copyPhone,
                    onOpenTasks: () =>
                        context.push(AppRouter.tasks(widget.weddingPlanId)),
                    onOpenGuests: () =>
                        context.push(AppRouter.guestList(widget.weddingPlanId)),
                    onOpenProviders: () => context.push(
                      AppRouter.planProviders(widget.weddingPlanId),
                    ),
                    onOpenProvider: (provider) => context.push(
                      AppRouter.providerDetails(
                        provider.providerId,
                        weddingPlanId: widget.weddingPlanId,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _localPlanLoading(
    DashboardSummaryProvider dashboard,
    TaskTimelineProvider tasks,
  ) {
    return (_isLocalPlan ? _localLoading : dashboard.isLoading) ||
        tasks.isLoading;
  }

  String? _notice(
    DashboardSummaryProvider dashboard,
    TaskTimelineProvider tasks,
  ) {
    final messages = <String>[
      ?_localError,
      if (!_isLocalPlan && dashboard.errorMessage != null)
        'تعذر تحديث ملخص الخطة؛ نعرض آخر بيانات محفوظة.',
      if (tasks.errorMessage != null)
        'تعذر تحديث المهام؛ نعرض ما هو محفوظ على الجهاز.',
    ];
    return messages.isEmpty ? null : messages.join(' ');
  }

  Future<void> _completeTask(WeddingTask task) async {
    final provider = context.read<TaskTimelineProvider>();
    if (provider.isSubmitting) return;
    final success = await provider.markTaskDone(widget.weddingPlanId, task);
    if (!mounted) return;
    if (!success) {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر إنجاز المهمة.',
      );
      return;
    }
    publishTaskPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
    AarastToast.showSuccess(
      context,
      'تم إنجاز المهمة.',
      action: SnackBarAction(
        label: 'تراجع',
        onPressed: () => unawaited(_undoTask(task)),
      ),
    );
  }

  Future<void> _undoTask(WeddingTask task) async {
    final provider = context.read<TaskTimelineProvider>();
    final current = provider.tasks.firstWhere(
      (item) => item.id == task.id,
      orElse: () => task.copyWith(status: 'DONE'),
    );
    final success = await provider.reopenTask(widget.weddingPlanId, current);
    if (!mounted) return;
    if (!success) {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر التراجع الآن.',
      );
      return;
    }
    publishTaskPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
    AarastToast.showInfo(context, 'أُعيدت المهمة إلى القائمة.');
  }

  Future<void> _copyPhone(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    AarastToast.showSuccess(context, 'تم نسخ الرقم.');
  }

  LocalDatabase? _localDatabaseOrNull() {
    try {
      return context.read<LocalDatabase>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _MissingSummaryState extends StatelessWidget {
  const _MissingSummaryState({
    required this.loading,
    required this.message,
    required this.onRetry,
  });

  final bool loading;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AarastScreenLoading(label: 'نرتّب اليوم الكبير…');
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AarastEmptyState(
          icon: LucideIcons.calendarX,
          title: 'تعذر فتح اليوم الكبير',
          message: message,
          action: AarastButton(
            label: 'إعادة المحاولة',
            icon: LucideIcons.refreshCw,
            expand: false,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}
