import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/sync_status.dart';
import '../../../core/routing/app_router.dart';
import '../../auth/providers/auth_controller.dart';
import '../../debts/models/installment.dart';
import '../../sharing/models/shared_member.dart';
import '../../tasks/models/wedding_task.dart';
import '../providers/dashboard_summary_provider.dart';
import '../widgets/aarast_dashboard_widgets.dart';

class WeddingPlanDashboardScreen extends StatefulWidget {
  const WeddingPlanDashboardScreen({
    required this.weddingPlanId,
    this.sharedMember,
    this.embedded = false,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;

  /// When hosted inside the [MainShell] tab stack, the shell owns the bottom
  /// navigation, so the screen hides its own and lets detail pages push over
  /// the persistent shell.
  final bool embedded;

  @override
  State<WeddingPlanDashboardScreen> createState() =>
      _WeddingPlanDashboardScreenState();
}

class _WeddingPlanDashboardScreenState
    extends State<WeddingPlanDashboardScreen> {
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
  void didUpdateWidget(covariant WeddingPlanDashboardScreen oldWidget) {
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: widget.embedded ? null : _buildBottomNav(provider),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: _wireInk,
            onRefresh: () => provider.loadDashboard(
              widget.weddingPlanId,
              sharedMember: widget.sharedMember,
            ),
            child: _buildContent(context, provider, auth),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(DashboardSummaryProvider provider) {
    final planId = provider.plan?.id ?? widget.weddingPlanId;
    return DashboardBottomNav(
      activeIndex: 4,
      onMore: () => context.go(AppRouter.home),
      onTasks: () => context.go(AppRouter.tasks(planId)),
      onAdd: () => _showQuickAdd(provider),
      onPlans: () => context.push(AppRouter.providerMarketplace),
      onHome: () {},
    );
  }

  void _openAccountSheet(AuthController auth) {
    showAccountSheet(
      context,
      name: auth.user?.name ?? 'مستخدم أعرست',
      phone: auth.user?.phone,
      onLogout: () async {
        await context.read<AuthController>().logout();
        if (mounted) context.go(AppRouter.login);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    DashboardSummaryProvider provider,
    AuthController auth,
  ) {
    final bottomPadding = widget.embedded ? 132.0 : 150.0;

    if (provider.isLoading && provider.plan == null) {
      return ListView(
        key: const ValueKey('skeleton'),
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        children: const [_WireLoading()],
      );
    }

    if (provider.errorMessage != null && provider.plan == null) {
      return ListView(
        key: const ValueKey('error'),
        padding: EdgeInsets.fromLTRB(12, 20, 12, bottomPadding),
        children: [
          _WireEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'تعذر تحميل اللوحة',
            message: provider.errorMessage!,
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              style: _wireButtonStyle(),
              onPressed: () => provider.loadDashboard(
                widget.weddingPlanId,
                sharedMember: widget.sharedMember,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    final plan = provider.plan;
    if (plan == null) {
      return ListView(
        key: const ValueKey('empty'),
        padding: EdgeInsets.fromLTRB(12, 20, 12, bottomPadding),
        children: const [
          _WireEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'لا توجد خطة',
            message: 'لم يتم العثور على خطة الزفاف الحالية.',
          ),
        ],
      );
    }

    final planId = plan.id;
    final tasks = provider.tasks ?? const <WeddingTask>[];
    final tasksDone = tasks.where((task) => task.isDone).length;
    final tasksTotal = tasks.length;
    final pendingTasks = _sortedPendingTasks(tasks);
    final canReadBudget =
        widget.sharedMember == null || widget.sharedMember!.canReadBudget;
    final canReadExpenses =
        widget.sharedMember == null || widget.sharedMember!.canReadExpenses;
    final canReadDebts =
        widget.sharedMember == null || widget.sharedMember!.canReadDebts;
    final canOpenFinance =
        widget.sharedMember == null || widget.sharedMember!.hasFinancialAccess;
    final totalBudget = canReadBudget
        ? dashParseAmount(plan.estimatedBudget)
        : 0.0;
    final spent = canReadExpenses
        ? dashParseAmount(provider.expenseSummary?.totalPaid)
        : 0.0;
    final plannedExpenses = canReadExpenses
        ? dashParseAmount(provider.expenseSummary?.totalPlanned)
        : 0.0;
    final remainingBudget = math.max(0.0, totalBudget - spent);
    final debtSummary = provider.debtSummary;
    final debtTotal = canReadDebts
        ? dashParseAmount(debtSummary?.totalDebt)
        : 0.0;
    final debtPaid = canReadDebts
        ? dashParseAmount(debtSummary?.totalPaid)
        : 0.0;
    final debtRemaining = canReadDebts
        ? dashParseAmount(debtSummary?.remainingDebt)
        : 0.0;
    final dueInstallments = canReadDebts
        ? _sortedInstallments(provider.dueInstallments ?? const [])
        : const <Installment>[];
    final sharedMembers = provider.sharedMembers ?? const <SharedMember>[];
    final progressPercent = tasksTotal == 0
        ? 0
        : ((tasksDone / tasksTotal) * 100).round().clamp(0, 100);
    final budgetPercent = totalBudget <= 0
        ? 0
        : ((spent / totalBudget) * 100).round().clamp(0, 100);
    final sync = _watchSyncService(context);

    return ListView(
      key: const ValueKey('content'),
      padding: EdgeInsets.fromLTRB(12, 6, 12, bottomPadding),
      children: [
        _WireHeader(
          sync: sync,
          onNotifications: () =>
              context.push(AppRouter.planNotifications(planId)),
          onProfile: () => _openAccountSheet(auth),
        ),
        const SizedBox(height: 8),
        _WirePlanCard(
          title: plan.title,
          city: plan.city,
          weddingDate: plan.weddingDate,
          daysRemaining: plan.daysRemaining,
          progressPercent: progressPercent,
          tasksDone: tasksDone,
          tasksTotal: tasksTotal,
          onOpen: () => context.push(
            AppRouter.planCenter(planId),
            extra: widget.sharedMember,
          ),
        ),
        const SizedBox(height: 8),
        _WireAssistantCard(
          advice: _assistantAdvice(
            pendingTasks: pendingTasks,
            dueInstallments: dueInstallments,
            canReadDebts: canReadDebts,
            canReadExpenses: canReadExpenses,
            totalBudget: totalBudget,
            spent: spent,
          ),
          onAsk: _showAiNotEnabled,
          onPlanDay: () => context.push(AppRouter.tasks(planId)),
        ),
        const SizedBox(height: 8),
        _WireTwoColumnRow(
          right: _WireSectionCard(
            title: 'المال',
            icon: Icons.account_balance_wallet_outlined,
            onTap: canOpenFinance
                ? () => _openFinanceOverview(provider, planId)
                : _showFinancialAccessDenied,
            footer: canOpenFinance ? 'عرض المال' : null,
            child: canOpenFinance
                ? _WireMetricGrid(
                    metrics: [
                      _WireMetric(
                        label: 'الميزانية',
                        value: canReadBudget
                            ? _moneyOrUnset(totalBudget, plan.currency)
                            : 'مخفية',
                      ),
                      _WireMetric(
                        label: 'المصروف',
                        value: canReadExpenses
                            ? _moneyOrUnset(spent, plan.currency)
                            : 'مخفي',
                      ),
                      _WireMetric(
                        label: 'المتبقي',
                        value: canReadBudget && canReadExpenses
                            ? _moneyOrUnset(remainingBudget, plan.currency)
                            : 'مخفي',
                      ),
                      _WireMetric(
                        label: 'نسبة الصرف',
                        value: canReadBudget && canReadExpenses
                            ? '$budgetPercent%'
                            : 'مخفية',
                      ),
                    ],
                  )
                : const _WireLocked(
                    message: 'الأرقام المالية مخفية حسب صلاحياتك.',
                  ),
          ),
          left: _WireSectionCard(
            title: 'الديون والأقساط',
            icon: Icons.layers_outlined,
            onTap: canReadDebts
                ? () => context.push(
                    AppRouter.debts(planId),
                    extra: widget.sharedMember,
                  )
                : _showFinancialAccessDenied,
            footer: canReadDebts ? 'عرض الديون والأقساط' : null,
            child: canReadDebts
                ? _WireMetricGrid(
                    metrics: [
                      _WireMetric(
                        label: 'الإجمالي',
                        value: _moneyOrUnset(debtTotal, plan.currency),
                      ),
                      _WireMetric(
                        label: 'المدفوع',
                        value: _moneyOrUnset(debtPaid, plan.currency),
                      ),
                      _WireMetric(
                        label: 'المتبقي',
                        value: _moneyOrUnset(debtRemaining, plan.currency),
                      ),
                      _WireMetric(
                        label: 'أقرب قسط',
                        value: dueInstallments.isEmpty
                            ? 'لا يوجد'
                            : _dateOrUnset(dueInstallments.first.dueDate),
                      ),
                    ],
                  )
                : const _WireLocked(
                    message: 'الديون والأقساط مخفية حسب صلاحياتك.',
                  ),
          ),
        ),
        const SizedBox(height: 8),
        _WireTwoColumnRow(
          right: _WireSectionCard(
            title: 'المهام القريبة',
            icon: Icons.checklist_rounded,
            onTap: () => context.push(AppRouter.tasks(planId)),
            footer: 'عرض كل المهام',
            child: _WireTaskList(tasks: pendingTasks.take(3).toList()),
          ),
          left: _WireSectionCard(
            title: 'التنبيهات',
            icon: Icons.notifications_none_rounded,
            onTap: () => context.push(AppRouter.planNotifications(planId)),
            child: _WireAlertList(
              rows: _alertRows(
                pendingTasks: pendingTasks,
                dueInstallments: dueInstallments,
                canReadDebts: canReadDebts,
                budgetPercent: budgetPercent,
                plannedExpenses: plannedExpenses,
                canReadExpenses: canReadExpenses,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _WireTwoColumnRow(
          right: _WireSectionCard(
            title: 'الضيوف',
            icon: Icons.groups_2_outlined,
            onTap: () => context.push(AppRouter.guestList(planId)),
            child: const _WireHonestNote(
              icon: Icons.groups_outlined,
              title: 'قائمة ضيوف محلية',
              message: 'لا يوجد ملخص مزامنة ضيوف حقيقي في اللوحة بعد.',
            ),
          ),
          left: _WireSectionCard(
            title: 'الموردون والعروض',
            icon: Icons.storefront_outlined,
            onTap: () => context.push(AppRouter.providerMarketplace),
            child: const _WirePlaceholderList(
              rows: [
                'طلبات عروض السعر من صفحة الموردين',
                'الموردون المحفوظون غير ملخصين هنا بعد',
                'لا يوجد ربط مباشر بالموردين داخل الخطة',
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _WireSharingSummaryCard(
          sharedMembers: sharedMembers,
          onTap: () => context.push(AppRouter.sharing(planId)),
        ),
        const SizedBox(height: 8),
        _WireSyncCard(sync: sync),
      ],
    );
  }

  void _showAiNotEnabled() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('مساعد أعرست غير مربوط بذكاء اصطناعي مباشر بعد.'),
        ),
      );
  }

  void _showQuickAdd(DashboardSummaryProvider provider) {
    final plan = provider.plan;
    if (plan == null) return;
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
              if (refreshDashboard && changed == true && mounted) {
                await provider.loadDashboard(
                  plan.id,
                  sharedMember: widget.sharedMember,
                );
              }
            },
            leading: _WireSmallIcon(icon),
            title: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _wireInk,
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
                      color: _wireLine,
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
                          color: _wireInk,
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

  void _showFinancialAccessDenied() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'الميزانية خاصة. ليست لديك صلاحية عرض التفاصيل المالية.',
          ),
        ),
      );
  }
}

const _wireInk = Color(0xFF111111);
const _wireText = Color(0xFF333333);
const _wireMuted = Color(0xFF777777);
const _wireLine = Color(0xFFD8D8D8);
const _wireSoft = Color(0xFFF5F5F5);
const _wireCardRadius = 10.0;

ButtonStyle _wireButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: _wireInk,
    side: const BorderSide(color: _wireInk, width: 0.8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
  );
}

OfflineSyncService? _watchSyncService(BuildContext context) {
  try {
    return context.watch<OfflineSyncService>();
  } catch (_) {
    return null;
  }
}

List<WeddingTask> _sortedPendingTasks(List<WeddingTask> tasks) {
  final pending = tasks.where((task) => !task.isDone).toList();
  pending.sort((a, b) => _compareNullableDates(a.dueDate, b.dueDate));
  return pending;
}

List<Installment> _sortedInstallments(List<Installment> installments) {
  final sorted = installments.toList();
  sorted.sort((a, b) => _compareNullableDates(a.dueDate, b.dueDate));
  return sorted;
}

int _compareNullableDates(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

String _dateOrUnset(DateTime? date) {
  return date == null ? 'غير محدد' : dashFormatArDate(date);
}

String _moneyOrUnset(num value, String currency) {
  if (value <= 0) return 'غير محدد';
  return '${_compactNumber(value)} ${_currencyLabel(currency)}';
}

String _compactNumber(num value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs >= 1000000) {
    final compact = abs / 1000000;
    return '$sign${_compactDecimal(compact)}M';
  }
  if (abs >= 1000) {
    final compact = abs / 1000;
    return '$sign${_compactDecimal(compact)}K';
  }
  return '$sign${dashFormatMoney(abs)}';
}

String _compactDecimal(num value) {
  final rounded = value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return rounded.endsWith('.0')
      ? rounded.substring(0, rounded.length - 2)
      : rounded;
}

String _currencyLabel(String currency) {
  return switch (currency.toUpperCase()) {
    'YER' => 'ر.ي',
    'SAR' => 'ر.س',
    'USD' => '\$',
    _ => currency,
  };
}

String _daysLabel(int? days) {
  if (days == null) return 'غير محدد';
  if (days < 0) return 'انتهى الموعد';
  if (days == 0) return 'اليوم';
  return '$days يوم';
}

String _syncLabel(OfflineSyncService? sync) {
  final state = sync?.state ?? SyncState.synced;
  return switch (state) {
    SyncState.offline => 'بدون اتصال',
    SyncState.syncing => 'جاري المزامنة',
    SyncState.syncError => 'خطأ مزامنة',
    SyncState.hasPendingChanges => 'متصل',
    SyncState.online => 'متصل',
    SyncState.synced => 'متصل',
  };
}

IconData _syncIcon(OfflineSyncService? sync) {
  final state = sync?.state ?? SyncState.synced;
  return switch (state) {
    SyncState.offline => Icons.wifi_off_rounded,
    SyncState.syncing => Icons.sync_rounded,
    SyncState.syncError => Icons.cloud_off_outlined,
    _ => Icons.sync_rounded,
  };
}

String _lastSyncLabel(OfflineSyncService? sync) {
  final value = sync?.lastSyncedAt;
  if (value == null) return 'لم تتم مزامنة بعد';
  return dashFormatArDate(value);
}

List<String> _assistantAdvice({
  required List<WeddingTask> pendingTasks,
  required List<Installment> dueInstallments,
  required bool canReadDebts,
  required bool canReadExpenses,
  required double totalBudget,
  required double spent,
}) {
  final rows = <String>[];
  if (pendingTasks.isNotEmpty) {
    final task = pendingTasks.first;
    rows.add(
      task.dueDate == null
          ? 'راجع المهمة: ${task.title}'
          : 'أقرب مهمة: ${task.title} - ${dashFormatArDate(task.dueDate!)}',
    );
  }
  if (canReadDebts && dueInstallments.isNotEmpty) {
    rows.add('عندك قسط قريب: ${_dateOrUnset(dueInstallments.first.dueDate)}');
  }
  if (canReadExpenses && totalBudget > 0 && spent > totalBudget) {
    rows.add('المصروفات تجاوزت الميزانية المحددة.');
  }
  if (rows.isEmpty) {
    rows.add('لا يوجد تنبيه عاجل من بيانات الخطة الحالية.');
  }
  rows.add('لا يوجد ذكاء اصطناعي مباشر مفعّل بعد.');
  return rows.take(3).toList();
}

List<_WireListItem> _alertRows({
  required List<WeddingTask> pendingTasks,
  required List<Installment> dueInstallments,
  required bool canReadDebts,
  required int budgetPercent,
  required double plannedExpenses,
  required bool canReadExpenses,
}) {
  final rows = <_WireListItem>[];
  if (canReadDebts && dueInstallments.isNotEmpty) {
    rows.add(
      _WireListItem(
        icon: Icons.payments_outlined,
        title: 'قسط مستحق',
        subtitle: _dateOrUnset(dueInstallments.first.dueDate),
      ),
    );
  }
  if (pendingTasks.isNotEmpty) {
    rows.add(
      _WireListItem(
        icon: Icons.warning_amber_rounded,
        title: 'مهمة قريبة',
        subtitle: pendingTasks.first.title,
      ),
    );
  }
  if (canReadExpenses && plannedExpenses > 0) {
    rows.add(
      _WireListItem(
        icon: Icons.local_offer_outlined,
        title: 'مصروف مخطط',
        subtitle: 'راجع البنود غير المدفوعة',
      ),
    );
  } else if (canReadExpenses && budgetPercent >= 80) {
    rows.add(
      _WireListItem(
        icon: Icons.report_gmailerrorred_outlined,
        title: 'تنبيه ميزانية',
        subtitle: 'نسبة الصرف $budgetPercent%',
      ),
    );
  }
  return rows.take(3).toList();
}

class _WireHeader extends StatelessWidget {
  const _WireHeader({
    required this.sync,
    required this.onNotifications,
    required this.onProfile,
  });

  final OfflineSyncService? sync;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'أعرست',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _wireInk,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          _WireSyncPill(sync: sync),
          const SizedBox(width: 8),
          _WireCircleButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'التنبيهات',
            onTap: onNotifications,
          ),
          const SizedBox(width: 8),
          _WireCircleButton(
            icon: Icons.person_outline_rounded,
            tooltip: 'الملف الشخصي',
            onTap: onProfile,
          ),
        ],
      ),
    );
  }
}

class _WireSyncPill extends StatelessWidget {
  const _WireSyncPill({required this.sync});

  final OfflineSyncService? sync;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        border: Border.all(color: _wireLine, width: 0.8),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_syncIcon(sync), color: _wireMuted, size: 15),
          const SizedBox(width: 4),
          Text(
            _syncLabel(sync),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _wireText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _wireMuted,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _WireCircleButton extends StatelessWidget {
  const _WireCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _wireLine, width: 0.9),
          ),
          child: Icon(icon, color: _wireInk, size: 22),
        ),
      ),
    );
  }
}

class _WirePlanCard extends StatelessWidget {
  const _WirePlanCard({
    required this.title,
    required this.city,
    required this.weddingDate,
    required this.daysRemaining,
    required this.progressPercent,
    required this.tasksDone,
    required this.tasksTotal,
    required this.onOpen,
  });

  final String title;
  final String? city;
  final DateTime? weddingDate;
  final int? daysRemaining;
  final int progressPercent;
  final int tasksDone;
  final int tasksTotal;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _WireCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(_wireCardRadius),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _WireTitle(
                    title: 'الخطة الحالية',
                    icon: Icons.calendar_month_outlined,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _wireInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _WireProgressBar(percent: progressPercent),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _WireTinyMeta(
                          icon: Icons.event_outlined,
                          label: 'تاريخ الزواج',
                          value: _dateOrUnset(weddingDate),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _WireTinyMeta(
                          icon: Icons.location_on_outlined,
                          label: 'المدينة',
                          value: city?.trim().isNotEmpty == true
                              ? city!.trim()
                              : 'غير محددة',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 84, color: _wireLine),
            const SizedBox(width: 12),
            SizedBox(
              width: 116,
              child: Column(
                children: [
                  _WireProgressRing(percent: progressPercent),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _WireMiniCounter(
                          label: 'باقي',
                          value: _daysLabel(daysRemaining),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _WireMiniCounter(
                          label: 'المهام',
                          value: tasksTotal == 0
                              ? '0'
                              : '$tasksDone/$tasksTotal',
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

class _WireAssistantCard extends StatelessWidget {
  const _WireAssistantCard({
    required this.advice,
    required this.onAsk,
    required this.onPlanDay,
  });

  final List<String> advice;
  final VoidCallback onAsk;
  final VoidCallback onPlanDay;

  @override
  Widget build(BuildContext context) {
    return _WireCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  style: _wireButtonStyle(),
                  onPressed: onAsk,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text('اسأل المساعد'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: _wireButtonStyle(),
                  onPressed: onPlanDay,
                  icon: const Icon(Icons.today_outlined, size: 17),
                  label: const Text('رتب يومي'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _WireTitle(
                  title: 'مساعد أعرست',
                  icon: Icons.auto_awesome_outlined,
                ),
                const SizedBox(height: 8),
                for (final row in advice) _WireBullet(text: row),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _WireBotFace(),
        ],
      ),
    );
  }
}

class _WireTwoColumnRow extends StatelessWidget {
  const _WireTwoColumnRow({required this.right, required this.left});

  final Widget right;
  final Widget left;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: right),
          const SizedBox(width: 8),
          Expanded(child: left),
        ],
      ),
    );
  }
}

class _WireSectionCard extends StatelessWidget {
  const _WireSectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.footer,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = _WireCard(
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WireTitle(title: title, icon: icon),
          const SizedBox(height: 7),
          Expanded(child: child),
          if (footer != null) ...[
            const SizedBox(height: 7),
            Container(height: 1, color: _wireLine),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.chevron_left_rounded,
                  size: 17,
                  color: _wireInk,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    footer!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _wireInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_wireCardRadius),
        child: content,
      ),
    );
  }
}

class _WireMetric {
  const _WireMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class _WireMetricGrid extends StatelessWidget {
  const _WireMetricGrid({required this.metrics});

  final List<_WireMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < metrics.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _WireMetricTile(metric: metrics[i])),
                const SizedBox(width: 6),
                Expanded(child: _WireMetricTile(metric: metrics[i + 1])),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _WireMetricTile extends StatelessWidget {
  const _WireMetricTile({required this.metric});

  final _WireMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _wireLine, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            metric.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _wireText,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.value,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _wireInk,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: _wireLine,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _WireTaskList extends StatelessWidget {
  const _WireTaskList({required this.tasks});

  final List<WeddingTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _WireHonestNote(
        icon: Icons.check_circle_outline_rounded,
        title: 'لا توجد مهام قريبة',
        message: 'ستظهر هنا المهام غير المكتملة عند توفرها.',
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final task in tasks) ...[
          _WireListRow(
            item: _WireListItem(
              icon: _taskIcon(task),
              title: task.title,
              subtitle: _dateOrUnset(task.dueDate),
            ),
          ),
          if (task != tasks.last) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _WireAlertList extends StatelessWidget {
  const _WireAlertList({required this.rows});

  final List<_WireListItem> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _WireHonestNote(
        icon: Icons.notifications_none_rounded,
        title: 'لا توجد تنبيهات',
        message: 'لا يوجد قسط أو مهمة قريبة من البيانات الحالية.',
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final row in rows) ...[
          _WireListRow(item: row),
          if (row != rows.last) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _WireListItem {
  const _WireListItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _WireListRow extends StatelessWidget {
  const _WireListRow({required this.item});

  final _WireListItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _wireLine, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: _wireInk, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _wireInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _wireMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: _wireMuted, size: 16),
        ],
      ),
    );
  }
}

class _WirePlaceholderList extends StatelessWidget {
  const _WirePlaceholderList({required this.rows});

  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final row in rows) ...[
          _WireBullet(text: row),
          if (row != rows.last) const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _WireSharingSummaryCard extends StatelessWidget {
  const _WireSharingSummaryCard({
    required this.sharedMembers,
    required this.onTap,
  });

  final List<SharedMember> sharedMembers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = sharedMembers.length;
    final managers = sharedMembers
        .where((member) => member.role == 'MANAGER' || member.canManageTasks)
        .length;
    final financeAllowed = sharedMembers
        .where((member) => member.hasFinancialAccess)
        .length;
    final content = _WireCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _WireTitle(title: 'المشاركة', icon: Icons.group_add_outlined),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 108,
                child: Row(
                  children: [
                    for (var i = 0; i < math.min(count, 3); i++)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 4),
                        child: _WireAvatar(label: sharedMembers[i].displayName),
                      ),
                    _WireAvatar(label: '+', muted: true),
                  ],
                ),
              ),
              Expanded(
                child: _WireSyncMetric(
                  icon: Icons.groups_2_outlined,
                  label: 'المشاركون',
                  value: count == 0 ? 'لا يوجد' : '$count',
                ),
              ),
              Container(width: 1, height: 42, color: _wireLine),
              Expanded(
                child: _WireSyncMetric(
                  icon: Icons.verified_user_outlined,
                  label: 'الصلاحيات',
                  value: count == 0 ? 'غير محددة' : '$managers مدير',
                ),
              ),
              Container(width: 1, height: 42, color: _wireLine),
              Expanded(
                child: _WireSyncMetric(
                  icon: Icons.lock_outline_rounded,
                  label: 'البيانات المالية',
                  value: financeAllowed == 0
                      ? 'محمية'
                      : '$financeAllowed مسموح',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'بعض البيانات حساسة وتحتاج صلاحيات',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _wireMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_wireCardRadius),
        child: content,
      ),
    );
  }
}

class _WireSyncCard extends StatelessWidget {
  const _WireSyncCard({required this.sync});

  final OfflineSyncService? sync;

  @override
  Widget build(BuildContext context) {
    final pending = sync?.pendingCount ?? 0;
    return _WireCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _WireTitle(
            title: 'حالة الاتصال والمزامنة',
            icon: Icons.cloud_sync_outlined,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _WireSyncMetric(
                  icon: Icons.wifi_rounded,
                  label: 'الحالة',
                  value: _syncLabel(sync),
                ),
              ),
              Container(width: 1, height: 42, color: _wireLine),
              Expanded(
                child: _WireSyncMetric(
                  icon: Icons.schedule_rounded,
                  label: 'آخر مزامنة',
                  value: _lastSyncLabel(sync),
                ),
              ),
              Container(width: 1, height: 42, color: _wireLine),
              Expanded(
                child: _WireSyncMetric(
                  icon: Icons.sync_rounded,
                  label: 'بانتظار المزامنة',
                  value: '$pending',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WireSyncMetric extends StatelessWidget {
  const _WireSyncMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(
        children: [
          Icon(icon, color: _wireInk, size: 19),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _wireText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _wireInk,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WireCard extends StatelessWidget {
  const _WireCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_wireCardRadius),
        border: Border.all(color: _wireLine, width: 0.9),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _WireTitle extends StatelessWidget {
  const _WireTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _wireInk, size: 18),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _wireInk,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}

class _WireBullet extends StatelessWidget {
  const _WireBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: _wireMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _wireText,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _WireProgressBar extends StatelessWidget {
  const _WireProgressBar({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        minHeight: 10,
        value: (percent / 100).clamp(0.0, 1.0),
        backgroundColor: _wireLine,
        valueColor: const AlwaysStoppedAnimation<Color>(_wireMuted),
      ),
    );
  }
}

class _WireProgressRing extends StatelessWidget {
  const _WireProgressRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: CustomPaint(
        painter: _WireRingPainter(percent / 100),
        child: Center(
          child: Text(
            '$percent%',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: _wireInk,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _WireRingPainter extends CustomPainter {
  const _WireRingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 9) / 2;
    final track = Paint()
      ..color = _wireLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    final arc = Paint()
      ..color = _wireMuted
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = 8;

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
  bool shouldRepaint(covariant _WireRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _WireTinyMeta extends StatelessWidget {
  const _WireTinyMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _wireText, size: 16),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _wireMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _wireInk,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WireMiniCounter extends StatelessWidget {
  const _WireMiniCounter({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _wireInk,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _wireMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WireBotFace extends StatelessWidget {
  const _WireBotFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _wireLine, width: 1),
        color: _wireSoft,
      ),
      child: const Icon(Icons.smart_toy_outlined, color: _wireInk, size: 29),
    );
  }
}

class _WireSmallIcon extends StatelessWidget {
  const _WireSmallIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _wireLine, width: 0.8),
      ),
      child: Icon(icon, color: _wireInk, size: 19),
    );
  }
}

class _WireLocked extends StatelessWidget {
  const _WireLocked({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _WireHonestNote(
        icon: Icons.lock_outline_rounded,
        title: 'قسم خاص',
        message: message,
      ),
    );
  }
}

class _WireHonestNote extends StatelessWidget {
  const _WireHonestNote({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _wireMuted, size: 25),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _wireInk,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _wireMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _WireAvatar extends StatelessWidget {
  const _WireAvatar({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? '?' : label.trim().characters.first;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? Colors.white : _wireSoft,
        shape: BoxShape.circle,
        border: Border.all(color: _wireLine, width: 0.9),
      ),
      child: Text(
        muted ? '+' : initial,
        style: const TextStyle(
          color: _wireInk,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WireLoading extends StatelessWidget {
  const _WireLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _box(54),
        const SizedBox(height: 8),
        _box(150),
        const SizedBox(height: 8),
        _box(120),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _box(150)),
            const SizedBox(width: 8),
            Expanded(child: _box(150)),
          ],
        ),
      ],
    );
  }

  Widget _box(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _wireSoft,
        borderRadius: BorderRadius.circular(_wireCardRadius),
        border: Border.all(color: _wireLine),
      ),
    );
  }
}

class _WireEmptyState extends StatelessWidget {
  const _WireEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _WireCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Icon(icon, color: _wireMuted, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _wireInk,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _wireMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _taskIcon(WeddingTask task) {
  final normalized = '${task.taskCategory ?? ''} ${task.title}'.toLowerCase();
  if (normalized.contains('photo') || normalized.contains('تصوير')) {
    return Icons.photo_camera_outlined;
  }
  if (normalized.contains('gift') || normalized.contains('هدايا')) {
    return Icons.card_giftcard_outlined;
  }
  if (normalized.contains('hall') || normalized.contains('قاعة')) {
    return Icons.event_available_outlined;
  }
  return Icons.radio_button_unchecked_rounded;
}
