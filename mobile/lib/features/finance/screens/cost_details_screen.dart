import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/money_widgets.dart';

class CostDetailsScreen extends StatefulWidget {
  const CostDetailsScreen({
    required this.weddingPlanId,
    required this.costId,
    super.key,
  });

  final String weddingPlanId;
  final String costId;

  @override
  State<CostDetailsScreen> createState() => _CostDetailsScreenState();
}

class _CostDetailsScreenState extends State<CostDetailsScreen> {
  bool _isLoadingDetails = true;
  final _scrollController = ScrollController();
  final _paymentsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refreshMoney = false}) async {
    if (!mounted) return;
    setState(() => _isLoadingDetails = true);
    final provider = context.read<FinanceProvider>();
    if (refreshMoney || provider.loadedPlanId != widget.weddingPlanId) {
      await provider.loadMoney(widget.weddingPlanId);
    }
    if (mounted && provider.canViewMoney) {
      await provider.loadCostDetails(widget.costId);
    }
    if (mounted) setState(() => _isLoadingDetails = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final cost = provider.costById(widget.costId);
    final payments = provider.paymentsForCost(widget.costId);
    final schedules = provider.schedulesForCost(widget.costId);
    final pendingSchedules = schedules.where((item) => item.isPending).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextSchedule = pendingSchedules.isEmpty
        ? null
        : pendingSchedules.first;
    final currency = provider.summary.currency;

    return MoneySubpageScaffold(
      title: 'تفاصيل التكلفة',
      subtitle: cost?.title ?? 'كل ما يخص التكلفة في مكان واحد.',
      showBack: true,
      onBack: _goBack,
      actions: [
        if (cost != null && provider.canManageMoney && !cost.isCancelled)
          _CostMoreMenu(
            canCancel: !cost.hasActivePayments,
            disabled: provider.isSubmitting,
            onEdit: () => _editCost(cost),
            onCancel: () => _confirmCancel(cost),
          ),
      ],
      child: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: () => _load(refreshMoney: true),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (_isLoadingDetails && cost == null)
              const AarastScreenLoading(label: 'جاري تحميل تفاصيل التكلفة')
            else if (provider.errorMessage != null && cost == null)
              AarastErrorState(
                title: 'تعذر تحميل التكلفة',
                message: provider.errorMessage!,
                onRetry: _load,
              )
            else if (cost == null)
              AarastEmptyState(
                icon: LucideIcons.receipt,
                title: 'التكلفة غير موجودة',
                message: 'ربما حُذفت أو لم تعد ضمن هذه الخطة.',
                action: OutlinedButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(LucideIcons.arrowRight),
                  label: const Text('العودة إلى التكاليف'),
                ),
              )
            else ...[
              if (provider.errorMessage != null) ...[
                MoneyMessageBanner(
                  message: provider.errorMessage!,
                  error: true,
                ),
                const SizedBox(height: 12),
              ],
              _CostHero(cost: cost, currency: currency),
              const SizedBox(height: 12),
              if (provider.canManageMoney && !cost.isCancelled)
                _CostPrimaryDecision(
                  cost: cost,
                  hasPendingSchedule: pendingSchedules.isNotEmpty,
                  onPay: () => _openRecordPayment(cost),
                  onSchedule: () => _openScheduleCreate(cost),
                  onViewPayments: _scrollToPayments,
                ),
              const SizedBox(height: 14),
              _CostContextCard(
                cost: cost,
                categoryName:
                    provider.categoryById(cost.budgetCategoryId)?.name ??
                    cost.categoryName,
              ),
              if (nextSchedule != null) ...[
                const SizedBox(height: 14),
                MoneySectionCard(
                  title: 'موعد الدفع القادم',
                  subtitle: 'أقرب موعد دفع معلق لهذه التكلفة.',
                  icon: LucideIcons.calendarClock,
                  child: ScheduleCard(
                    schedule: nextSchedule,
                    currency: currency,
                    costTitle: cost.title,
                    onTap: () => context.push(
                      AppRouter.moneyScheduleDetails(
                        widget.weddingPlanId,
                        cost.id,
                        nextSchedule.id,
                      ),
                    ),
                  ),
                ),
              ],
              if (!provider.canManageMoney) ...[
                const SizedBox(height: 14),
                const MoneyMessageBanner(
                  message:
                      'هذه التفاصيل للعرض فقط. إجراءات التعديل والدفع متاحة لمدير المال.',
                ),
              ],
              const SizedBox(height: 22),
              KeyedSubtree(
                key: _paymentsKey,
                child: AarastSectionHeader(
                  title: 'الدفعات',
                  subtitle: payments.isEmpty
                      ? 'لا توجد دفعات مسجلة لهذه التكلفة.'
                      : '${payments.length} حركة محفوظة في السجل.',
                  icon: LucideIcons.banknote,
                ),
              ),
              const SizedBox(height: 10),
              if (payments.isEmpty)
                const AarastEmptyState(
                  icon: LucideIcons.banknote,
                  title: 'لا توجد دفعات',
                  message: 'عند تسجيل دفعة ستظهر هنا كسجل يمكن مراجعته.',
                )
              else
                for (final payment in payments) ...[
                  PaymentCard(
                    payment: payment,
                    currency: currency,
                    costTitle: cost.title,
                    onTap: () => context.push(
                      AppRouter.moneyPaymentDetails(
                        widget.weddingPlanId,
                        payment.id,
                        costId: cost.id,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 12),
              AarastSectionHeader(
                title: 'مواعيد الدفع',
                subtitle: schedules.isEmpty
                    ? 'لا توجد مبالغ مجدولة بعد.'
                    : '${schedules.length} موعد مرتبط بهذه التكلفة.',
                icon: LucideIcons.calendarClock,
                actionLabel:
                    provider.canManageMoney &&
                        !cost.isCancelled &&
                        moneyValue(cost.remainingAmount) > 0
                    ? 'إضافة موعد'
                    : null,
                onAction:
                    provider.canManageMoney &&
                        !cost.isCancelled &&
                        moneyValue(cost.remainingAmount) > 0
                    ? () => _openScheduleCreate(cost)
                    : null,
              ),
              const SizedBox(height: 10),
              if (schedules.isEmpty)
                const AarastEmptyState(
                  icon: LucideIcons.calendarPlus,
                  title: 'لا توجد مواعيد دفع',
                  message: 'أضف موعدًا إذا كان جزء من المبلغ سيُدفع لاحقًا.',
                )
              else
                for (final schedule in schedules) ...[
                  ScheduleCard(
                    schedule: schedule,
                    currency: currency,
                    costTitle: cost.title,
                    onTap: () => context.push(
                      AppRouter.moneyScheduleDetails(
                        widget.weddingPlanId,
                        cost.id,
                        schedule.id,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editCost(WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneyCostEdit(widget.weddingPlanId, cost.id),
      extra: cost,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }

  Future<void> _scrollToPayments() async {
    final paymentsContext = _paymentsKey.currentContext;
    if (paymentsContext == null) return;
    await Scrollable.ensureVisible(
      paymentsContext,
      duration: AppTheme.motionMedium,
      curve: AppTheme.motionCurve,
      alignment: 0.08,
    );
  }

  Future<void> _openRecordPayment(WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneyPaymentCreate(widget.weddingPlanId, cost.id),
      extra: cost,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }

  Future<void> _openScheduleCreate(WeddingCost cost) async {
    final changed = await context.push<bool>(
      AppRouter.moneyScheduleCreate(widget.weddingPlanId, cost.id),
      extra: cost,
    );
    if (changed == true && mounted) await _load(refreshMoney: true);
  }

  Future<void> _confirmCancel(WeddingCost cost) async {
    final confirmed = await _confirmAction(
      title: 'إلغاء التكلفة؟',
      message:
          'ستخرج من الإجماليات وتُلغى مواعيد الدفع المفتوحة، بينما يبقى السجل محفوظًا للرجوع إليه.',
      actionLabel: 'إلغاء التكلفة',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<FinanceProvider>();
    final ok = await provider.cancelCost(cost);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(
        context,
        provider.savedMessage('تم إلغاء التكلفة.'),
      );
      await _load(refreshMoney: true);
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String actionLabel,
    required bool danger,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        icon: Icon(
          danger ? LucideIcons.alertTriangle : LucideIcons.info,
          color: danger ? AppTheme.danger : AppTheme.brand,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          AarastButton(
            label: actionLabel,
            expand: false,
            variant: danger
                ? AarastButtonVariant.danger
                : AarastButtonVariant.primary,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.moneyCosts(widget.weddingPlanId));
    }
  }
}

class _CostHero extends StatelessWidget {
  const _CostHero({required this.cost, required this.currency});

  final WeddingCost cost;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final total = moneyValue(cost.totalAmount);
    final paid = moneyValue(cost.paidAmount);
    final progress = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'الإجمالي',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MoneyStatusBadge(status: cost.status),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyAmountText(
              amount: cost.totalAmount,
              currency: currency,
              color: AppTheme.textPrimary,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 14),
          AarastV3ProgressLine(
            value: progress,
            height: 7,
            color: cost.isPaid ? AppTheme.success : AppTheme.brand,
            backgroundColor: AppTheme.border,
            semanticsLabel: 'نسبة سداد التكلفة',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CostHeroValue(
                  label: 'المدفوع',
                  amount: cost.paidAmount,
                  currency: currency,
                  color: AppTheme.success,
                ),
              ),
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: AppTheme.border,
              ),
              Expanded(
                child: _CostHeroValue(
                  label: 'غير مدفوع',
                  amount: cost.remainingAmount,
                  currency: currency,
                  color: moneyValue(cost.remainingAmount) > 0
                      ? AppTheme.warning
                      : AppTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CostHeroValue extends StatelessWidget {
  const _CostHeroValue({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  final String label;
  final Object? amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: MoneyAmountText(
            amount: amount,
            currency: currency,
            color: color,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class _CostContextCard extends StatelessWidget {
  const _CostContextCard({required this.cost, this.categoryName});

  final WeddingCost cost;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final party = cost.partyLabel;
    return MoneySectionCard(
      title: 'معلومات التكلفة',
      icon: LucideIcons.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            icon: LucideIcons.tags,
            label: 'التصنيف',
            value: categoryName ?? 'غير محدد',
          ),
          if (party != null)
            _InfoRow(
              icon: cost.providerId == null
                  ? LucideIcons.user
                  : LucideIcons.store,
              label: cost.providerId == null ? 'الجهة' : 'المزود',
              value: party,
              onTap: cost.providerId == null
                  ? null
                  : () => context.push(
                      AppRouter.providerDetails(cost.providerId!),
                    ),
            ),
          if (cost.partyPhone != null)
            _InfoRow(
              icon: LucideIcons.phone,
              label: 'رقم التواصل',
              value:
                  PhoneNumberUtils.directionalDisplay(cost.partyPhone) ??
                  cost.partyPhone!,
            ),
          if (cost.agreementDate != null)
            _InfoRow(
              icon: LucideIcons.calendarCheck,
              label: 'تاريخ الاتفاق',
              value: formatArabicCompactDate(cost.agreementDate!),
            ),
          if (cost.note != null)
            _InfoRow(
              icon: LucideIcons.fileText,
              label: 'ملاحظة',
              value: cost.note!,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.brand),
          const SizedBox(width: 9),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(
              LucideIcons.externalLink,
              size: 17,
              color: AppTheme.brand,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: 'فتح ملف $label: $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: content,
      ),
    );
  }
}

class _CostPrimaryDecision extends StatelessWidget {
  const _CostPrimaryDecision({
    required this.cost,
    required this.hasPendingSchedule,
    required this.onPay,
    required this.onSchedule,
    required this.onViewPayments,
  });

  final WeddingCost cost;
  final bool hasPendingSchedule;
  final VoidCallback onPay;
  final VoidCallback onSchedule;
  final VoidCallback onViewPayments;

  @override
  Widget build(BuildContext context) {
    final needsPayment = moneyValue(cost.remainingAmount) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const ValueKey('money-cost-primary-action'),
          onPressed: needsPayment ? onPay : onViewPayments,
          icon: Icon(needsPayment ? LucideIcons.banknote : LucideIcons.history),
          label: Text(needsPayment ? 'تسجيل دفعة' : 'عرض الدفعات'),
        ),
        if (needsPayment && !hasPendingSchedule) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onSchedule,
            icon: const Icon(LucideIcons.calendarPlus, size: 18),
            label: const Text('لا يوجد موعد قادم · أضف موعد دفع'),
          ),
        ],
      ],
    );
  }
}

class _CostMoreMenu extends StatelessWidget {
  const _CostMoreMenu({
    required this.canCancel,
    required this.disabled,
    required this.onEdit,
    required this.onCancel,
  });

  final bool canCancel;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CostMenuAction>(
      enabled: !disabled,
      tooltip: 'المزيد',
      icon: const Icon(LucideIcons.moreHorizontal),
      onSelected: (action) {
        switch (action) {
          case _CostMenuAction.edit:
            onEdit();
          case _CostMenuAction.cancel:
            onCancel();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _CostMenuAction.edit,
          child: Row(
            children: [
              Icon(LucideIcons.pencil, size: 18),
              SizedBox(width: 10),
              Flexible(child: Text('تعديل التكلفة')),
            ],
          ),
        ),
        if (canCancel)
          const PopupMenuItem(
            value: _CostMenuAction.cancel,
            child: Row(
              children: [
                Icon(
                  LucideIcons.circleSlash2,
                  size: 18,
                  color: AppTheme.danger,
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'إلغاء التكلفة',
                    style: TextStyle(color: AppTheme.danger),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _CostMenuAction { edit, cancel }
