import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthController, AuthStatus;
import '../../onboarding/onboarding_api.dart'
    show
        GuestOnboardingDraft,
        GuestOnboardingPath,
        GuestOnboardingStorage,
        GuestPersona,
        WeddingLocationDraft;
import '../../wedding_plans/wedding_plans_api.dart'
    show
        OnboardingCompleteRequest,
        WeddingPlanCreationFields,
        WeddingPlanCreationScope,
        WeddingPlansProvider;

import '../widgets/aarast_path_card.dart';

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

  final _quickSetupFormKey = GlobalKey<FormState>();
  final _planNameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _governorateController = TextEditingController();
  final _cityOrDistrictController = TextEditingController();
  final _areaOrNeighborhoodController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _streetController = TextEditingController();
  final _detailedAddressController = TextEditingController();
  DateTime? _selectedDate;
  String _currency = 'YER';
  bool _showOptionalAddress = false;
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
    _governorateController.dispose();
    _cityOrDistrictController.dispose();
    _areaOrNeighborhoodController.dispose();
    _neighborhoodController.dispose();
    _streetController.dispose();
    _detailedAddressController.dispose();
    super.dispose();
  }

  void _goTo(_WelcomeStep step) {
    setState(() {
      _currentStep = step;
      _setupError = null;
    });
  }

  Future<void> _startPlanning() async {
    if (!(_quickSetupFormKey.currentState?.validate() ?? false)) return;
    final planName = _planNameController.text.trim();
    final location = _locationDraft;
    final budgetText = _budgetController.text.replaceAll(',', '').trim();

    final missingMessage = switch ((
      _selectedPersona,
      planName.isEmpty,
      location.governorate?.trim().isEmpty ?? true,
      location.cityOrDistrict?.trim().isEmpty ?? true,
      _selectedDate,
      _currency.trim().isEmpty,
    )) {
      (null, _, _, _, _, _) => 'اختر دورك في الخطة قبل المتابعة.',
      (_, true, _, _, _, _) => 'أدخل اسمًا واضحًا للخطة.',
      (_, _, true, _, _, _) => 'اختر المحافظة قبل إنشاء الخطة.',
      (_, _, _, true, _, _) => 'اختر المديرية قبل إنشاء الخطة.',
      (_, _, _, _, null, _) => 'اختر تاريخ الزفاف قبل إنشاء الخطة.',
      (_, _, _, _, _, true) => 'اختر عملة الميزانية.',
      _ => null,
    };
    if (missingMessage != null) {
      setState(() => _setupError = missingMessage);
      return;
    }

    setState(() => _isLoading = true);

    // Authenticated users get a real backend plan immediately — a local
    // draft would strand them in a welcome/home redirect loop.
    if (_isAuthenticated()) {
      await _createAccountPlan(
        planName: planName,
        location: location,
        budgetText: budgetText,
      );
      return;
    }

    final guestStorage = context.read<GuestOnboardingStorage>();
    final now = DateTime.now();

    final draft = GuestOnboardingDraft.quickLocalPlanSetup(
      planName: planName,
      persona: _selectedPersona!,
      location: location,
      area: _areaOrNeighborhoodController.text.trim(),
      neighborhood: _neighborhoodController.text.trim(),
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
    required WeddingLocationDraft location,
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
        city: location.cityOrDistrict,
        location: location.toJson(),
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

    final location = draft.weddingLocation;
    _planNameController.text = draft.planName ?? '';
    _governorateController.text = location.governorate ?? '';
    _cityOrDistrictController.text = location.cityOrDistrict ?? '';
    _areaOrNeighborhoodController.text = draft.district ?? '';
    _neighborhoodController.text = draft.neighborhood ?? '';
    _streetController.text = location.street ?? '';
    _detailedAddressController.text = location.detailedAddress ?? '';
    _budgetController.text = draft.estimatedBudget ?? '';

    setState(() {
      _selectedPersona = draft.persona;
      _selectedDate = draft.weddingDate;
      _currency = draft.currency ?? 'YER';
      _showOptionalAddress =
          _streetController.text.isNotEmpty ||
          _detailedAddressController.text.isNotEmpty;
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

  WeddingLocationDraft get _locationDraft {
    return WeddingLocationDraft.fromLegacyFields(
      governorate: _governorateController.text.trim(),
      city: _cityOrDistrictController.text.trim(),
      district: _areaOrNeighborhoodController.text.trim(),
      neighborhood: _neighborhoodController.text.trim(),
      street: _streetController.text.trim(),
      addressNote: _detailedAddressController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == _WelcomeStep.quickSetup) {
      return _buildQuickSetupPage(context);
    }
    return AarastScreenFrame(
      maxWidth: 600,
      safeAreaBottom: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppTheme.canvas),
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
        return const SizedBox.shrink();
    }
  }

  Widget _buildPathSelection(BuildContext context) {
    return Padding(
      key: const ValueKey('pathSelection'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AarastPathCard(
            title: 'إنشاء خطتك',
            subtitle: 'ابدأ خطة جديدة ثم خصصها حسب دورك.',
            icon: LucideIcons.clipboardList,
            tone: AarastPathTone.hero,
            onTap: () => _goTo(_WelcomeStep.roleSelection),
          ),
          const SizedBox(height: 14),
          AarastPathCard(
            title: 'وصلتني دعوة لخطة',
            subtitle: 'الدخول إلى خطة تمت دعوتك إليها برقم هاتفك.',
            icon: LucideIcons.mailCheck,
            tone: AarastPathTone.accent,
            onTap: () => context.go(AppRouter.inviteAccess),
          ),
          const SizedBox(height: 14),
          AarastPathCard(
            title: 'أنا مزود خدمة',
            subtitle: 'إدارة حساب المورد أو طلب الانضمام.',
            icon: LucideIcons.store,
            tone: AarastPathTone.quiet,
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
          AarastPathCard(
            title: 'العريس',
            subtitle: 'أتابع الخطة والميزانية',
            icon: LucideIcons.user,
            tone: AarastPathTone.hero,
            selected: _selectedPersona == GuestPersona.groom,
            onTap: () {
              setState(() => _selectedPersona = GuestPersona.groom);
            },
          ),
          const SizedBox(height: 14),
          AarastPathCard(
            title: 'العروسة',
            subtitle: 'أرتب التفاصيل والاختيارات',
            icon: LucideIcons.flower2,
            tone: AarastPathTone.accent,
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

  Widget _buildQuickSetupPage(BuildContext context) {
    return AarastPageScaffold(
      key: const ValueKey('quickSetup'),
      title: 'إنشاء خطة زفاف',
      subtitle: 'التفاصيل الأساسية فقط — كل شيء قابل للتعديل لاحقًا.',
      showBack: true,
      onBack: () => _goTo(_WelcomeStep.roleSelection),
      maxWidth: 480,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: AarastV3FormActionBar(
        label: 'إنشاء الخطة',
        icon: LucideIcons.chevronLeft,
        loading: _isLoading,
        onPressed: _isLoading || _selectedPersona == null
            ? null
            : _startPlanning,
      ),
      child: WeddingPlanCreationScope(
        formKey: _quickSetupFormKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            WeddingPlanCreationFields(
              titleController: _planNameController,
              governorateController: _governorateController,
              cityOrDistrictController: _cityOrDistrictController,
              areaOrNeighborhoodController: _areaOrNeighborhoodController,
              neighborhoodController: _neighborhoodController,
              streetController: _streetController,
              detailedAddressController: _detailedAddressController,
              budgetController: _budgetController,
              currency: _currency,
              weddingDate: _selectedDate,
              showOptionalAddress: _showOptionalAddress,
              onSelectDate: _showWelcomeDatePicker,
              onCurrencyChanged: (value) {
                setState(() {
                  _currency = value;
                  _setupError = null;
                });
              },
              onToggleOptionalAddress: () {
                setState(() {
                  _showOptionalAddress = !_showOptionalAddress;
                  _setupError = null;
                });
              },
              onChanged: () {
                if (_setupError != null) {
                  setState(() => _setupError = null);
                } else {
                  setState(() {});
                }
              },
              errorMessage: _setupError,
            ),
            const SizedBox(height: 8),
            Text(
              'يمكنك تعديل الخطة في أي وقت.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _showWelcomeDatePicker() async {
    releaseFieldFocus();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(data: AppTheme.light(), child: child!),
        );
      },
    );
    if (date == null || !mounted) return;
    setState(() {
      _selectedDate = date;
      _setupError = null;
    });
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
                  color: AppTheme.brand,
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
            color: AppTheme.textPrimary,
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
            color: AppTheme.textSecondary,
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
      icon: const Icon(LucideIcons.arrowRight, color: AppTheme.textPrimary),
    );
  }
}

/// نقطتا تقدّم: المرحلة النشطة شريط ممتد، والأخرى نقطة هادئة.
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
              color: i == activeIndex
                  ? AppTheme.brand
                  : AppTheme.focus.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.brand,
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
