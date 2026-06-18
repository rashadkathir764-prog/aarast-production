import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../auth/providers/auth_controller.dart';
import '../../sharing/models/shared_member.dart';
import '../../tasks/models/wedding_task.dart';
import '../models/wedding_plan.dart';
import '../providers/dashboard_summary_provider.dart';
import '../providers/wedding_plans_provider.dart';
import '../widgets/aarast_dashboard_widgets.dart';

class PlanCenterScreen extends StatefulWidget {
  const PlanCenterScreen({
    required this.weddingPlanId,
    this.sharedMember,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;

  @override
  State<PlanCenterScreen> createState() => _PlanCenterScreenState();
}

class _PlanCenterScreenState extends State<PlanCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardSummaryProvider>().loadDashboard(
        widget.weddingPlanId,
        sharedMember: widget.sharedMember,
      );
    });
  }

  @override
  void didUpdateWidget(covariant PlanCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId ||
        oldWidget.sharedMember != widget.sharedMember) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<DashboardSummaryProvider>().loadDashboard(
          widget.weddingPlanId,
          sharedMember: widget.sharedMember,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardSummaryProvider>();
    final auth = context.watch<AuthController>();
    final plan = provider.plan;
    final hasCurrentPlan = plan?.id == widget.weddingPlanId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: _buildBottomNav(provider),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: _pcInk,
            onRefresh: () => provider.loadDashboard(
              widget.weddingPlanId,
              sharedMember: widget.sharedMember,
            ),
            child: _buildBody(provider, auth, hasCurrentPlan),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    DashboardSummaryProvider provider,
    AuthController auth,
    bool hasCurrentPlan,
  ) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 118;

    if (provider.isLoading && !hasCurrentPlan) {
      return ListView(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        children: const [
          _PlanCenterHeader(),
          SizedBox(height: 10),
          _PlanCenterLoading(),
        ],
      );
    }

    if (provider.errorMessage != null && !hasCurrentPlan) {
      return ListView(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        children: [
          const _PlanCenterHeader(),
          const SizedBox(height: 10),
          _PcCard(
            padding: const EdgeInsets.all(18),
            child: _PcEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل مركز الخطة',
              message: provider.errorMessage!,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: _pcOutlinedButtonStyle(),
            onPressed: () => provider.loadDashboard(
              widget.weddingPlanId,
              sharedMember: widget.sharedMember,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    final plan = provider.plan;
    if (plan == null || !hasCurrentPlan) {
      return ListView(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        children: const [
          _PlanCenterHeader(),
          SizedBox(height: 10),
          _PcCard(
            padding: EdgeInsets.all(18),
            child: _PcEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'لا توجد خطة',
              message: 'لم يتم العثور على بيانات الخطة الحالية.',
            ),
          ),
        ],
      );
    }

    final tasksAvailable = provider.tasks != null;
    final tasks = provider.tasks ?? const <WeddingTask>[];
    final completedTasks = tasks.where((task) => task.isDone).length;
    final remainingTasks = math.max(0, tasks.length - completedTasks);
    final progressPercent = tasksAvailable && tasks.isNotEmpty
        ? ((completedTasks / tasks.length) * 100).round().clamp(0, 100)
        : tasksAvailable
        ? 0
        : null;
    final isOwner =
        auth.user?.id == plan.ownerUserId || widget.sharedMember == null;
    final canManagePlan = isOwner || widget.sharedMember?.role == 'MANAGER';
    final canOpenFinance =
        widget.sharedMember == null || widget.sharedMember!.hasFinancialAccess;
    final canOpenDebts =
        widget.sharedMember == null || widget.sharedMember!.canReadDebts;
    final canOpenSharing = widget.sharedMember == null;

    return ListView(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
      children: [
        const _PlanCenterHeader(),
        const SizedBox(height: 10),
        _MainPlanSummaryCard(
          plan: plan,
          progressPercent: progressPercent,
          completedTasks: completedTasks,
          totalTasks: tasksAvailable ? tasks.length : null,
          canManagePlan: canManagePlan,
          onEdit: () => _showEditPlanSheet(provider, plan),
        ),
        const SizedBox(height: 10),
        _ProgressSummaryCard(
          progressPercent: progressPercent,
          completedTasks: tasksAvailable ? completedTasks : null,
          remainingTasks: tasksAvailable ? remainingTasks : null,
          lastUpdate: plan.updatedAt,
        ),
        const SizedBox(height: 10),
        const _PlanTimelineCard(),
        const SizedBox(height: 10),
        _PlanSectionsCard(
          onTasks: () => context.push(AppRouter.tasks(plan.id)),
          onBudget: canOpenFinance
              ? () => _openFinanceOverview(provider, plan.id)
              : _showFinancialAccessDenied,
          onDebts: canOpenDebts
              ? () => context.push(
                  AppRouter.debts(plan.id),
                  extra: widget.sharedMember,
                )
              : _showFinancialAccessDenied,
          onGuests: () => context.push(AppRouter.guestList(plan.id)),
          onProviders: () => context.push(AppRouter.providerMarketplace),
          onSharing: canOpenSharing
              ? () => context.push(AppRouter.sharing(plan.id))
              : () => _showUnavailable('إدارة المشاركة متاحة لصاحب الخطة فقط.'),
          sharingEnabled: canOpenSharing,
          budgetEnabled: canOpenFinance,
          debtsEnabled: canOpenDebts,
        ),
        const SizedBox(height: 10),
        _ParticipantsCard(
          roleLabel: _roleLabel(isOwner, widget.sharedMember),
          participantsCount: provider.sharedMembers?.length,
          permissionsLabel: _permissionsLabel(isOwner, widget.sharedMember),
          canManageSharing: canOpenSharing,
          onManageSharing: () => context.push(AppRouter.sharing(plan.id)),
        ),
        const SizedBox(height: 10),
        _PlanSettingsCard(
          plan: plan,
          canManagePlan: canManagePlan,
          onEdit: () => _showEditPlanSheet(provider, plan),
          onArchive: () => _showArchivePlanSheet(provider, plan),
        ),
      ],
    );
  }

  Widget _buildBottomNav(DashboardSummaryProvider provider) {
    final planId = provider.plan?.id == widget.weddingPlanId
        ? provider.plan!.id
        : widget.weddingPlanId;
    return DashboardBottomNav(
      activeIndex: 4,
      onMore: () => context.go(AppRouter.home),
      onTasks: () => context.push(AppRouter.tasks(planId)),
      onAdd: () => _showQuickAdd(provider),
      onPlans: () => context.push(AppRouter.providerMarketplace),
      onHome: () => context.go(AppRouter.home),
    );
  }

  Future<void> _openFinanceOverview(
    DashboardSummaryProvider provider,
    String planId,
  ) async {
    final canOpenFinance =
        widget.sharedMember == null || widget.sharedMember!.hasFinancialAccess;
    if (!canOpenFinance) {
      _showFinancialAccessDenied();
      return;
    }

    final changed = await context.push<bool>(
      AppRouter.finance(planId),
      extra: widget.sharedMember,
    );
    if (changed == true && mounted) {
      await provider.loadDashboard(planId, sharedMember: widget.sharedMember);
    }
  }

  void _showQuickAdd(DashboardSummaryProvider provider) {
    final plan = provider.plan;
    if (plan == null || plan.id != widget.weddingPlanId) return;
    final canManageFinancialRecords =
        widget.sharedMember == null ||
        widget.sharedMember!.canManageFinancialRecords;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        Widget tile(
          IconData icon,
          String label,
          String route, {
          bool refreshDashboard = false,
        }) {
          return ListTile(
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final isFinancialWriteRoute =
                  route == AppRouter.createExpense(plan.id) ||
                  route == AppRouter.createDebt(plan.id);
              if (isFinancialWriteRoute && !canManageFinancialRecords) {
                _showFinancialAccessDenied();
                return;
              }
              final changed = await context.push<bool>(
                route,
                extra: widget.sharedMember,
              );
              if (!mounted) return;
              if (refreshDashboard && changed == true) {
                await provider.loadDashboard(
                  plan.id,
                  sharedMember: widget.sharedMember,
                );
              }
            },
            leading: _PcIconBox(icon: icon, compact: true),
            title: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _pcInk,
              ),
            ),
          );
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _pcLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'إضافة سريعة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _pcInk,
                        ),
                      ),
                    ),
                  ),
                  tile(
                    Icons.account_balance_wallet_outlined,
                    'إضافة مصروف',
                    AppRouter.createExpense(plan.id),
                    refreshDashboard: true,
                  ),
                  tile(
                    Icons.credit_card_rounded,
                    'إضافة دين',
                    AppRouter.createDebt(plan.id),
                  ),
                  tile(
                    Icons.check_circle_outline_rounded,
                    'إضافة مهمة',
                    AppRouter.createTask(plan.id),
                  ),
                  tile(
                    Icons.person_add_alt_1_outlined,
                    'إضافة ضيف',
                    AppRouter.guestList(plan.id),
                  ),
                  tile(
                    Icons.post_add_rounded,
                    'خطة جديدة',
                    AppRouter.createWeddingPlan,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditPlanSheet(
    DashboardSummaryProvider dashboardProvider,
    WeddingPlan plan,
  ) async {
    final weddingPlansProvider = context.read<WeddingPlansProvider>();
    final titleController = TextEditingController(text: plan.title);
    final cityController = TextEditingController(text: plan.city ?? '');
    var selectedDate = plan.weddingDate;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _pcLine,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'تعديل بيانات الخطة',
                          style: TextStyle(
                            color: _pcInk,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الخطة',
                            prefixIcon: Icon(Icons.edit_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: cityController,
                          decoration: const InputDecoration(
                            labelText: 'المدينة',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: _pcOutlinedButtonStyle(),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: sheetContext,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setSheetState(() => selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            selectedDate == null
                                ? 'اختيار تاريخ الزواج'
                                : _dateLabel(selectedDate),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) return;
                            final data = <String, dynamic>{
                              'title': title,
                              'city': cityController.text.trim(),
                              if (selectedDate != null)
                                'weddingDate': selectedDate!.toIso8601String(),
                            };
                            final updated = await weddingPlansProvider
                                .updateWeddingPlan(plan.id, data);
                            if (updated != null && sheetContext.mounted) {
                              Navigator.of(sheetContext).pop(true);
                            }
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('حفظ التعديل'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    titleController.dispose();
    cityController.dispose();

    if (saved == true && mounted) {
      await dashboardProvider.loadDashboard(
        plan.id,
        sharedMember: widget.sharedMember,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تم تحديث الخطة.')));
    } else {
      final error = weddingPlansProvider.errorMessage;
      if (error != null && mounted) _showUnavailable(error);
    }
  }

  Future<void> _showArchivePlanSheet(
    DashboardSummaryProvider dashboardProvider,
    WeddingPlan plan,
  ) async {
    final weddingPlansProvider = context.read<WeddingPlansProvider>();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'أرشفة الخطة؟',
                    style: TextStyle(
                      color: _pcInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيتم نقل "${plan.title}" إلى الأرشيف بدون حذف البيانات.',
                    style: const TextStyle(
                      color: _pcMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('أرشفة'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    final archived = await weddingPlansProvider.archiveWeddingPlan(plan.id);
    if (archived != null && mounted) {
      await dashboardProvider.loadDashboard(
        plan.id,
        sharedMember: widget.sharedMember,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تمت أرشفة الخطة.')));
    } else {
      final error = weddingPlansProvider.errorMessage;
      if (error != null && mounted) _showUnavailable(error);
    }
  }

  void _showFinancialAccessDenied() {
    _showUnavailable(
      'هذا القسم غير متاح حسب صلاحياتك ولا يتم عرض البيانات المالية الخاصة.',
    );
  }

  void _showUnavailable(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PlanCenterHeader extends StatelessWidget {
  const _PlanCenterHeader();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 78),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRouter.home);
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'رجوع',
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'مركز الخطة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _pcInk,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.calendar_month_outlined,
                      color: _pcInk,
                      size: 23,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  'تفاصيل الخطة الحالية',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _pcMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _MainPlanSummaryCard extends StatelessWidget {
  const _MainPlanSummaryCard({
    required this.plan,
    required this.progressPercent,
    required this.completedTasks,
    required this.totalTasks,
    required this.canManagePlan,
    required this.onEdit,
  });

  final WeddingPlan plan;
  final int? progressPercent;
  final int completedTasks;
  final int? totalTasks;
  final bool canManagePlan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _PcCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          final details = _PlanDetails(
            plan: plan,
            canManagePlan: canManagePlan,
            onEdit: onEdit,
          );
          final progress = _PlanProgressBlock(
            progressPercent: progressPercent,
            completedTasks: completedTasks,
            totalTasks: totalTasks,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 14),
                const Divider(height: 1, color: _pcLine),
                const SizedBox(height: 14),
                progress,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 6, child: details),
              const SizedBox(width: 14),
              Container(width: 1, height: 128, color: _pcLine),
              const SizedBox(width: 14),
              SizedBox(width: 108, child: progress),
            ],
          );
        },
      ),
    );
  }
}

class _PlanDetails extends StatelessWidget {
  const _PlanDetails({
    required this.plan,
    required this.canManagePlan,
    required this.onEdit,
  });

  final WeddingPlan plan;
  final bool canManagePlan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                plan.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _pcInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const _CurrentPlanBadge(),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _InlineMeta(
              icon: Icons.calendar_month_outlined,
              value: _dateLabel(plan.weddingDate),
            ),
            _InlineMeta(
              icon: Icons.location_on_outlined,
              value: _cityLabel(plan.city),
            ),
            _InlineMeta(
              icon: Icons.timer_outlined,
              value: _daysRemainingLabel(plan.daysRemaining),
            ),
          ],
        ),
        if (canManagePlan) ...[
          const SizedBox(height: 13),
          SizedBox(
            height: 39,
            child: OutlinedButton.icon(
              style: _pcOutlinedButtonStyle(),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(
                'تعديل بيانات الخطة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlanProgressBlock extends StatelessWidget {
  const _PlanProgressBlock({
    required this.progressPercent,
    required this.completedTasks,
    required this.totalTasks,
  });

  final int? progressPercent;
  final int completedTasks;
  final int? totalTasks;

  @override
  Widget build(BuildContext context) {
    final taskValue = totalTasks == null
        ? 'غير متاح'
        : '$completedTasks/$totalTasks';

    return Column(
      children: [
        _ProgressRing(percent: progressPercent),
        const SizedBox(height: 10),
        Text(
          taskValue,
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _pcInk,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'المهام',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _pcText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProgressSummaryCard extends StatelessWidget {
  const _ProgressSummaryCard({
    required this.progressPercent,
    required this.completedTasks,
    required this.remainingTasks,
    required this.lastUpdate,
  });

  final int? progressPercent;
  final int? completedTasks;
  final int? remainingTasks;
  final DateTime lastUpdate;

  @override
  Widget build(BuildContext context) {
    return _PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PcSectionTitle(
            title: 'ملخص التقدم',
            icon: Icons.donut_large_rounded,
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            children: [
              _MetricTile(
                icon: Icons.donut_large_rounded,
                label: 'نسبة الإنجاز',
                value: progressPercent == null
                    ? 'غير متاح'
                    : '$progressPercent%',
              ),
              _MetricTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'المكتملة',
                value: completedTasks?.toString() ?? 'غير متاح',
              ),
              _MetricTile(
                icon: Icons.description_outlined,
                label: 'المتبقية',
                value: remainingTasks?.toString() ?? 'غير متاح',
              ),
              _MetricTile(
                icon: Icons.event_available_outlined,
                label: 'آخر تحديث',
                value: _lastUpdateLabel(lastUpdate),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanTimelineCard extends StatelessWidget {
  const _PlanTimelineCard();

  @override
  Widget build(BuildContext context) {
    const steps = [
      _TimelineStep(
        icon: Icons.event_available_outlined,
        title: 'اليوم',
        subtitle: 'استكمال المهام اليومية',
        active: true,
      ),
      _TimelineStep(
        icon: Icons.assignment_outlined,
        title: 'هذا الأسبوع',
        subtitle: 'ترتيب التفاصيل القريبة',
      ),
      _TimelineStep(
        icon: Icons.cake_outlined,
        title: 'قبل الزواج',
        subtitle: 'تحضيرات نهائية ومراجعة',
      ),
      _TimelineStep(
        icon: Icons.favorite_border_rounded,
        title: 'يوم الزواج',
        subtitle: 'اليوم الكبير والاحتفال',
      ),
    ];

    return _PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PcSectionTitle(
            title: 'الخط الزمني',
            icon: Icons.timeline_rounded,
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (var i = 0; i < steps.length; i++)
                _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanSectionsCard extends StatelessWidget {
  const _PlanSectionsCard({
    required this.onTasks,
    required this.onBudget,
    required this.onDebts,
    required this.onGuests,
    required this.onProviders,
    required this.onSharing,
    required this.sharingEnabled,
    required this.budgetEnabled,
    required this.debtsEnabled,
  });

  final VoidCallback onTasks;
  final VoidCallback onBudget;
  final VoidCallback onDebts;
  final VoidCallback onGuests;
  final VoidCallback onProviders;
  final VoidCallback onSharing;
  final bool sharingEnabled;
  final bool budgetEnabled;
  final bool debtsEnabled;

  @override
  Widget build(BuildContext context) {
    return _PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PcSectionTitle(
            title: 'أقسام الخطة',
            icon: Icons.dashboard_customize_outlined,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 300 ? 2 : 3;
              final itemWidth =
                  (constraints.maxWidth - (8 * (columns - 1))) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.assignment_outlined,
                      label: 'المهام',
                      onTap: onTasks,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'الميزانية',
                      onTap: onBudget,
                      enabled: budgetEnabled,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.savings_outlined,
                      label: 'الديون',
                      onTap: onDebts,
                      enabled: debtsEnabled,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.groups_2_outlined,
                      label: 'الضيوف',
                      onTap: onGuests,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.storefront_outlined,
                      label: 'الموردون',
                      onTap: onProviders,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SectionLink(
                      icon: Icons.group_add_outlined,
                      label: 'المشاركة',
                      onTap: onSharing,
                      enabled: sharingEnabled,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ParticipantsCard extends StatelessWidget {
  const _ParticipantsCard({
    required this.roleLabel,
    required this.participantsCount,
    required this.permissionsLabel,
    required this.canManageSharing,
    required this.onManageSharing,
  });

  final String roleLabel;
  final int? participantsCount;
  final String permissionsLabel;
  final bool canManageSharing;
  final VoidCallback onManageSharing;

  @override
  Widget build(BuildContext context) {
    return _PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PcSectionTitle(
            title: 'المشاركون والصلاحيات',
            icon: Icons.people_outline_rounded,
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            children: [
              _MetricTile(
                icon: Icons.person_outline_rounded,
                label: 'الدور',
                value: roleLabel,
              ),
              _MetricTile(
                icon: Icons.groups_outlined,
                label: 'المشاركون',
                value: participantsCount?.toString() ?? 'غير متاح',
              ),
              _MetricTile(
                icon: Icons.verified_user_outlined,
                label: 'الصلاحيات',
                value: permissionsLabel,
              ),
            ],
          ),
          if (canManageSharing) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                style: _pcOutlinedButtonStyle(),
                onPressed: onManageSharing,
                icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                label: const Text(
                  'إدارة المشاركة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanSettingsCard extends StatelessWidget {
  const _PlanSettingsCard({
    required this.plan,
    required this.canManagePlan,
    required this.onEdit,
    required this.onArchive,
  });

  final WeddingPlan plan;
  final bool canManagePlan;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final disabledSubtitle = canManagePlan ? null : 'يتطلب صلاحية إدارة الخطة';
    return _PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PcSectionTitle(
            title: 'إعدادات الخطة',
            icon: Icons.settings_outlined,
          ),
          const SizedBox(height: 8),
          _SettingsRow(
            icon: Icons.edit_outlined,
            title: 'تغيير اسم الخطة',
            subtitle: disabledSubtitle ?? plan.title,
            enabled: canManagePlan,
            onTap: onEdit,
          ),
          _SettingsRow(
            icon: Icons.calendar_month_outlined,
            title: 'تغيير تاريخ الزواج',
            subtitle: disabledSubtitle ?? _dateLabel(plan.weddingDate),
            enabled: canManagePlan,
            onTap: onEdit,
          ),
          _SettingsRow(
            icon: Icons.location_on_outlined,
            title: 'تغيير المدينة',
            subtitle: disabledSubtitle ?? _cityLabel(plan.city),
            enabled: canManagePlan,
            onTap: onEdit,
          ),
          _SettingsRow(
            icon: Icons.archive_outlined,
            title: 'أرشفة الخطة',
            subtitle: canManagePlan
                ? 'نقلها للأرشيف بدون حذف البيانات'
                : disabledSubtitle!,
            enabled: canManagePlan && plan.status != 'ARCHIVED',
            onTap: onArchive,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_pcRadius),
        border: Border.all(color: _pcLine, width: 0.9),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _pcInk, size: 20),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _pcText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _pcInk,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 280 ? 1 : 2;
        final itemWidth =
            (constraints.maxWidth - (8 * (columns - 1))) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _SectionLink extends StatelessWidget {
  const _SectionLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? _pcInk : _pcMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? _pcText : _pcMuted;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _pcLine, width: 0.8)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _pcMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              enabled ? Icons.chevron_left_rounded : Icons.lock_outline_rounded,
              color: _pcMuted,
              size: enabled ? 20 : 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});

  final _TimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: step.active ? _pcInk : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _pcInk, width: 1),
                ),
              ),
              if (!isLast) Container(width: 1, height: 46, color: _pcLine),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: _PcIconBox(icon: step.icon, compact: true),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  step.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _pcInk,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _pcMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.active = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.percent});

  final int? percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: CustomPaint(
        painter: _ProgressRingPainter((percent ?? 0) / 100),
        child: Center(
          child: Text(
            percent == null ? '-' : '$percent%',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: _pcInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 12) / 2;
    final track = Paint()
      ..color = _pcLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final arc = Paint()
      ..color = _pcMuted
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = 10;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _PcCard extends StatelessWidget {
  const _PcCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_pcRadius),
        border: Border.all(color: _pcLine, width: 0.9),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _PcSectionTitle extends StatelessWidget {
  const _PcSectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _pcInk, size: 20),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _pcInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _pcText, size: 18),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 136),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _pcInk,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrentPlanBadge extends StatelessWidget {
  const _CurrentPlanBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _pcSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _pcLine, width: 0.8),
      ),
      child: const Text(
        'الخطة الحالية',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _pcMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PcIconBox extends StatelessWidget {
  const _PcIconBox({required this.icon, this.compact = false});

  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 40.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _pcLine, width: 0.8),
      ),
      child: Icon(icon, color: _pcInk, size: compact ? 19 : 22),
    );
  }
}

class _PcEmptyState extends StatelessWidget {
  const _PcEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: _pcMuted, size: 34),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _pcInk,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _pcMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PlanCenterLoading extends StatelessWidget {
  const _PlanCenterLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SkeletonBox(height: 170),
        SizedBox(height: 10),
        _SkeletonBox(height: 124),
        SizedBox(height: 10),
        _SkeletonBox(height: 132),
        SizedBox(height: 10),
        _SkeletonBox(height: 112),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _pcSoft,
        borderRadius: BorderRadius.circular(_pcRadius),
        border: Border.all(color: _pcLine),
      ),
    );
  }
}

const _pcInk = Color(0xFF111111);
const _pcText = Color(0xFF333333);
const _pcMuted = Color(0xFF777777);
const _pcLine = Color(0xFFD8D8D8);
const _pcSoft = Color(0xFFF5F5F5);
const _pcRadius = 10.0;

ButtonStyle _pcOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: _pcInk,
    disabledForegroundColor: _pcMuted,
    side: const BorderSide(color: _pcInk, width: 0.8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
  );
}

String _dateLabel(DateTime? date) {
  return date == null ? 'غير محدد' : dashFormatArDate(date);
}

String _cityLabel(String? city) {
  return city?.trim().isNotEmpty == true ? city!.trim() : 'غير محددة';
}

String _daysRemainingLabel(int? days) {
  if (days == null) return 'غير محدد';
  if (days < 0) return 'انتهى الموعد';
  if (days == 0) return 'اليوم';
  return 'باقي $days يوم';
}

String _lastUpdateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final updateDay = DateTime(date.year, date.month, date.day);
  if (updateDay == today) return 'اليوم';
  return dashFormatArDate(date);
}

String _roleLabel(bool isOwner, SharedMember? member) {
  if (isOwner) return 'صاحب';
  if (member == null) return 'غير متاح';
  return 'مشارك: ${sharedMemberRoleLabel(member.role)}';
}

String _permissionsLabel(bool isOwner, SharedMember? member) {
  if (isOwner) return 'كاملة';
  if (member == null) return 'غير متاح';
  if (member.permissionLabels.isEmpty) return 'مهام فقط';
  return member.permissionLabels.take(2).join('، ');
}
