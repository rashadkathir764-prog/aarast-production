import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
    final currency = provider.summary.currency;

    return AarastPageScaffold(
      title: 'تفاصيل التكلفة',
      subtitle: cost?.title ?? 'كل ما يخص التكلفة في مكان واحد.',
      showBack: true,
      onBack: _goBack,
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: () => _load(refreshMoney: true),
        child: ListView(
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
              const SizedBox(height: 14),
              _CostContextCard(
                cost: cost,
                categoryName:
                    provider.categoryById(cost.budgetCategoryId)?.name ??
                    cost.categoryName,
              ),
              const SizedBox(height: 14),
              if (!provider.canManageMoney)
                const MoneyMessageBanner(
                  message:
                      'هذه التفاصيل للعرض فقط. إجراءات التعديل والدفع متاحة لمدير المال.',
                )
              else
                _CostActions(
                  cost: cost,
                  isSubmitting: provider.isSubmitting,
                  hasSchedules: schedules.isNotEmpty,
                  onEdit: () => _editCost(cost),
                  onCancel: () => _confirmCancel(cost),
                  onDelete: () => _confirmDelete(cost),
                ),
              const SizedBox(height: 22),
              AarastSectionHeader(
                title: 'الدفعات',
                subtitle: payments.isEmpty
                    ? 'لا توجد دفعات مسجلة لهذه التكلفة.'
                    : '${payments.length} حركة محفوظة في السجل.',
                icon: LucideIcons.banknote,
                actionLabel:
                    provider.canManageMoney &&
                        !cost.isCancelled &&
                        moneyValue(cost.remainingAmount) > 0
                    ? 'تسجيل دفعة'
                    : null,
                onAction:
                    provider.canManageMoney &&
                        !cost.isCancelled &&
                        moneyValue(cost.remainingAmount) > 0
                    ? () => _openRecordPayment(cost)
                    : null,
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
      AarastToast.showSuccess(context, 'تم إلغاء التكلفة.');
      await _load(refreshMoney: true);
    }
  }

  Future<void> _confirmDelete(WeddingCost cost) async {
    final confirmed = await _confirmAction(
      title: 'حذف التكلفة نهائيًا؟',
      message:
          'الحذف متاح فقط قبل وجود دفعات أو مواعيد. لا يمكن التراجع عن هذه الخطوة.',
      actionLabel: 'حذف نهائي',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<FinanceProvider>();
    final ok = await provider.deleteCost(cost);
    if (!mounted || !ok) return;
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go(AppRouter.moneyCosts(widget.weddingPlanId));
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
          color: danger ? AppTheme.danger : AppTheme.burgundy,
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  cost.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MoneyStatusBadge(status: cost.status),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = <Widget>[
                MoneyMetricCard(
                  label: 'الإجمالي',
                  amount: cost.totalAmount,
                  currency: currency,
                  icon: LucideIcons.receipt,
                ),
                MoneyMetricCard(
                  label: 'المدفوع',
                  amount: cost.paidAmount,
                  currency: currency,
                  icon: LucideIcons.checkCircle,
                  color: AppTheme.success,
                ),
                MoneyMetricCard(
                  label: 'الباقي',
                  amount: cost.remainingAmount,
                  currency: currency,
                  icon: LucideIcons.clock3,
                  color: moneyValue(cost.remainingAmount) > 0
                      ? AppTheme.warning
                      : AppTheme.success,
                ),
              ];
              if (constraints.maxWidth < 430) {
                return Column(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      metrics[index],
                      if (index != metrics.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < metrics.length; index++) ...[
                    Expanded(child: metrics[index]),
                    if (index != metrics.length - 1) const SizedBox(width: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
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
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'معلومات التكلفة',
            icon: LucideIcons.info,
          ),
          const SizedBox(height: 12),
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
              value: cost.partyPhone!,
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
          Icon(icon, size: 18, color: AppTheme.burgundy),
          const SizedBox(width: 9),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(
              LucideIcons.externalLink,
              size: 17,
              color: AppTheme.burgundy,
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

class _CostActions extends StatelessWidget {
  const _CostActions({
    required this.cost,
    required this.isSubmitting,
    required this.hasSchedules,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
  });

  final WeddingCost cost;
  final bool isSubmitting;
  final bool hasSchedules;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (cost.isCancelled) {
      return const MoneyMessageBanner(
        message: 'هذه التكلفة ملغاة وسجلها محفوظ للرجوع إليه.',
      );
    }
    final canDelete = cost.canDelete && !hasSchedules;
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'إدارة التكلفة',
            subtitle:
                'الإجراءات موجودة هنا فقط حتى تبقى القائمة الرئيسية نظيفة.',
            icon: LucideIcons.settings2,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: isSubmitting ? null : onEdit,
                icon: const Icon(LucideIcons.pencil),
                label: const Text('تعديل'),
              ),
              if (!cost.hasActivePayments)
                OutlinedButton.icon(
                  onPressed: isSubmitting ? null : onCancel,
                  icon: const Icon(LucideIcons.circleSlash2),
                  label: const Text('إلغاء'),
                ),
              if (canDelete)
                OutlinedButton.icon(
                  onPressed: isSubmitting ? null : onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                  ),
                  icon: const Icon(LucideIcons.trash2),
                  label: const Text('حذف'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
