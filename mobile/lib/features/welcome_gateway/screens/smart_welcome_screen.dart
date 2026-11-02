import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/app_clock.dart';
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
        MahrFields,
        MoneyInputFormatter,
        formatMoneyInputValue,
        mahrWords,
        moneyStarterPlanItemNames,
        pickMahrDueDate;
import '../../marketplace/marketplace_api.dart' show MarketplaceApi;
import '../../onboarding/onboarding_api.dart'
    show
        DraftMahr,
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
/// whose wedding, your name and the date, the city and a rough budget, the
/// mahr (a06), and «خطتك جاهزة». The plan is kept on the phone first; the
/// account is asked for only when it is saved.
enum _WelcomeStep { start, whose, nameDate, placeBudget, mahr, ready }

/// The questions after «خطة مين؟»: the name and the day, the city and the
/// budget, the mahr. a06's «في اليمن ولا برا؟» is after V1 (y01).
const _questionCount = 3;

/// The months on the screen from this one; later ones are in a sheet.
const _monthsOnScreen = 6;

/// The cities seeded in the provider directory, used until the live list
/// arrives (or when offline with nothing cached).
const _fallbackCities = ['صنعاء', 'عدن', 'تعز', 'إب', 'الحديدة', 'المكلا'];

class SmartWelcomeScreen extends StatefulWidget {
  const SmartWelcomeScreen({this.newPlan = false, super.key});

  /// w11 «خطة جديدة»: a signed-in person adds another plan. The steps start
  /// at «خطة مين؟» (a02b), since «أهلًا فيك» offers signing in and the
  /// provider path, and a phone plan kept for later is left alone.
  final bool newPlan;

  @override
  State<SmartWelcomeScreen> createState() => _SmartWelcomeScreenState();
}

class _SmartWelcomeScreenState extends State<SmartWelcomeScreen> {
  late _WelcomeStep _step = widget.newPlan
      ? _WelcomeStep.whose
      : _WelcomeStep.start;
  GuestPersona _persona = GuestPersona.groom;

  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  // a06: the mahr, what was handed over or received, the rest's day.
  final _mahrTotalController = TextEditingController();
  final _mahrSettledController = TextEditingController();
  DateTime? _mahrDueDate;
  String? _mahrError;

  /// «أكثر من المهر نفسه» belongs under the settled field, as on c-mahr.
  String? _mahrSettledError;
  DateTime? _date;
  bool _dateUnknown = false;
  String? _city;
  bool _budgetSkipped = false;
  List<String> _cities = _fallbackCities;

  /// The directory's id of each city, to count its providers on «جاهزة».
  Map<String, String> _cityIds = const {};

  /// How many providers the chosen city has; null while unknown (offline,
  /// a city typed by hand, or not asked yet).
  int? _providerCount;
  String? _providerCountCity;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.newPlan) _loadSavedDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCities());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _mahrTotalController.dispose();
    _mahrSettledController.dispose();
    super.dispose();
  }

  /// a06's answer, or null for «ما اتفقنا بعد» (nothing typed).
  DraftMahr? get _mahr {
    final total = MahrFields.amountOf(_mahrTotalController);
    if (total == null || total <= 0) return null;
    final settled = MahrFields.amountOf(_mahrSettledController) ?? 0;
    return DraftMahr(
      total: '$total',
      settled: '$settled',
      remainingDueDate: settled < total ? _mahrDueDate : null,
    );
  }

  /// «التالي» on a06: what is typed must hold together.
  void _confirmMahr() {
    final total = MahrFields.amountOf(_mahrTotalController) ?? 0;
    final settled = MahrFields.amountOf(_mahrSettledController) ?? 0;
    if (total <= 0) {
      setState(
        () => _mahrError = _profile.say('اكتب كم المهر', 'اكتبي كم المهر'),
      );
      return;
    }
    if (settled > total) {
      setState(() => _mahrSettledError = 'أكثر من المهر نفسه');
      return;
    }
    _toReady();
  }

  /// «ما اتفقنا بعد»: a real answer; the home keeps the step to take later.
  void _skipMahr() {
    _mahrTotalController.clear();
    _mahrSettledController.clear();
    _mahrDueDate = null;
    _toReady();
  }

  Future<void> _pickMahrDueDate() async {
    final picked = await pickMahrDueDate(
      context,
      _mahrDueDate,
      accent: _profile.accent,
    );
    if (picked != null && mounted) setState(() => _mahrDueDate = picked);
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
        if (widget.newPlan) {
          context.canPop() ? context.pop() : context.go(AppRouter.home);
        } else {
          _goTo(_WelcomeStep.start);
        }
      case _WelcomeStep.nameDate:
        _goTo(_WelcomeStep.whose);
      case _WelcomeStep.placeBudget:
        _goTo(_WelcomeStep.nameDate);
      case _WelcomeStep.mahr:
        _goTo(_WelcomeStep.placeBudget);
      case _WelcomeStep.ready:
        _goTo(_WelcomeStep.mahr);
    }
  }

  void _choosePersona(GuestPersona persona) {
    setState(() => _persona = persona);
    _goTo(_WelcomeStep.nameDate);
  }

  /// A link tapped before its question has what it needs says what is
  /// missing, rather than doing nothing.
  bool _nameMissing = false;
  bool _cityMissing = false;

  /// «ما حددنا الموعد بعد»: a full answer, the date is set later.
  void _skipDate() {
    if (_name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    setState(() {
      _dateUnknown = true;
      _date = null;
    });
    _goTo(_WelcomeStep.placeBudget);
  }

  /// «أكمل بدون ميزانية»: the plan starts without a total.
  void _skipBudget() {
    if (_city == null) {
      setState(() => _cityMissing = true);
      return;
    }
    _budgetController.clear();
    setState(() => _budgetSkipped = true);
    _goTo(_WelcomeStep.mahr);
  }

  void _toReady() {
    _goTo(_WelcomeStep.ready);
    _countProviders();
  }

  /// The real number of providers in the chosen city, for «جاهزة». Nothing
  /// is said about a number the directory did not give.
  Future<void> _countProviders() async {
    final city = _city;
    final id = city == null ? null : _cityIds[city];
    final api = _maybeRead<MarketplaceApi>();
    if (city == _providerCountCity) return;
    setState(() {
      _providerCount = null;
      _providerCountCity = null;
    });
    if (id == null && _cityIds.isNotEmpty) {
      // The directory answered and this city (typed by hand) is not in it:
      // no providers there yet, which is a real answer, not «offline».
      setState(() {
        _providerCount = 0;
        _providerCountCity = city;
      });
      return;
    }
    if (id == null || api == null) return;
    try {
      final page = await api.getProvidersPage(cityId: id, limit: 1);
      if (!mounted || _city != city) return;
      setState(() {
        _providerCount = page.total;
        _providerCountCity = city;
      });
    } on Object {
      // Offline: the row names the city without a number.
    }
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
      final ids = {
        for (final city in cities)
          if (city.nameAr.trim().isNotEmpty) city.nameAr.trim(): city.id,
      };
      if (!mounted || ids.isEmpty) return;
      setState(() {
        _cities = ids.keys.toList();
        _cityIds = ids;
      });
    } on Object {
      // Offline with nothing cached: the seeded cities stay.
    }
  }

  /// A finished plan already on this phone («عرس محمد»): the door opens it
  /// instead of starting a second one over it (the phone keeps one).
  String? _phonePlanTitle;

  /// «مو خطتك؟»: the phone keeps one plan, so a new one takes its place,
  /// once the person said the other is dropped from this phone.
  Future<void> _replacePhonePlan() async {
    final title = _phonePlanTitle ?? 'الخطة اللي على الجوال';
    final confirmed = await showJourneySheet<bool>(
      context: context,
      profile: JourneyProfile.groom,
      builder: (sheetContext) => JourneySheetBody(
        title: 'تبدأ خطة جديدة بدل $title؟',
        subtitle: '$title تنمسح من هذا الجوال وما ترجع.',
        children: [
          JourneyButton(
            key: const ValueKey('door-replace-confirm'),
            label: 'إيه، ابدأ من جديد',
            background: AarastV3Color.danger,
            expand: true,
            large: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton.quiet(
            label: 'لا، خلّها',
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final storage = context.read<GuestOnboardingStorage>();
    final draft = await storage.loadDraft();
    await storage.clearDraft();
    final planId = draft?.guestPlanId;
    final offline = _maybeRead<OfflineSyncService>();
    if (planId != null && planId.trim().isNotEmpty) {
      await offline?.database.deletePlanGraph(planId);
      await offline?.refreshStatus();
    }
    if (!mounted) return;
    setState(() => _phonePlanTitle = null);
    _goTo(_WelcomeStep.whose);
  }

  Future<void> _loadSavedDraft() async {
    final draft = await context.read<GuestOnboardingStorage>().loadDraft();
    if (!mounted || draft == null) return;
    if (draft.isCompleteGuestPlan) {
      setState(() => _phonePlanTitle = draft.planName?.trim() ?? 'خطتك');
      return;
    }
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
      final mahr = draft.mahr;
      if (mahr != null) {
        _mahrTotalController.text = formatMoneyInputValue(mahr.total);
        _mahrSettledController.text = formatMoneyInputValue(mahr.settled);
        _mahrDueDate = mahr.remainingDueDate;
      }
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
      mahr: _mahr,
    );
  }

  bool _isAuthenticated() {
    final auth = _maybeRead<AuthController>();
    return auth?.status == AuthStatus.authenticated;
  }

  /// The phone plan kept from «جاهزة», so going back and saving again
  /// keeps the same plan, not a second one.
  String? _keptPlanId;
  DateTime? _keptAt;

  /// Keeps the plan on the phone, then opens [route]. The items «جاهزة»
  /// promised («12 بند لعرسك») go into its money at once, as an account
  /// plan gets them from the server. Saving with the number opens over this
  /// screen, so its back arrow returns to «جاهزة» with every answer.
  Future<void> _keepOnPhone(String route, {bool over = false}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = _keptAt ?? DateTime.now();
    final planId = _keptPlanId ?? 'local-guest-${now.microsecondsSinceEpoch}';
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
        _error = _profile.say(
          'ما قدرنا نحفظ الخطة على جوالك. حاول مرة ثانية.',
          'ما قدرنا نحفظ الخطة على جوالك. حاولي مرة ثانية.',
        );
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _keptPlanId = planId;
      _keptAt = now;
    });
    if (over) {
      context.push(route);
    } else {
      context.go(route);
    }
  }

  /// A signed-in person creating another plan gets it on the server at once.
  Future<void> _createAccountPlan() async {
    final plans = _maybeRead<WeddingPlansProvider>();
    if (plans == null) {
      setState(
        () => _error = _profile.say(
          'ما قدرنا ننشئ الخطة الآن. حاول مرة ثانية.',
          'ما قدرنا ننشئ الخطة الآن. حاولي مرة ثانية.',
        ),
      );
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
        mahr: _mahr?.toRequestJson(),
      ),
    );
    if (!mounted) return;
    if (response == null) {
      setState(() {
        _saving = false;
        _error =
            plans.errorMessage ??
            _profile.say(
              'ما قدرنا ننشئ الخطة. تأكد من النت وحاول مرة ثانية.',
              'ما قدرنا ننشئ الخطة. تأكدي من النت وحاولي مرة ثانية.',
            );
      });
      return;
    }
    await authStorage?.saveActivePlanId(response.activePlanId);
    // The plan was made from the steps just answered; a phone plan kept
    // for later stays when this is another plan (w11).
    if (!widget.newPlan) await guestStorage.clearDraft();
    if (!mounted) return;
    await _maybeRead<AccountContextController>()?.refresh(
      allowInitialSingleContext: true,
    );
    if (!mounted) return;
    context.go(AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    // The start and «خطة مين؟» are the same for everyone. From a03 on the
    // plan being made already has its owner, so its steps take that
    // profile (the bride's rose and voice) before the plan exists.
    final shared = _step == _WelcomeStep.start || _step == _WelcomeStep.whose;
    // System back walks the steps like the arrow does. Only the first step
    // leaves the page, so answers are not lost to the phone's back key.
    final leavesPage =
        _step == _WelcomeStep.start ||
        (widget.newPlan && _step == _WelcomeStep.whose);
    return PopScope<Object?>(
      canPop: leavesPage,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AarastScreenFrame(
        maxWidth: 600,
        safeAreaBottom: false,
        backgroundColor: AarastV3Color.canvas,
        child: JourneyProfileScope(
          profile: shared ? JourneyProfile.groom : _profile,
          // Built under the scope, so every word is in the plan owner's
          // voice (the bride reads «تسمحين», not «تسمح»).
          child: Builder(
            builder: (context) => AnimatedSwitcher(
              duration: AarastV3Motion.standard,
              child: KeyedSubtree(key: ValueKey(_step), child: _page(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _page(BuildContext context) {
    return switch (_step) {
      _WelcomeStep.start => _StartStep(
        phonePlanTitle: _phonePlanTitle,
        onPlan: () => _phonePlanTitle != null
            ? context.go(AppRouter.home)
            : _goTo(_WelcomeStep.whose),
        onReplacePlan: _replacePhonePlan,
        onInvite: () => context.go(AppRouter.inviteAccess),
        // A provider without an account goes straight to their own
        // sign-up, never to a wall written for couples (D75).
        onProvider: () => context.go(
          _isAuthenticated()
              ? AppRouter.providerApply
              : '${AppRouter.register}?type=provider',
        ),
        onLogin: () => context.go(AppRouter.login),
      ),
      _WelcomeStep.whose => _WhoseStep(onChoose: _choosePersona, onBack: _back),
      _WelcomeStep.nameDate => _NameDateStep(
        controller: _nameController,
        date: _date,
        nameError: _nameMissing
            ? context.say('اكتب اسمك أول', 'اكتبي اسمك أول')
            : null,
        onNameChanged: () => setState(() => _nameMissing = false),
        onPickMonth: _pickDayInMonth,
        onLaterMonths: _pickLaterMonth,
        onNext: _name.isEmpty || _date == null
            ? null
            : () => _goTo(_WelcomeStep.placeBudget),
        onSkipDate: _skipDate,
        onBack: _back,
      ),
      _WelcomeStep.placeBudget => _PlaceBudgetStep(
        cities: _cities,
        city: _city,
        budgetController: _budgetController,
        cityError: _cityMissing
            ? context.say('اختر المدينة أول', 'اختاري المدينة أول')
            : null,
        onCity: (city) => setState(() {
          _city = city;
          _cityMissing = false;
        }),
        onMoreCities: _pickOtherCity,
        onBudgetChanged: () => setState(() => _budgetSkipped = false),
        onNext: _city == null || _budget == null
            ? null
            : () => _goTo(_WelcomeStep.mahr),
        onSkipBudget: _skipBudget,
        onBack: _back,
      ),
      _WelcomeStep.mahr => JourneyQuestionPage(
        step: 2,
        total: _questionCount,
        question: 'اتفقتوا على المهر؟',
        help: _persona == GuestPersona.bride
            ? 'اللي بتستلمينه من العريس. نحسبه برّا الميزانية ونقول لك كم باقي.'
            : 'اللي بتسلّمه لأهل العروسة. نحسبه برّا الميزانية ونقول لك كم باقي.',
        primaryLabel: 'التالي',
        onPrimary: _confirmMahr,
        onBack: _back,
        skipLabel: 'ما اتفقنا بعد',
        onSkip: _skipMahr,
        children: [
          JourneyNote(
            text: context.say(
              'أرقام المهر ما يشوفها غيرك، إلا اللي تسمح له يشوف المال.',
              'أرقام المهر ما يشوفها غيرك، إلا اللي تسمحين له يشوف المال.',
            ),
            icon: LucideIcons.lock,
            tone: JourneyNoteTone.bare,
            color: AarastV3Color.textMuted,
          ),
          const SizedBox(height: AarastV3Space.x3),
          MahrFields(
            pays: _persona != GuestPersona.bride,
            totalController: _mahrTotalController,
            settledController: _mahrSettledController,
            dueDate: _mahrDueDate,
            onPickDueDate: _pickMahrDueDate,
            onChanged: () => setState(() {
              _mahrError = null;
              _mahrSettledError = null;
            }),
            totalError: _mahrError,
            settledError: _mahrSettledError,
          ),
          // A reminder needs a day to remind of, and an account to send
          // it to: before the account it is a promise kept on saving.
          if (_mahrDueDate != null && _mahrRemaining > 0) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyNote(
              text: _isAuthenticated()
                  ? 'نذكّرك قبل الموعد.'
                  : context.say(
                      'لو حفظت خطتك برقمك، نذكّرك قبل الموعد.',
                      'لو حفظتي خطتك برقمك، نذكّرك قبل الموعد.',
                    ),
              icon: LucideIcons.bell,
              tone: JourneyNoteTone.bare,
            ),
          ],
        ],
      ),
      _WelcomeStep.ready => _ReadyStep(
        name: _name,
        subtitle: _readySubtitle(),
        moneyLine: _readyMoneyLine(),
        city: _city ?? '',
        providerCount: _providerCountCity == _city ? _providerCount : null,
        hasDate: !_dateUnknown && _date != null,
        catalogs: _catalogs(),
        signedIn: _isAuthenticated(),
        saving: _saving,
        error: _error,
        onSaveWithPhone: () => _keepOnPhone(AppRouter.register, over: true),
        onLookFirst: () => _keepOnPhone(AppRouter.home),
        onOpenPlan: _createAccountPlan,
        onBack: _back,
      ),
    };
  }

  JourneyProfile get _profile => JourneyProfile.fromPersona(_personaCode);

  int get _mahrRemaining =>
      MahrFields.remainingOf(_mahrTotalController, _mahrSettledController) ?? 0;

  String _readySubtitle() {
    final parts = <String>[_planTitle, ?_city];
    if (!_dateUnknown && _date != null) {
      parts.add(formatArabicWeekdayDayMonth(_date!));
      final hijri = HijriDate.fromGregorian(_date!);
      if (hijri != null) parts.add(hijri.dayAndMonth);
    }
    return parts.join(' · ');
  }

  /// What the plan's money starts with, only what was typed.
  String? _readyMoneyLine() {
    final parts = <String>[];
    final budget = _budgetSkipped ? null : _budget;
    if (budget != null) parts.add('الميزانية ${mahrWords(budget)}');
    final mahr = MahrFields.amountOf(_mahrTotalController);
    if (mahr != null && mahr > 0) {
      final rest = _mahrRemaining;
      parts.add(
        rest > 0
            ? 'المهر ${mahrWords(mahr)}، باقي ${mahrWords(rest)}'
            : 'المهر ${mahrWords(mahr)}',
      );
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _pickDayInMonth(DateTime month) async {
    releaseFieldFocus();
    final picked = await showJourneySheet<DateTime>(
      context: context,
      profile: _profile,
      builder: (sheetContext) => _DaySheet(
        month: DateTime(month.year, month.month),
        selected: _date,
        today: DateUtils.dateOnly(appNow()),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _dateUnknown = false;
    });
  }

  /// «موعدنا بعد ...»: the eighteen months after the six on the screen.
  Future<void> _pickLaterMonth() async {
    releaseFieldFocus();
    final today = DateUtils.dateOnly(appNow());
    final month = await showJourneySheet<DateTime>(
      context: context,
      profile: _profile,
      builder: (sheetContext) => _LaterMonthsSheet(
        first: DateTime(today.year, today.month + _monthsOnScreen),
        selected: _date,
      ),
    );
    if (month == null || !mounted) return;
    await _pickDayInMonth(month);
  }

  Future<void> _pickOtherCity() async {
    final picked = await showJourneySheet<String>(
      context: context,
      profile: _profile,
      builder: (sheetContext) => _CitySheet(cities: _cities, selected: _city),
    );
    if (picked == null || !mounted) return;
    setState(() => _city = picked);
  }
}

typedef ReferenceCatalogData = ({List<String> items, int taskCount});
