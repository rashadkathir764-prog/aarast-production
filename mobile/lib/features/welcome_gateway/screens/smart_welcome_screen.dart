import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/hijri_date.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthController, AuthStatus;
import '../../catalogs/catalogs_api.dart' show ReferenceCatalogProvider;
import '../../finance/finance_api.dart'
    show
        FinanceApi,
        MoneyInputFormatter,
        formatMoneyInputValue,
        moneyStarterPlanItemNames;
import '../../marketplace/marketplace_api.dart' show MarketplaceApi;
import '../../onboarding/onboarding_api.dart'
    show
        GuestOnboardingDraft,
        GuestOnboardingPath,
        GuestOnboardingStorage,
        GuestPersona,
        WeddingLocationDraft;
import '../../tasks/tasks_api.dart' show taskStarterCountFor;
import '../../wedding_plans/wedding_plans_api.dart'
    show OnboardingCompleteRequest, WeddingPlansProvider;

part 'smart_welcome_screen.start.dart';
part 'smart_welcome_screen.plan.dart';
part 'smart_welcome_screen.day.dart';

/// The start of the journey (prototype a02 to a08): what you want to do,
/// whose wedding, your name and the date, the city and a rough budget, and
/// «خطتك جاهزة». The plan is kept on the phone first; the account is asked
/// for only when it is saved.
enum _WelcomeStep { start, whose, nameDate, placeBudget, ready }

/// The questions after «خطة مين؟». The mahr question joins when the
/// agreement section exists on the server.
const _questionCount = 2;

/// The cities seeded in the provider directory, used until the live list
/// arrives (or when offline with nothing cached).
const _fallbackCities = ['صنعاء', 'عدن', 'تعز', 'إب', 'الحديدة', 'المكلا'];

class SmartWelcomeScreen extends StatefulWidget {
  const SmartWelcomeScreen({super.key});

  @override
  State<SmartWelcomeScreen> createState() => _SmartWelcomeScreenState();
}

class _SmartWelcomeScreenState extends State<SmartWelcomeScreen> {
  _WelcomeStep _step = _WelcomeStep.start;
  bool _wantsProvider = false;
  GuestPersona _persona = GuestPersona.groom;

  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  DateTime? _date;
  bool _dateUnknown = false;
  String? _city;
  bool _budgetSkipped = false;
  List<String> _cities = _fallbackCities;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCities());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();

  int? get _budget {
    final digits = _budgetController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final value = int.tryParse(digits);
    return value == null || value <= 0 ? null : value;
  }

  String get _personaCode => _persona == GuestPersona.bride ? 'BRIDE' : 'GROOM';

  String get _planTitle => 'عرس $_name';

  void _goTo(_WelcomeStep step) {
    setState(() {
      _step = step;
      _error = null;
    });
  }

  void _back() {
    switch (_step) {
      case _WelcomeStep.start:
        return;
      case _WelcomeStep.whose:
        _goTo(_WelcomeStep.start);
      case _WelcomeStep.nameDate:
        _goTo(_WelcomeStep.whose);
      case _WelcomeStep.placeBudget:
        _goTo(_WelcomeStep.nameDate);
      case _WelcomeStep.ready:
        _goTo(_WelcomeStep.placeBudget);
    }
  }

  void _start() {
    if (_wantsProvider) {
      context.go(AppRouter.providerApply);
      return;
    }
    _goTo(_WelcomeStep.whose);
  }

  T? _maybeRead<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _loadCities() async {
    final api = _maybeRead<MarketplaceApi>();
    if (api == null) return;
    try {
      final cities = await api.getCities();
      final names = [
        for (final city in cities)
          if (city.nameAr.trim().isNotEmpty) city.nameAr.trim(),
      ];
      if (!mounted || names.isEmpty) return;
      setState(() => _cities = names);
    } on Object {
      // Offline with nothing cached: the seeded cities stay.
    }
  }

  Future<void> _loadSavedDraft() async {
    final draft = await context.read<GuestOnboardingStorage>().loadDraft();
    if (!mounted || draft == null || draft.isCompleteGuestPlan) return;
    if (draft.selectedPath == GuestOnboardingPath.provider) {
      context.go(AppRouter.providerApply);
      return;
    }
    final name = draft.planName?.trim() ?? '';
    _nameController.text = name.startsWith('عرس ') ? name.substring(4) : name;
    _budgetController.text = formatMoneyInputValue(draft.estimatedBudget);
    setState(() {
      _persona = draft.persona == GuestPersona.bride
          ? GuestPersona.bride
          : GuestPersona.groom;
      _date = draft.weddingDate;
      _dateUnknown = draft.weddingDateUnknown;
      _city = draft.city;
      _budgetSkipped = draft.budgetSkipped;
      if (draft.hasPersona) _step = _WelcomeStep.nameDate;
    });
  }

  ReferenceCatalogData _catalogs() {
    final catalogs = _maybeRead<ReferenceCatalogProvider>();
    final items = moneyStarterPlanItemNames(
      catalogs?.catalogFor('money.starter.categories'),
      _personaCode,
    );
    final tasks = taskStarterCountFor(
      catalogs?.catalogFor('tasks.starter'),
      _personaCode,
    );
    return (items: items, taskCount: tasks);
  }

  WeddingLocationDraft get _location =>
      WeddingLocationDraft.fromLegacyFields(governorate: _city, city: _city);

  GuestOnboardingDraft _draft() {
    return GuestOnboardingDraft.quickLocalPlanSetup(
      planName: _planTitle,
      persona: _persona,
      location: _location,
      weddingDate: _dateUnknown ? null : _date,
      currency: 'YER',
      estimatedBudget: _budgetSkipped ? null : _budget?.toString(),
      startingItemNames: _catalogs().items,
    );
  }

  bool _isAuthenticated() {
    final auth = _maybeRead<AuthController>();
    return auth?.status == AuthStatus.authenticated;
  }

  /// Keeps the plan on the phone, then opens [route]. The items a05
  /// promised («11 بند لعرسك») go into its money at once, as an account
  /// plan gets them from the server.
  Future<void> _keepOnPhone(String route) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final planId = 'local-guest-${now.microsecondsSinceEpoch}';
    final draft = _draft().copyWith(
      guestPlanId: planId,
      createdAt: now,
      isGuestPlan: true,
      needsSync: true,
    );
    try {
      await _maybeRead<FinanceApi>()?.replaceMoneyBudget(
        planId: planId,
        totalBudget: draft.estimatedBudget,
        currency: 'YER',
        categories: [
          for (final name in draft.selectedCategoryKeys)
            (id: null, name: name, allocatedAmount: null),
        ],
      );
      if (!mounted) return;
      await context.read<GuestOnboardingStorage>().saveDraft(draft);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'ما قدرنا نحفظ الخطة على جوالك. حاول مرة ثانية.';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    context.go(route);
  }

  /// A signed-in person creating another plan gets it on the server at once.
  Future<void> _createAccountPlan() async {
    final plans = _maybeRead<WeddingPlansProvider>();
    if (plans == null) {
      setState(() => _error = 'ما قدرنا ننشئ الخطة الآن. حاول مرة ثانية.');
      return;
    }
    final authStorage = _maybeRead<AuthStorage>();
    final guestStorage = context.read<GuestOnboardingStorage>();
    setState(() {
      _saving = true;
      _error = null;
    });
    final response = await plans.completeOnboarding(
      OnboardingCompleteRequest(
        path: 'USER',
        persona: _personaCode,
        title: _planTitle,
        city: _city,
        location: _location.toJson(),
        weddingDate: _dateUnknown ? null : _date?.toIso8601String(),
        estimatedBudget: _budgetSkipped ? null : _budget?.toString(),
        currency: 'YER',
        selectedCategories: _catalogs().items,
      ),
    );
    if (!mounted) return;
    if (response == null) {
      setState(() {
        _saving = false;
        _error =
            plans.errorMessage ??
            'ما قدرنا ننشئ الخطة. تأكد من النت وحاول مرة ثانية.';
      });
      return;
    }
    await authStorage?.saveActivePlanId(response.activePlanId);
    await guestStorage.clearDraft();
    if (!mounted) return;
    await _maybeRead<AccountContextController>()?.refresh(
      allowInitialSingleContext: true,
    );
    if (!mounted) return;
    context.go(AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_step) {
      _WelcomeStep.start => _StartStep(
        wantsProvider: _wantsProvider,
        onChoose: (provider) => setState(() => _wantsProvider = provider),
        onStart: _start,
        onLogin: () => context.go(AppRouter.login),
        onInvite: () => context.go(AppRouter.inviteAccess),
      ),
      _WelcomeStep.whose => _WhoseStep(
        persona: _persona,
        onChoose: (persona) => setState(() => _persona = persona),
        onNext: () => _goTo(_WelcomeStep.nameDate),
        onBack: _back,
      ),
      _WelcomeStep.nameDate => _NameDateStep(
        controller: _nameController,
        date: _date,
        dateUnknown: _dateUnknown,
        onNameChanged: () => setState(() {}),
        onPickMonth: _pickDayInMonth,
        onDateUnknown: () => setState(() {
          _dateUnknown = !_dateUnknown;
          if (_dateUnknown) _date = null;
        }),
        onNext: _name.isEmpty || (_date == null && !_dateUnknown)
            ? null
            : () => _goTo(_WelcomeStep.placeBudget),
        onBack: _back,
      ),
      _WelcomeStep.placeBudget => _PlaceBudgetStep(
        cities: _cities,
        city: _city,
        budgetController: _budgetController,
        budgetSkipped: _budgetSkipped,
        onCity: (city) => setState(() => _city = city),
        onMoreCities: _pickOtherCity,
        onBudgetChanged: () => setState(() => _budgetSkipped = false),
        onSkipBudget: () => setState(() {
          _budgetSkipped = !_budgetSkipped;
          if (_budgetSkipped) _budgetController.clear();
        }),
        onNext: _city == null || (_budget == null && !_budgetSkipped)
            ? null
            : () => _goTo(_WelcomeStep.ready),
        onBack: _back,
      ),
      _WelcomeStep.ready => _ReadyStep(
        name: _name,
        subtitle: _readySubtitle(),
        city: _city ?? '',
        hasDate: !_dateUnknown && _date != null,
        catalogs: _catalogs(),
        signedIn: _isAuthenticated(),
        saving: _saving,
        error: _error,
        onSaveWithPhone: () => _keepOnPhone(AppRouter.register),
        onLookFirst: () => _keepOnPhone(AppRouter.home),
        onOpenPlan: _createAccountPlan,
        onBack: _back,
      ),
    };
    return AarastScreenFrame(
      maxWidth: 600,
      safeAreaBottom: false,
      backgroundColor: AarastV3Color.canvas,
      child: AnimatedSwitcher(
        duration: AarastV3Motion.standard,
        child: KeyedSubtree(key: ValueKey(_step), child: page),
      ),
    );
  }

  String _readySubtitle() {
    final parts = <String>[_planTitle, ?_city];
    if (!_dateUnknown && _date != null) {
      parts.add(formatArabicDayMonth(_date!));
      final hijri = HijriDate.fromGregorian(_date!);
      if (hijri != null) parts.add(hijri.dayAndMonth);
    }
    return parts.join(' · ');
  }

  Future<void> _pickDayInMonth(DateTime month) async {
    releaseFieldFocus();
    final picked = await showJourneySheet<DateTime>(
      context: context,
      builder: (sheetContext) => _DaySheet(
        month: DateTime(month.year, month.month),
        selected: _date,
        today: DateUtils.dateOnly(DateTime.now()),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _dateUnknown = false;
    });
  }

  Future<void> _pickOtherCity() async {
    final picked = await showJourneySheet<String>(
      context: context,
      builder: (sheetContext) => _CitySheet(cities: _cities, selected: _city),
    );
    if (picked == null || !mounted) return;
    setState(() => _city = picked);
  }
}

typedef ReferenceCatalogData = ({List<String> items, int taskCount});
