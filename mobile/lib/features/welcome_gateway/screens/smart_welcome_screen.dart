import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/providers/account_context_controller.dart';
import '../../auth/providers/auth_controller.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/guest_onboarding_draft.dart';
import '../../wedding_plans/models/onboarding_complete.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';

import '../widgets/premium_path_card.dart';
import '../widgets/premium_setup_fields.dart';

enum _WelcomeStep { pathSelection, roleSelection, quickSetup }

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
        _currency.trim().isEmpty) {
      setState(() {
        _setupError =
            'أكمل اسم الخطة، المدينة، وتاريخ الزفاف قبل فتح لوحة التحكم. يمكنك تحديد الميزانية لاحقاً.';
      });
      return;
    }

    setState(() => _isLoading = true);

    // Authenticated users get a real backend plan immediately — a local
    // draft would strand them in a welcome/home redirect loop.
    if (_isAuthenticated()) {
      await _createAccountPlan(
        planName: planName,
        locationText: locationText,
        budgetText: budgetText,
      );
      return;
    }

    final guestStorage = context.read<GuestOnboardingStorage>();
    final now = DateTime.now();

    final draft = GuestOnboardingDraft.quickLocalPlanSetup(
      planName: planName,
      persona: _selectedPersona!,
      location: locationText,
      weddingDate: _selectedDate!,
      currency: _currency,
      estimatedBudget: budgetText,
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

  bool _isAuthenticated() {
    try {
      return context.read<AuthController>().status == AuthStatus.authenticated;
    } on ProviderNotFoundException {
      return false;
    }
  }

  Future<void> _createAccountPlan({
    required String planName,
    required String locationText,
    required String budgetText,
  }) async {
    final WeddingPlansProvider plans;
    AuthStorage? authStorage;
    final guestStorage = context.read<GuestOnboardingStorage>();
    try {
      plans = context.read<WeddingPlansProvider>();
    } on ProviderNotFoundException {
      setState(() {
        _isLoading = false;
        _setupError = 'تعذر إنشاء الخطة الآن. حاول مرة أخرى.';
      });
      return;
    }
    try {
      authStorage = context.read<AuthStorage>();
    } on ProviderNotFoundException {
      authStorage = null;
    }

    final response = await plans.completeOnboarding(
      OnboardingCompleteRequest(
        path: 'USER',
        persona: switch (_selectedPersona) {
          GuestPersona.bride => 'BRIDE',
          GuestPersona.helper => 'HELPER',
          _ => 'GROOM',
        },
        title: planName,
        city: locationText,
        weddingDate: _selectedDate?.toIso8601String(),
        estimatedBudget: budgetText.isEmpty ? null : budgetText,
        currency: _currency,
      ),
    );

    if (!mounted) return;
    if (response == null) {
      setState(() {
        _isLoading = false;
        _setupError =
            plans.errorMessage ??
            'تعذر إنشاء الخطة الآن. تحقق من الاتصال وحاول مرة أخرى.';
      });
      return;
    }

    await authStorage?.saveActivePlanId(response.activePlanId);
    await guestStorage.clearDraft();
    if (!mounted) return;
    try {
      await context.read<AccountContextController>().refresh(
        allowInitialSingleContext: true,
      );
    } on ProviderNotFoundException {
      // Lightweight widget previews do not install the authenticated
      // account-context boundary.
    }
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
        context.go(AppRouter.providerApply);
        return;
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: _WelcomeHero(
                      step: _currentStep,
                      onBack: switch (_currentStep) {
                        _WelcomeStep.pathSelection => null,
                        _WelcomeStep.roleSelection => () => _goTo(
                          _WelcomeStep.pathSelection,
                        ),
                        _WelcomeStep.quickSetup => () => _goTo(
                          _WelcomeStep.roleSelection,
                        ),
                      },
                    ),
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
    }
  }

  Widget _buildPathSelection(BuildContext context) {
    return Padding(
      key: const ValueKey('pathSelection'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumPathCard(
            title: 'إنشاء خطتك',
            subtitle: 'ابدأ خطة جديدة ثم خصصها حسب دورك.',
            icon: LucideIcons.clipboardList,
            tone: PremiumPathTone.hero,
            onTap: () => _goTo(_WelcomeStep.roleSelection),
          ),
          const SizedBox(height: 14),
          PremiumPathCard(
            title: 'وصلتني دعوة لخطة',
            subtitle: 'الدخول إلى خطة تمت دعوتك إليها برقم هاتفك.',
            icon: LucideIcons.mailCheck,
            tone: PremiumPathTone.gold,
            onTap: () => context.go(AppRouter.inviteAccess),
          ),
          const SizedBox(height: 14),
          PremiumPathCard(
            title: 'أنا مزود خدمة',
            subtitle: 'إدارة حساب المورد أو طلب الانضمام.',
            icon: LucideIcons.store,
            tone: PremiumPathTone.quiet,
            onTap: () => context.go(AppRouter.providerApply),
          ),
          const SizedBox(height: 18),
          _LoginPrompt(onTap: () => context.go(AppRouter.login)),
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
          PremiumPathCard(
            title: 'العريس',
            subtitle: 'أتابع الخطة والميزانية',
            icon: LucideIcons.user,
            tone: PremiumPathTone.hero,
            selected: _selectedPersona == GuestPersona.groom,
            onTap: () {
              setState(() => _selectedPersona = GuestPersona.groom);
            },
          ),
          const SizedBox(height: 14),
          PremiumPathCard(
            title: 'العروسة',
            subtitle: 'أرتب التفاصيل والاختيارات',
            icon: LucideIcons.flower2,
            tone: PremiumPathTone.gold,
            selected: _selectedPersona == GuestPersona.bride,
            onTap: () {
              setState(() => _selectedPersona = GuestPersona.bride);
            },
          ),
          const SizedBox(height: 18),
          AarastButton(
            label: 'التالي',
            icon: LucideIcons.arrowLeft,
            onPressed: _selectedPersona == null
                ? null
                : () => _goTo(_WelcomeStep.quickSetup),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFieldLabel('اسم الخطة / اسم الزفاف'),
                PremiumTextField(
                  controller: _planNameController,
                  hintText: 'عرسنا، خطة زفاف رشاد...',
                  icon: LucideIcons.pencil,
                  onChanged: (_) => setState(() => _setupError = null),
                ),
                const SizedBox(height: 12),

                _buildFieldLabel('المدينة / الموقع'),
                PremiumLocationCard(
                  controller: _locationController,
                  onChanged: (_) => setState(() => _setupError = null),
                ),
                const SizedBox(height: 12),

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
                const SizedBox(height: 12),

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
                const SizedBox(height: 20),

                AarastButton(
                  label: 'حفظ ومتابعة',
                  icon: LucideIcons.arrowLeft,
                  isLoading: _isLoading,
                  onPressed: _isLoading || _selectedPersona == null
                      ? null
                      : _startPlanning,
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
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: AppTheme.ink),
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.step, this.onBack});

  final _WelcomeStep step;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final content = _WelcomeHeroContent.forStep(step);

    return Column(
      children: [
        // زر الرجوع يجاور السطر التمهيدي في صفّ واحد بدل أن يطفو فوق
        // المحتوى: يبقى العنوان متمركزًا ولا يتداخل مع الزر مهما كبر الخط.
        Row(
          children: [
            SizedBox(
              width: 40,
              child: onBack == null ? null : _WelcomeBackButton(onTap: onBack!),
            ),
            Expanded(
              child: Text(
                content.eyebrow,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.burgundy,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          content.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppTheme.title,
            fontWeight: FontWeight.w900,
            fontFamily: AppTheme.displayFontFamily,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content.message,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.muted,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        // مؤشّر خطوات للمسار الخطّي فقط (الدور ← البيانات) — نقطتان.
        // اختيار المسار تفرّع وليس خطوة، فلا نعرضه فيه.
        if (step != _WelcomeStep.pathSelection) ...[
          const SizedBox(height: 16),
          _WelcomeStepDots(
            activeIndex: step == _WelcomeStep.roleSelection ? 0 : 1,
          ),
        ],
      ],
    );
  }
}

class _WelcomeBackButton extends StatelessWidget {
  const _WelcomeBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'رجوع',
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      icon: const Icon(LucideIcons.arrowRight, color: AppTheme.ink),
    );
  }
}

/// نقطتا تقدّم أنيقتان: المرحلة النشطة شريط ذهبي ممدود، والأخرى نقطة هادئة.
class _WelcomeStepDots extends StatelessWidget {
  const _WelcomeStepDots({required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 2; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: 6,
            width: i == activeIndex ? 26 : 6,
            decoration: BoxDecoration(
              gradient: i == activeIndex
                  ? const LinearGradient(
                      colors: [AppTheme.goldDeep, AppTheme.gold],
                    )
                  : null,
              color: i == activeIndex
                  ? null
                  : AppTheme.gold.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (i == 0) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// نص الترويسة هو المصدر الوحيد لعناوين الخطوة: سطر تمهيدي + عنوان + سطر
/// إرشادي واحد. الخطوات لا تكرّر أيًّا منها في جسمها.
class _WelcomeHeroContent {
  const _WelcomeHeroContent({
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  factory _WelcomeHeroContent.forStep(_WelcomeStep step) {
    return switch (step) {
      _WelcomeStep.pathSelection => const _WelcomeHeroContent(
        eyebrow: 'مرحبًا بك',
        title: 'أعرست',
        message: 'اختر المسار المناسب لك',
      ),
      _WelcomeStep.roleSelection => const _WelcomeHeroContent(
        eyebrow: 'تخصيص التجربة',
        title: 'دورك يحدد التفاصيل',
        message: 'اختيار بسيط يساعدنا نرتب التجربة لك بوضوح.',
      ),
      _WelcomeStep.quickSetup => const _WelcomeHeroContent(
        eyebrow: 'بيانات أساسية',
        title: 'افتح لوحة واضحة',
        message:
            'هذه البيانات مطلوبة قبل فتح لوحة التحكم حتى لا تبدأ الخطة ناقصة أو مربكة.',
      ),
    };
  }

  final String eyebrow;
  final String title;
  final String message;
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
          const Icon(LucideIcons.info, color: AppTheme.danger, size: 20),
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

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'لديك حساب؟',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.burgundy,
            textStyle: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          child: const Text('تسجيل الدخول'),
        ),
      ],
    );
  }
}
