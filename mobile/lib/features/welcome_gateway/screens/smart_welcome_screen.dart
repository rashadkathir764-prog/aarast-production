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
  String? _setupError;

  final _planNameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDate;
  String _currency = 'YER';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedDraft();
  }

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
      _setupError = null;
    });
  }

  Future<void> _startPlanning() async {
    final planName = _planNameController.text.trim();
    final locationText = _locationController.text.trim();
    final budgetText = _budgetController.text.replaceAll(',', '').trim();

    if (_selectedPersona == null ||
        planName.isEmpty ||
        locationText.isEmpty ||
        _selectedDate == null ||
        budgetText.isEmpty ||
        _currency.trim().isEmpty) {
      setState(() {
        _setupError =
            'أكمل اسم الخطة، المدينة، تاريخ الزفاف، الميزانية، والعملة قبل فتح لوحة التحكم.';
      });
      return;
    }

    setState(() => _isLoading = true);

    final guestStorage = context.read<GuestOnboardingStorage>();
    final now = DateTime.now();

    final draft = GuestOnboardingDraft(
      planName: planName,
      selectedPath: GuestOnboardingPath.weddingUser,
      persona: _selectedPersona,
      governorate: locationText,
      city: locationText,
      district: null,
      neighborhood: null,
      street: null,
      addressNote: null,
      weddingDate: _selectedDate,
      weddingDateUnknown: false,
      priorities: const [],
      currency: _currency,
      estimatedBudget: budgetText,
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

  Future<void> _loadSavedDraft() async {
    final draft = await context.read<GuestOnboardingStorage>().loadDraft();
    if (!mounted || draft == null || draft.isCompleteGuestPlan) return;

    _planNameController.text = draft.planName ?? '';
    _locationController.text =
        draft.weddingLocation.shortLabel ?? draft.locationDisplayLabel.trim();
    _budgetController.text = draft.estimatedBudget ?? '';

    setState(() {
      _selectedPersona = draft.persona;
      _selectedDate = draft.weddingDate;
      _currency = draft.currency ?? 'YER';
      if (draft.selectedPath == GuestOnboardingPath.provider) {
        _currentStep = _WelcomeStep.providerComingSoon;
      } else if (draft.hasPersona) {
        _currentStep = _WelcomeStep.quickSetup;
      } else if (draft.isWeddingUser) {
        _currentStep = _WelcomeStep.roleSelection;
      }
    });
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
                color: AppTheme.ivory, // Royal Burgundy Night
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
                    child: _currentStep == _WelcomeStep.pathSelection
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              children: [
                                Text(
                                  'أهلاً بك في أعرست',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AppTheme.title,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'ابدأ بخطة زفاف هادئة تحفظ تفاصيلك محليًا بدون تسجيل دخول.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.muted,
                                        height: 1.55,
                                      ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
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
              color: AppTheme.ink,
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
              color: AppTheme.ink,
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
                backgroundColor: AppTheme.burgundy,
                disabledBackgroundColor: AppTheme.disabled,
                foregroundColor: Colors.white,
                disabledForegroundColor: AppTheme.muted,
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
            'أكمل بيانات خطتك',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.title,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'هذه البيانات مطلوبة قبل فتح Dashboard حتى تبدأ الخطة بوضوح.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.border, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFieldLabel('اسم الخطة / اسم الزفاف'),
                PremiumTextField(
                  controller: _planNameController,
                  hintText: 'عرسنا، خطة زفاف رشاد...',
                  icon: Icons.edit_rounded,
                  onChanged: (_) => setState(() => _setupError = null),
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('المدينة / الموقع'),
                PremiumLocationCard(
                  controller: _locationController,
                  onChanged: (_) => setState(() => _setupError = null),
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
                            colorScheme: const ColorScheme.light(
                              primary: AppTheme.burgundy,
                              onSurface: AppTheme.ink,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                        _setupError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('الميزانية والعملة'),
                PremiumBudgetField(
                  controller: _budgetController,
                  initialCurrency: _currency,
                  onCurrencyChanged: (val) => setState(() {
                    _currency = val;
                    _setupError = null;
                  }),
                  onChanged: (_) => setState(() => _setupError = null),
                ),
                if (_setupError != null) ...[
                  const SizedBox(height: 16),
                  _SetupErrorBanner(message: _setupError!),
                ],
                const SizedBox(height: 28),

                SizedBox(
                  height: 60,
                  child: FilledButton(
                    onPressed: _isLoading || _selectedPersona == null
                        ? null
                        : _startPlanning,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.burgundy,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: AppTheme.burgundy.withValues(alpha: 0.4),
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
                              color: AppTheme.ink,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'حفظ ومتابعة',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0,
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
          color: AppTheme.ink,
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
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: AppTheme.ink,
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
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.border, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 72,
              color: AppTheme.gold,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'مسار مزودي الخدمة',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'قريبًا ستتمكن من عرض خدماتك واستقبال طلبات العملاء من داخل أعرست.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.muted,
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
                backgroundColor: AppTheme.surface,
                foregroundColor: AppTheme.burgundy,
                side: const BorderSide(color: AppTheme.border, width: 1.5),
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
                foregroundColor: AppTheme.burgundy,
                backgroundColor: AppTheme.goldSoft,
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

class _SetupErrorBanner extends StatelessWidget {
  const _SetupErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.dangerSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.danger,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.danger,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
