import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthController;
import '../data/local_plan_migration.dart';
import '../models/guest_onboarding_draft.dart' show GuestPersona;

/// w09 «عندك خطة على هذا الجوال»: right after sign-in, a plan made on this
/// phone before signing in meets the account.
///
/// When the account already owns an open plan, a sheet over the wordmark
/// shows both plans' counts and asks: keep it as a second plan (import-local
/// always makes a new plan; there is no merge) or drop it from this phone.
/// When the account owns none, or was just made to save this plan (a08b),
/// the plan is saved at once.
///
/// Trust rules:
/// - The phone's plan is deleted ONLY after the server confirms the import.
/// - Dropping it is confirmed twice: the choice, then a confirmation (C62).
class LocalPlanMigrationScreen extends StatefulWidget {
  const LocalPlanMigrationScreen({
    super.key,
    required this.snapshot,
    required this.migrationService,
    required this.onFinished,
    this.autoSave = false,
    this.localPlan,
    this.startLocally = false,
    this.onOpenedLocally,
  });

  final LocalPlanSnapshot snapshot;
  final LocalPlanMigrationService migrationService;

  /// Called with the account plan the local plan became, or null when the
  /// local plan was dropped.
  final ValueChanged<String?> onFinished;

  /// The account was just created to save this plan (a08b), so it is saved
  /// at once without looking for another plan.
  final bool autoSave;

  /// D77 (J1-01): the plan's home on this phone, for when the account could
  /// not take it: a failure never locks the app. Built with `saveNow`, the
  /// move into the account again, for its «ما انحفظت في حسابك بعد» strip.
  /// Without it the failure offers only trying again or dropping the plan.
  final Widget Function(BuildContext context, VoidCallback saveNow)? localPlan;

  /// The person opened the plan on the phone earlier in this session: it
  /// opens there again, and the move is tried quietly (now, and each time
  /// the app comes back) instead of locking the app again.
  final bool startLocally;

  /// Told when the person opens the plan on the phone, so the session can
  /// remember it ([startLocally]).
  final VoidCallback? onOpenedLocally;

  @override
  State<LocalPlanMigrationScreen> createState() =>
      _LocalPlanMigrationScreenState();
}

/// [_Phase.local]: the plan is open on the phone, not in the account yet.
enum _Phase { checking, saving, choosing, failed, local }

/// Fixed dimensions of this layout, not spacing steps (D74): where the
/// saving or failure sits on the page, and its mark.
const _outcomeTop = 140.0;
const _markSize = 72.0;

/// Why saving into the account did not happen, in words for the user.
class _SaveFailure implements Exception {
  const _SaveFailure(this.message, {this.savedBefore = false});

  final String message;

  /// RA-BE-65: an earlier try reached the account and its answer was lost,
  /// and the plan changed on the phone since. The phone keeps it and asks.
  final bool savedBefore;
}

class _LocalPlanMigrationScreenState extends State<LocalPlanMigrationScreen> {
  _Phase _phase = _Phase.checking;
  String? _error;
  AccountPlanCounts? _account;
  bool _sheetOpen = false;
  bool _busy = false;

  /// The failure shown is «خطتك انحفظت في حسابك من محاولة قبل» (RA-BE-65).
  bool _savedBefore = false;
  late Future<void> Function() _retry = _start;

  /// The phone plan's owner: the colour and voice of this screen and its
  /// sheets.
  ///
  /// The words go to the one reading: the plan's owner, unless the plan is
  /// the other side's, when the account holder reads about someone else's.
  JourneyProfile get _owner => JourneyProfile.fromPersona(
    _otherSide
        ? _accountPersona
        : widget.snapshot.draft.persona == GuestPersona.bride
        ? 'BRIDE'
        : 'GROOM',
  );

  String? get _accountPersona {
    try {
      return context.read<AuthController>().user?.persona;
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Tries the move again whenever the app comes back while the plan is
  /// open on the phone (D77).
  AppLifecycleListener? _lifecycle;
  bool _tryingQuietly = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoSave) _phase = _Phase.saving;
    if (widget.startLocally && widget.localPlan != null) {
      _phase = _Phase.local;
      _lifecycle = AppLifecycleListener(onResume: _tryQuietly);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _phase == _Phase.local ? _tryQuietly() : _start();
    });
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  /// The plan opens on the phone (D77): the app goes on, and the session
  /// remembers it so the next home does not lock again.
  void _openLocally() {
    if (_busy) return;
    _lifecycle ??= AppLifecycleListener(onResume: _tryQuietly);
    setState(() => _phase = _Phase.local);
    widget.onOpenedLocally?.call();
  }

  /// «احفظها الحين» on the phone plan's strip: the move again, in view (the
  /// choice when the account has a plan, the failure if it fails again).
  void _saveFromPhone() {
    if (_tryingQuietly) return;
    _retry();
  }

  /// The move again without a word on the screen while the plan is open on
  /// the phone. Only a plan with nothing to choose is saved on its own; a
  /// choice (an account with a plan, the other side's plan) stays the
  /// person's, from the strip.
  Future<void> _tryQuietly() async {
    if (_phase != _Phase.local || _tryingQuietly) return;
    _tryingQuietly = true;
    try {
      if (!widget.autoSave) {
        final account = await widget.migrationService.accountPlanCounts();
        if (account != null || _otherSide) return;
      }
      final planId = await _save();
      if (!mounted) return;
      _lifecycle?.dispose();
      _lifecycle = null;
      widget.onFinished(planId);
    } on Object {
      // Still offline, or refused: the plan stays open on the phone and its
      // strip still offers saving it.
    } finally {
      _tryingQuietly = false;
    }
  }

  /// «ما فيه نت الحين»: the failure said as it is when the phone is offline.
  static bool _isOffline(Object error) =>
      error is ApiException && error.isNetworkFailure;

  String get _offlineMessage => 'ما فيه نت الحين، فما قدرنا نوصل لحسابك.';

  Future<void> _start() async {
    if (widget.autoSave) return _saveDirectly();
    setState(() {
      _phase = _Phase.checking;
      _error = null;
    });
    final AccountPlanCounts? account;
    try {
      account = await widget.migrationService.accountPlanCounts();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = _isOffline(error)
            ? _offlineMessage
            : _owner.say(
                'ما قدرنا نشوف حسابك. تأكد من النت وجرّب مرة ثانية.',
                'ما قدرنا نشوف حسابك. تأكدي من النت وجرّبي مرة ثانية.',
              );
        _retry = _start;
      });
      return;
    }
    if (!mounted) return;
    // The other side's plan is never taken in on its own, even into an
    // account without a plan: its owner decides (D75).
    if (account == null && !_otherSide) return _saveDirectly();
    _account =
        account ??
        const AccountPlanCounts(items: 0, tasks: 0, title: _noAccountPlan);
    await _openChoice();
  }

  Future<void> _saveDirectly() async {
    setState(() {
      _phase = _Phase.saving;
      _error = null;
      _savedBefore = false;
    });
    try {
      final planId = await _save();
      if (!mounted) return;
      widget.onFinished(planId);
    } on _SaveFailure catch (failure) {
      if (!mounted) return;
      _showFailure(failure);
    }
  }

  void _showFailure(_SaveFailure failure) {
    setState(() {
      _phase = _Phase.failed;
      _error = failure.message;
      _savedBefore = failure.savedBefore;
      _retry = failure.savedBefore ? _saveAsSecondPlan : _saveDirectly;
    });
  }

  /// RA-BE-65: the account holds the plan as it was at an earlier try; the
  /// phone's plan, changed since, is saved next to it as a second plan, so
  /// nothing done between the two tries is lost. A new save with its own id,
  /// kept for every retry of it.
  Future<void> _saveAsSecondPlan() async {
    final guestPlanId = widget.snapshot.draft.guestPlanId;
    if (guestPlanId != null && guestPlanId.trim().isNotEmpty) {
      await widget.migrationService.guestStorage.startNewImport(guestPlanId);
    }
    if (!mounted) return;
    await _saveDirectly();
  }

  Future<void> _openChoice() async {
    final account = _account;
    if (account == null) return;
    setState(() {
      _phase = _Phase.choosing;
      _sheetOpen = true;
    });
    final outcome =
        await showJourneySheet<({String? planId, bool savedBefore})>(
          context: context,
          profile: _owner,
          isDismissible: false,
          enableDrag: false,
          builder: (_) => _LocalPlanChoiceSheet(
            local: _localTitle.isEmpty
                ? _counts(
                    widget.snapshot.itemNames.length,
                    widget.snapshot.tasks.length,
                  )
                : _localTitle,
            account: account.title.isEmpty
                ? _counts(account.items, account.tasks)
                : account.title,
            otherSide: _otherSide,
            accountHasPlan:
                account.items > 0 ||
                account.tasks > 0 ||
                account.title != _noAccountPlan,
            save: _save,
            confirmDrop: _confirmDrop,
            drop: _drop,
          ),
        );
    if (!mounted) return;
    if (outcome == null) {
      setState(() => _sheetOpen = false);
      return;
    }
    if (outcome.savedBefore) {
      setState(() => _sheetOpen = false);
      _showFailure(_SaveFailure(_savedBeforeMessage ?? '', savedBefore: true));
      return;
    }
    widget.onFinished(outcome.planId);
  }

  /// The phone's plan is the other side's (the bride's plan on the groom's
  /// account, or the other way): each makes their own plan (D75), so it is
  /// not taken in; it stays on the phone for its owner to save by her number.
  bool get _otherSide {
    final account = _accountPersona;
    final plan = switch (widget.snapshot.draft.persona) {
      GuestPersona.bride => 'BRIDE',
      GuestPersona.groom => 'GROOM',
      _ => null,
    };
    return (account == 'BRIDE' || account == 'GROOM') &&
        plan != null &&
        account != plan;
  }

  /// The server's words for RA-BE-65, kept for the failure shown after the
  /// choice sheet closes.
  String? _savedBeforeMessage;

  /// Saves the plan into the account and only then clears it from this
  /// phone. Returns the account plan it became.
  ///
  /// The plan is read again from the phone first: it may have changed since
  /// this screen opened (opened on the phone after a failure, D77), and
  /// sending what was read then would save the old plan and clear the new.
  Future<String> _save() async {
    final authStorage = _read<AuthStorage>();
    final offlineSync = _read<OfflineSyncService>();
    try {
      final snapshot =
          await widget.migrationService.loadSnapshot() ?? widget.snapshot;
      final response = await widget.migrationService.migrate(snapshot);
      // The server confirmed: only now is it safe to clear the phone's plan.
      await authStorage?.saveActivePlanId(response.activePlanId);
      await _clearPhonePlan(offlineSync);
      return response.activePlanId;
    } on LocalPlanTooLarge catch (error) {
      throw _SaveFailure(error.message);
    } on ApiException catch (error) {
      if (error.isNetworkFailure) throw _SaveFailure(_offlineMessage);
      if (error.serverCode == 'LOCAL_PLAN_SAVED_BEFORE') {
        _savedBeforeMessage = error.message;
        throw _SaveFailure(error.message, savedBefore: true);
      }
      // J1-13: the server's checks (an English detail, so a generic line by
      // the time it is here) said no; trying again will not change that.
      final refused = error.statusCode == 400 || error.statusCode == 422;
      if (refused && error.serverCode == null) {
        throw const _SaveFailure(
          'فيه شي في خطتك ما قبله الحساب، فما انحفظت فيه.',
        );
      }
      throw _SaveFailure(error.message);
    } on Object {
      throw _SaveFailure(
        _owner.say(
          'تأكد من النت وجرّب مرة ثانية.',
          'تأكدي من النت وجرّبي مرة ثانية.',
        ),
      );
    }
  }

  Future<void> _drop() => _clearPhonePlan(_read<OfflineSyncService>());

  Future<void> _clearPhonePlan(OfflineSyncService? offlineSync) async {
    await widget.migrationService.guestStorage.clearDraft();
    final guestPlanId = widget.snapshot.draft.guestPlanId;
    if (guestPlanId != null && guestPlanId.trim().isNotEmpty) {
      await offlineSync?.database.deletePlanGraph(guestPlanId);
      await offlineSync?.refreshStatus();
    }
  }

  T? _read<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// The second confirmation before the phone's plan is dropped (C62).
  Future<bool> _confirmDrop(BuildContext context) async {
    final confirmed = await showJourneySheet<bool>(
      context: context,
      profile: _owner,
      builder: (sheetContext) => JourneySheetBody(
        title: _owner.say(
          'تمسح الخطة اللي على الجوال؟',
          'تمسحين الخطة اللي على الجوال؟',
        ),
        subtitle: _account == null
            ? 'تنحذف من هذا الجوال وما ترجع.'
            : 'تنحذف من هذا الجوال وما ترجع. خطتك اللي في حسابك ما تتأثر.',
        children: [
          JourneyButton(
            key: const ValueKey('local-plan-drop-confirm'),
            label: _owner.say('إيه، امسحها', 'إيه، امسحيها'),
            background: AarastV3Color.danger,
            expand: true,
            large: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton.quiet(
            label: _owner.say('لا، خلّها', 'لا، خلّيها'),
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _dropFromFailure() async {
    if (_busy || !await _confirmDrop(context) || !mounted) return;
    setState(() => _busy = true);
    await _drop();
    if (!mounted) return;
    widget.onFinished(null);
  }

  /// «عرس محمد · صنعاء», the plan on this phone.
  String get _localTitle {
    final draft = widget.snapshot.draft;
    return [
      draft.planName?.trim() ?? '',
      draft.city?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final persona = widget.snapshot.draft.persona == GuestPersona.bride
        ? 'BRIDE'
        : 'GROOM';
    final localPlan = widget.localPlan;
    return JourneyProfileScope(
      profile: JourneyProfile.fromPersona(persona),
      child: _phase == _Phase.local && localPlan != null
          ? Builder(builder: (context) => localPlan(context, _saveFromPhone))
          : Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    final planName = widget.snapshot.draft.planName?.trim();
    final saving = planName == null || planName.isEmpty ? 'خطتك' : planName;
    final failed = _phase == _Phase.failed;
    final retry = JourneyButton(
      key: _savedBefore ? const ValueKey('local-plan-save-second') : null,
      label: _savedBefore
          ? context.say(
              'احفظ اللي على الجوال كخطة ثانية',
              'احفظي اللي على الجوال كخطة ثانية',
            )
          : context.say('جرّب مرة ثانية', 'جرّبي مرة ثانية'),
      expand: true,
      large: true,
      onPressed: _busy ? null : _retry,
    );
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: JourneyPage(
        bottom: failed
            ? JourneyEntryActions(
                // D77: the third way out, so a failure never locks the app.
                primary: widget.localPlan == null
                    ? retry
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          retry,
                          const SizedBox(height: AarastV3Space.x2),
                          JourneyButton.outline(
                            key: const ValueKey('local-plan-open-on-phone'),
                            label: context.say(
                              'افتح خطتك على الجوال الحين',
                              'افتحي خطتك على الجوال الحين',
                            ),
                            expand: true,
                            large: true,
                            onPressed: _busy ? null : _openLocally,
                          ),
                        ],
                      ),
                secondary: JourneyTextAction(
                  label: context.say('امسحها من الجوال', 'امسحيها من الجوال'),
                  onPressed: _busy ? null : _dropFromFailure,
                ),
              )
            : _phase == _Phase.choosing && !_sheetOpen
            ? JourneyEntryActions(
                primary: JourneyButton(
                  label: 'متابعة',
                  expand: true,
                  large: true,
                  onPressed: _openChoice,
                ),
              )
            : null,
        children: [
          const SizedBox(height: _outcomeTop),
          if (failed)
            _Outcome(
              mark: Container(
                width: _markSize,
                height: _markSize,
                decoration: const BoxDecoration(
                  color: AarastV3Color.brandAccentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.alertCircle,
                  size: AarastV3Space.x8,
                  color: AarastV3Color.brandAccentStrong,
                ),
              ),
              title: _savedBefore
                  ? 'خطتك في حسابك من قبل'
                  : 'ما قدرنا نحفظها في حسابك',
              body: _savedBefore
                  ? '${_error ?? ''}\n'
                        'اللي تغيّر بعدها باقي على هذا الجوال، ما ينحذف إلا باختيارك.'
                  : '${_error ?? context.say('تأكد من النت وجرّب مرة ثانية.', 'تأكدي من النت وجرّبي مرة ثانية.')}\n'
                        'خطتك باقية على هذا الجوال، ما تنحذف لين تنحفظ في حسابك.',
            )
          else
            _Outcome(
              mark: AarastInlineSpinner(
                dimension: _markSize,
                color: context.accent.primary,
              ),
              title: _phase == _Phase.saving
                  ? 'نحفظ $saving في حسابك'
                  : 'نفتح حسابك',
              body: _phase == _Phase.saving
                  ? context.say(
                      'البنود والمهر والموعد، كما سويتها.',
                      'البنود والمهر والموعد، كما سويتيها.',
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// The middle of the page while saving, or when saving failed: a mark, a
/// title and what it means.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.mark, required this.title, this.body});

  final Widget mark;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        mark,
        const SizedBox(height: AarastV3Space.x6),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.question,
              weight: JourneyType.bold,
            ),
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: AarastV3Space.x2),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.bodyLarge,
              color: AarastV3Color.textMuted,
              height: 1.55,
            ),
          ),
        ],
      ],
    );
  }
}

/// «12 بند · 20 مهمة», when a plan has no name to show.
String _counts(int items, int tasks) {
  final itemsLine = arabicCount(
    items,
    one: 'بند واحد',
    two: 'بندين',
    few: 'بنود',
    many: 'بند',
  );
  final tasksLine = arabicCount(
    tasks,
    one: 'مهمة واحدة',
    two: 'مهمتين',
    few: 'مهام',
    many: 'مهمة',
  );
  return '$itemsLine · $tasksLine';
}

enum _Choice { secondPlan, keepForOwner, drop }

/// The account side of the sheet when the account holds no plan yet.
const _noAccountPlan = 'ما فيه خطة بعد';

/// The w09 sheet: both plans' counts, the two choices and «متابعة». It
/// stays open while the plan saves, so a failure shows here and the choice
/// can be made again.
class _LocalPlanChoiceSheet extends StatefulWidget {
  const _LocalPlanChoiceSheet({
    required this.local,
    required this.account,
    required this.otherSide,
    required this.accountHasPlan,
    required this.save,
    required this.confirmDrop,
    required this.drop,
  });

  final String local;
  final String account;

  /// The phone's plan belongs to the other side: it is kept for its owner,
  /// not taken in as a second plan of this account.
  final bool otherSide;
  final bool accountHasPlan;
  final Future<String> Function() save;
  final Future<bool> Function(BuildContext context) confirmDrop;
  final Future<void> Function() drop;

  @override
  State<_LocalPlanChoiceSheet> createState() => _LocalPlanChoiceSheetState();
}

class _LocalPlanChoiceSheetState extends State<_LocalPlanChoiceSheet> {
  /// Nothing is chosen for the person: «متابعة» waits for a choice.
  _Choice? _choice;
  bool _busy = false;
  String? _error;

  Future<void> _continue() async {
    if (_busy) return;
    if (_choice == _Choice.drop) {
      if (!await widget.confirmDrop(context) || !mounted) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      await widget.drop();
      if (!mounted) return;
      Navigator.of(context).pop((planId: null, savedBefore: false));
      return;
    }
    if (_choice == null) return;
    if (_choice == _Choice.keepForOwner) {
      Navigator.of(context).pop((planId: null, savedBefore: false));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final planId = await widget.save();
      if (!mounted) return;
      Navigator.of(context).pop((planId: planId, savedBefore: false));
    } on _SaveFailure catch (failure) {
      if (!mounted) return;
      // RA-BE-65: the choice it needs is the page's, not this sheet's.
      if (failure.savedBefore) {
        Navigator.of(context).pop((planId: null, savedBefore: true));
        return;
      }
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  void _pick(_Choice choice) {
    if (_busy) return;
    setState(() => _choice = choice);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: JourneySheetBody(
        title: 'عندك خطة على هذا الجوال',
        subtitle: widget.accountHasPlan
            ? context.say(
                'سويتها قبل ما تدخل. وحسابك فيه خطة من قبل.',
                'سويتيها قبل ما تدخلين. وحسابك فيه خطة من قبل.',
              )
            : context.say('سويتها قبل ما تدخل.', 'سويتيها قبل ما تدخلين.'),
        children: [
          Row(
            children: [
              Expanded(
                child: _CountCard(label: 'على هذا الجوال', value: widget.local),
              ),
              const SizedBox(width: AarastV3Space.x2),
              Expanded(
                child: _CountCard(label: 'في حسابك', value: widget.account),
              ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x3),
          if (widget.otherSide)
            JourneyOption(
              key: const ValueKey('local-plan-keep-for-owner'),
              title: context.say(
                'خلّها على الجوال لصاحبتها',
                'خلّيها على الجوال لصاحبها',
              ),
              subtitle: context.say(
                'هذي خطة العروسة: تحفظها هي برقمها',
                'هذي خطة العريس: يحفظها هو برقمه',
              ),
              selected: _choice == _Choice.keepForOwner,
              onTap: () => _pick(_Choice.keepForOwner),
            )
          else
            JourneyOption(
              key: const ValueKey('local-plan-second'),
              title: 'خلّها خطة ثانية',
              subtitle: 'مثلًا لو هي لعرس أخوك',
              selected: _choice == _Choice.secondPlan,
              onTap: () => _pick(_Choice.secondPlan),
            ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyOption(
            key: const ValueKey('local-plan-drop'),
            title: context.say('تجاهلها', 'تجاهليها'),
            subtitle: 'تنحذف من الجوال بس',
            selected: _choice == _Choice.drop,
            onTap: () => _pick(_Choice.drop),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyNote(
              text: error,
              icon: LucideIcons.alertCircle,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
          ],
          const SizedBox(height: AarastV3Space.x4),
          JourneyButton(
            key: const ValueKey('local-plan-continue'),
            label: 'متابعة',
            expand: true,
            large: true,
            loading: _busy,
            onPressed: _choice == null ? null : _continue,
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      color: AarastV3Color.canvas,
      radius: AarastV3Radius.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x3,
        vertical: AarastV3Space.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: JourneyType.of(
              JourneyType.label,
              color: AarastV3Color.textMuted,
            ),
          ),
          Text(
            value,
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
        ],
      ),
    );
  }
}
