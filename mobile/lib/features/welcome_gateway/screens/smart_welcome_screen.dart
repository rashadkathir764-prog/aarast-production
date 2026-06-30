import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/guest_onboarding_draft.dart';

import '../widgets/premium_path_card.dart';
import '../widgets/premium_role_card.dart';
import '../widgets/premium_setup_fields.dart';

enum _WelcomeStep {
  pathSelection,
  roleSelection,
  quickSetup,
  providerComingSoon,
}

class SmartWelcomeScreen extends StatefulWidget {
  const SmartWelcomeScreen({super.key});

  @override
  State<SmartWelcomeScreen> createState() => _SmartWelcomeScreenState();
}

class _SmartWelcomeScreenState extends State<SmartWelcomeScreen> {
  _WelcomeStep _currentStep = _WelcomeStep.pathSelection;
  GuestPersona? _selectedPersona;

  final _planNameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDate;
  String _currency = 'YER';
  bool _isLoading = false;

  @override
  void dispose() {
    _planNameController.dispose();
    _budgetController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _goTo(_WelcomeStep step) {
    setState(() {
      _currentStep = step;
    });
  }

  Future<void> _startPlanning() async {
    setState(() => _isLoading = true);

    final guestStorage = context.read<GuestOnboardingStorage>();
    final now = DateTime.now();

    final planName = _planNameController.text.trim();
    final locationText = _locationController.text.trim();
    final budgetText = _budgetController.text.replaceAll(',', '').trim();

    final draft = GuestOnboardingDraft(
      planName: planName.isEmpty ? null : planName,
      selectedPath: GuestOnboardingPath.weddingUser,
      persona: _selectedPersona,
      governorate: locationText.isNotEmpty ? locationText : null,
      city: locationText.isNotEmpty ? locationText : null,
      district: null,
      neighborhood: null,
      street: null,
      addressNote: null,
      weddingDate: _selectedDate,
      weddingDateUnknown: _selectedDate == null,
      priorities: const [],
      currency: budgetText.isEmpty ? null : _currency,
      estimatedBudget: budgetText.isEmpty ? null : budgetText,
      selectedCategoryKeys: const [],
    );

    await guestStorage.saveDraft(
      draft.copyWith(
        guestPlanId: 'local-guest-${now.microsecondsSinceEpoch}',
        createdAt: now,
        isGuestPlan: true,
        needsSync: true,
      ),
    );

    if (!mounted) return;
    context.go(AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 600,
      safeAreaBottom: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFF120306), // Royal Burgundy Night
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.0,
                  colors: [
                    AppTheme.dMaroonDeep.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 0.8,
                  colors: [
                    AppTheme.dGoldDeep.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 32, bottom: 16),
                    child: Center(child: const SizedBox.shrink()),
                  ),
                ),
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutQuart,
                    switchOutCurve: Curves.easeInQuart,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.05),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                    child: _buildCurrentStep(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_currentStep) {
      case _WelcomeStep.pathSelection:
        return _buildPathSelection(context);
      case _WelcomeStep.roleSelection:
        return _buildRoleSelection(context);
      case _WelcomeStep.quickSetup:
        return _buildQuickSetup(context);
      case _WelcomeStep.providerComingSoon:
        return _buildProviderComingSoon(context);
    }
  }

  Widget _buildPathSelection(BuildContext context) {
    return Padding(
      key: const ValueKey('pathSelection'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'كيف تحب تبدأ؟',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 56),
          PremiumPathCard(
            title: 'أريد تنظيم زفافي',
            subtitle: 'ابدأ خطة ذكية للمهام والميزانية والضيوف والموردين',
            icon: Icons.favorite_rounded,
            isPrimary: true,
            onTap: () => _goTo(_WelcomeStep.roleSelection),
          ),
          const SizedBox(height: 16),
          PremiumPathCard(
            title: 'أنا مزود خدمة',
            subtitle: 'اعرض خدماتك واستقبل طلبات العملاء',
            icon: Icons.storefront_rounded,
            onTap: () => _goTo(_WelcomeStep.providerComingSoon),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelection(BuildContext context) {
    return Padding(
      key: const ValueKey('roleSelection'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _buildBackButton(() => _goTo(_WelcomeStep.pathSelection)),
          ),
          const SizedBox(height: 24),
          Text(
            'من أنت؟',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          PremiumRoleCard(
            title: 'العريس',
            subtitle: 'أتابع الخطة والميزانية',
            icon: Icons.person,
            isSelected: _selectedPersona == GuestPersona.groom,
            onTap: () {
              setState(() => _selectedPersona = GuestPersona.groom);
            },
          ),
          const SizedBox(height: 14),
          PremiumRoleCard(
            title: 'العروسة',
            subtitle: 'أرتب التفاصيل والاختيارات',
            icon: Icons.person_3,
            isSelected: _selectedPersona == GuestPersona.bride,
            onTap: () {
              setState(() => _selectedPersona = GuestPersona.bride);
            },
          ),
          const SizedBox(height: 14),
          PremiumRoleCard(
            title: 'مساهم / مشارك في الخطة',
            subtitle: 'أساعد في التنظيم والمتابعة',
            icon: Icons.handshake_rounded,
            isSelected: _selectedPersona == GuestPersona.helper,
            onTap: () {
              setState(() => _selectedPersona = GuestPersona.helper);
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _selectedPersona == null
                  ? null
                  : () => _goTo(_WelcomeStep.quickSetup),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.dGoldDeep,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'متابعة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSetup(BuildContext context) {
    return Padding(
      key: const ValueKey('quickSetup'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _buildBackButton(() => _goTo(_WelcomeStep.roleSelection)),
          ),
          const SizedBox(height: 24),
          Text(
            'خلّينا نجهز أساس خطتك',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFieldLabel('اسم المناسبة / اسم الخطة'),
                PremiumTextField(
                  controller: _planNameController,
                  hintText: 'عرسنا، عرس رشاد...',
                  icon: Icons.edit_rounded,
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('تاريخ الزفاف'),
                PremiumDateField(
                  selectedDate: _selectedDate,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1000)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppTheme.dGoldDeep,
                              onPrimary: Colors.white,
                              surface: AppTheme.dInk,
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('الميزانية والعملة'),
                PremiumBudgetField(
                  controller: _budgetController,
                  initialCurrency: _currency,
                  onCurrencyChanged: (val) => setState(() => _currency = val),
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('الموقع'),
                PremiumLocationCard(controller: _locationController),
                const SizedBox(height: 32),

                SizedBox(
                  height: 60,
                  child: FilledButton(
                    onPressed: _isLoading || _selectedPersona == null
                        ? null
                        : _startPlanning,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.dGoldDeep,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: AppTheme.dMaroon.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'ابدأ التخطيط',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom + 24
                : MediaQuery.of(context).viewPadding.bottom + 40,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, right: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildBackButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildProviderComingSoon(BuildContext context) {
    return Padding(
      key: const ValueKey('providerComingSoon'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _buildBackButton(() => _goTo(_WelcomeStep.pathSelection)),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 72,
              color: AppTheme.dGold,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'مسار مزودي الخدمة',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'قريبًا ستتمكن من عرض خدماتك واستقبال طلبات العملاء من داخل أعرست.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.8,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 64),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: () => _goTo(_WelcomeStep.pathSelection),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppTheme.dGoldDeep,
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppTheme.dGoldDeep, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'العودة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: TextButton(
              onPressed: () =>
                  context.push(AppRouter.login, extra: {'type': 'provider'}),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.warmGold,
                backgroundColor: AppTheme.warmGold.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'تسجيل الدخول',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
