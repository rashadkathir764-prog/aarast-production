import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/finance_provider.dart';

class CreateExpenseScreen extends StatefulWidget {
  const CreateExpenseScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _budgetCategoryId;
  String _status = 'PLANNED';
  DateTime? _expenseDate;
  
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FinanceProvider>();
      if (provider.budgetCategories.isEmpty) {
        provider.loadFinance(widget.weddingPlanId);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showDatePicker() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    DateTime tempDate = _expenseDate ?? now;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.dCard.withAlpha(240),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.dLine,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.dPinkBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(LucideIcons.calendarDays, color: AppTheme.dMaroon),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'تاريخ المصروف',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.dMaroonDeep,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: AppTheme.dMaroon,
                            onPrimary: Colors.white,
                            surface: Colors.transparent,
                            onSurface: AppTheme.dInk,
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: tempDate,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 10),
                          onDateChanged: (date) {
                            tempDate = date;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.dMaroon,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            ),
                          ),
                          onPressed: () {
                            setState(() => _expenseDate = tempDate);
                            Navigator.pop(sheetContext);
                          },
                          child: const Text(
                            'تأكيد التاريخ',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCategoryPicker() {
    FocusScope.of(context).unfocus();
    final provider = context.read<FinanceProvider>();
    
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: AppTheme.dCard.withAlpha(240),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.dLine,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.dGold.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(LucideIcons.folder, color: AppTheme.dGoldDeep),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'تصنيف الميزانية',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.dInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: provider.budgetCategories.isEmpty
                        ? const Center(child: Text('لا توجد تصنيفات، يرجى إضافة تصنيف أولاً.'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            itemCount: provider.budgetCategories.length + 1,
                            itemBuilder: (context, index) {
                              final isNone = index == 0;
                              final categoryId = isNone ? null : provider.budgetCategories[index - 1].id;
                              final categoryName = isNone ? 'بدون تصنيف' : provider.budgetCategories[index - 1].name;
                              final isSelected = _budgetCategoryId == categoryId;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() => _budgetCategoryId = categoryId);
                                      Navigator.pop(sheetContext);
                                    },
                                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isSelected ? AppTheme.dMaroon : AppTheme.dLine,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                        color: isSelected ? AppTheme.dPinkBg.withAlpha(100) : Colors.transparent,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isNone ? LucideIcons.minusCircle : LucideIcons.folder,
                                            color: isSelected ? AppTheme.dMaroon : AppTheme.dMuted,
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            categoryName,
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                              color: isSelected ? AppTheme.dMaroonDeep : AppTheme.dInk,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (isSelected)
                                            const Icon(LucideIcons.checkCircle2, color: AppTheme.dMaroon),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.dGold.withAlpha(20),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRouter.finance(widget.weddingPlanId));
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
                          child: const Icon(Icons.arrow_back_rounded, color: AppTheme.dInk),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'إضافة مصروف',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppTheme.dInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAnimated(
                            0,
                            Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.dGold.withAlpha(20),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.dLine),
                                  ),
                                  child: const Icon(LucideIcons.wallet, color: AppTheme.dGoldDeep, size: 36),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'تتبعي مصروفاتك بدقة وسهولة 💰',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.dInkSoft,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),

                          _buildAnimated(
                            1,
                            TextFormField(
                              controller: _titleController,
                              textAlign: TextAlign.right,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                labelText: 'عنوان المصروف',
                                hintText: 'مثال: دفعة قاعة الأفراح',
                                prefixIcon: const Icon(LucideIcons.penTool),
                                filled: true,
                                fillColor: AppTheme.dCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty ? 'عنوان المصروف مطلوب' : null,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildAnimated(
                            2,
                            TextFormField(
                              controller: _amountController,
                              textAlign: TextAlign.right,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.dMaroonDeep),
                              decoration: InputDecoration(
                                labelText: 'المبلغ',
                                prefixIcon: const Icon(LucideIcons.coins),
                                suffixText: 'YER',
                                filled: true,
                                fillColor: AppTheme.dCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                              ),
                              validator: (value) {
                                final parsed = num.tryParse(value?.trim() ?? '');
                                if (parsed == null || parsed < 0) return 'المبلغ غير صحيح';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildAnimated(
                            3,
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _showCategoryPicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.dCard,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                        border: Border.all(color: AppTheme.dLine),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(LucideIcons.folder, color: AppTheme.dMuted),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('التصنيف', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.dInkSoft)),
                                                Text(
                                                  _getCategoryName(_budgetCategoryId),
                                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.dInk, fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(LucideIcons.chevronDown, color: AppTheme.dMuted, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _showDatePicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.dCard,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                        border: Border.all(
                                          color: _expenseDate != null ? AppTheme.dMaroon : AppTheme.dLine,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(LucideIcons.calendarDays, color: _expenseDate != null ? AppTheme.dMaroon : AppTheme.dMuted),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (_expenseDate != null)
                                                  const Text('التاريخ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.dInkSoft)),
                                                Text(
                                                  _expenseDate == null ? 'التاريخ' : '${_expenseDate!.year}/${_expenseDate!.month}/${_expenseDate!.day}',
                                                  style: TextStyle(
                                                    fontWeight: _expenseDate != null ? FontWeight.w800 : FontWeight.w600,
                                                    color: _expenseDate != null ? AppTheme.dInk : AppTheme.dMuted,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildAnimated(
                            4,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'حالة الدفع',
                                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.dInk),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildStatusChip('PLANNED', 'مخطط', AppTheme.dGold),
                                    _buildStatusChip('PAID', 'مدفوع', AppTheme.dMaroon),
                                    _buildStatusChip('CANCELLED', 'ملغي', AppTheme.dMuted),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildAnimated(
                            5,
                            TextFormField(
                              controller: _noteController,
                              textAlign: TextAlign.right,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'ملاحظات (اختياري)',
                                alignLabelWithHint: true,
                                filled: true,
                                fillColor: AppTheme.dCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          _buildAnimated(
                            6,
                            PrimaryActionButton(
                              label: 'حفظ المصروف',
                              isLoading: provider.isSubmitting,
                              onPressed: _submit,
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String value, String label, Color color) {
    final isSelected = _status == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(20) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected ? color : AppTheme.dLine,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                Icon(LucideIcons.checkCircle2, color: color, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? color : AppTheme.dMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimated(int index, Widget child) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, childWidget) {
        final delay = 0.1 + (index * 0.05);
        final value = (_animationController.value - delay).clamp(0.0, 1.0);
        final curve = Curves.easeOutCubic.transform(value);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - curve)),
          child: Opacity(
            opacity: curve,
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  String _getCategoryName(String? id) {
    if (id == null) return 'بدون تصنيف';
    final categories = context.read<FinanceProvider>().budgetCategories;
    try {
      return categories.firstWhere((c) => c.id == id).name;
    } catch (_) {
      return 'بدون تصنيف';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();
    final created = await provider.createExpense(
      weddingPlanId: widget.weddingPlanId,
      title: _titleController.text,
      amount: _amountController.text,
      budgetCategoryId: _budgetCategoryId,
      status: _status,
      expenseDate: _expenseDate,
      note: _noteController.text,
    );
    if (created && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.finance(widget.weddingPlanId));
      }
    }
  }
}
