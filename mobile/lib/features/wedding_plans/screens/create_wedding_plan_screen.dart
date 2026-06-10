import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/wedding_plans_provider.dart';

class CreateWeddingPlanScreen extends StatefulWidget {
  const CreateWeddingPlanScreen({super.key});

  @override
  State<CreateWeddingPlanScreen> createState() =>
      _CreateWeddingPlanScreenState();
}

class _CreateWeddingPlanScreenState extends State<CreateWeddingPlanScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _budgetController = TextEditingController();
  final _currencyController = TextEditingController(text: 'YER');

  String? _selectedCity;
  DateTime? _weddingDate;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _budgetController.dispose();
    _currencyController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showCityPicker() {
    FocusScope.of(context).unfocus();
    final cities = [
      'صنعاء',
      'عدن',
      'تعز',
      'الحديدة',
      'إب',
      'المكلا',
      'ذمار',
      'غير ذلك'
    ];

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
              boxShadow: [
                BoxShadow(
                  color: AppTheme.dMaroonDeep.withAlpha(30),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                )
              ],
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
                              color: AppTheme.dPinkBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(LucideIcons.mapPin, color: AppTheme.dMaroon),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'اختر مدينة الزفاف',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.dMaroonDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: cities.length,
                        itemBuilder: (context, index) {
                          final city = cities[index];
                          final isSelected = city == _selectedCity;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedCity = city);
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
                                      Text(
                                        city,
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

  void _showCalendarPicker() {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    DateTime tempDate = _weddingDate ?? now;

    showModalBottomSheet<void>(
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
              boxShadow: [
                BoxShadow(
                  color: AppTheme.dMaroonDeep.withAlpha(30),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                )
              ],
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
                            'تاريخ الزفاف',
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
                            setState(() => _weddingDate = tempDate);
                            Navigator.pop(sheetContext);
                          },
                          child: const Text(
                            'تأكيد التاريخ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeddingPlansProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: SafeArea(
        child: Stack(
          children: [
            // Luxury Background Elements
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.dPinkBg.withAlpha(150),
                ),
              ),
            ),
            Positioned(
              top: 200,
              left: -80,
              child: Container(
                width: 200,
                height: 200,
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
                        'إنشاء خطة زفاف',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppTheme.dMaroonDeep,
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
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              final curve = Curves.easeOutCubic.transform(_animationController.value);
                              return Transform.translate(
                                offset: Offset(0, 30 * (1 - curve)),
                                child: Opacity(
                                  opacity: curve,
                                  child: child,
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.heroGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.dMaroonDeep.withAlpha(40),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      )
                                    ],
                                  ),
                                  child: const Icon(LucideIcons.gem, color: AppTheme.dGold2, size: 36),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'أجمل أيام حياتك يبدأ من هنا',
                                  textAlign: TextAlign.center,
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: AppTheme.dMaroonDeep,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'دعنا نجهز لك خطة زفافك خطوة بخطوة بكل سهولة وأناقة',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.dInkSoft,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                          
                          _buildAnimatedField(
                            0,
                            TextFormField(
                              controller: _titleController,
                              textAlign: TextAlign.right,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                labelText: 'عنوان الخطة',
                                hintText: 'مثال: زفاف الأحلام',
                                prefixIcon: const Icon(LucideIcons.textCursorInput),
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
                                if (value == null || value.trim().isEmpty) {
                                  return 'عنوان الخطة مطلوب';
                                }
                                return null;
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          _buildAnimatedField(
                            1,
                            GestureDetector(
                              onTap: _showCityPicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.dCard,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  border: Border.all(
                                    color: _selectedCity != null ? AppTheme.dMaroon : AppTheme.dLine,
                                    width: _selectedCity != null ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.mapPin, color: _selectedCity != null ? AppTheme.dMaroon : AppTheme.dMuted),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _selectedCity ?? 'المدينة (اختياري)',
                                        style: TextStyle(
                                          fontWeight: _selectedCity != null ? FontWeight.w800 : FontWeight.w600,
                                          color: _selectedCity != null ? AppTheme.dInk : AppTheme.dMuted,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const Icon(LucideIcons.chevronDown, color: AppTheme.dMuted, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          _buildAnimatedField(
                            2,
                            GestureDetector(
                              onTap: _showCalendarPicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.dCard,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  border: Border.all(
                                    color: _weddingDate != null ? AppTheme.dMaroon : AppTheme.dLine,
                                    width: _weddingDate != null ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.calendarDays, color: _weddingDate != null ? AppTheme.dMaroon : AppTheme.dMuted),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (_weddingDate != null)
                                            Text(
                                              'تاريخ الزفاف',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.dInkSoft,
                                              ),
                                            ),
                                          Text(
                                            _weddingDate == null ? 'تاريخ الزفاف (اختياري)' : '${_weddingDate!.year}/${_weddingDate!.month}/${_weddingDate!.day}',
                                            style: TextStyle(
                                              fontWeight: _weddingDate != null ? FontWeight.w800 : FontWeight.w600,
                                              color: _weddingDate != null ? AppTheme.dInk : AppTheme.dMuted,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(LucideIcons.calendarPlus, color: AppTheme.dMuted, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          _buildAnimatedField(
                            3,
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _budgetController,
                                    textAlign: TextAlign.right,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                    decoration: InputDecoration(
                                      labelText: 'الميزانية (اختياري)',
                                      hintText: '2,500,000',
                                      prefixIcon: const Icon(LucideIcons.wallet),
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
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: _currencyController,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.dMaroonDeep),
                                    decoration: InputDecoration(
                                      labelText: 'العملة',
                                      filled: true,
                                      fillColor: AppTheme.dPinkBg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          if (provider.errorMessage != null) ...[
                            const SizedBox(height: 20),
                            _buildAnimatedField(
                              4,
                              Container(
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
                          
                          const SizedBox(height: 40),
                          
                          _buildAnimatedField(
                            4,
                            PrimaryActionButton(
                              label: 'بدء التخطيط',
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

  Widget _buildAnimatedField(int index, Widget child) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, childWidget) {
        final delay = 0.2 + (index * 0.1);
        final value = (_animationController.value - delay).clamp(0.0, 1.0);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<WeddingPlansProvider>();

    final plan = await provider.createWeddingPlan(
      title: _titleController.text.trim(),
      city: _selectedCity,
      weddingDate: _weddingDate,
      estimatedBudget: _budgetController.text.trim(),
      currency: _currencyController.text.trim().isEmpty
          ? 'YER'
          : _currencyController.text.trim(),
    );

    if (plan != null && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.home);
      }
    }
  }
}