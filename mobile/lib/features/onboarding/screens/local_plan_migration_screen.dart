import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/local_plan_migration.dart';

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
  });

  final LocalPlanSnapshot snapshot;
  final LocalPlanMigrationService migrationService;

  /// Called with the account plan the local plan became, or null when the
  /// local plan was dropped.
  final ValueChanged<String?> onFinished;

  /// The account was just created to save this plan (a08b), so it is saved
  /// at once without looking for another plan.
  final bool autoSave;

  @override
  State<LocalPlanMigrationScreen> createState() =>
      _LocalPlanMigrationScreenState();
}

enum _Phase { checking, saving, choosing, failed }

/// Why saving into the account did not happen, in words for the user.
class _SaveFailure implements Exception {
  const _SaveFailure(this.message);

  final String message;
}

class _LocalPlanMigrationScreenState extends State<LocalPlanMigrationScreen> {
  static const _saveFailed =
      'ما قدرنا نحفظها في حسابك. تأكد من النت وجرّب مرة ثانية.';
  static const _lookupFailed =
      'ما قدرنا نشوف حسابك. تأكد من النت وجرّب مرة ثانية.';

  _Phase _phase = _Phase.checking;
  String? _error;
  AccountPlanCounts? _account;
  bool _sheetOpen = false;
  bool _busy = false;
  late Future<void> Function() _retry = _start;

  @override
  void initState() {
    super.initState();
    if (widget.autoSave) _phase = _Phase.saving;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  Future<void> _start() async {
    if (widget.autoSave) return _saveDirectly();
    setState(() {
      _phase = _Phase.checking;
      _error = null;
    });
    final AccountPlanCounts? account;
    try {
      account = await widget.migrationService.accountPlanCounts();
    } on Object {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = _lookupFailed;
        _retry = _start;
      });
      return;
    }
    if (!mounted) return;
    if (account == null) return _saveDirectly();
    _account = account;
    await _openChoice();
  }

  Future<void> _saveDirectly() async {
    setState(() {
      _phase = _Phase.saving;
      _error = null;
    });
    try {
      final planId = await _save();
      if (!mounted) return;
      widget.onFinished(planId);
    } on _SaveFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = failure.message;
        _retry = _saveDirectly;
      });
    }
  }

  Future<void> _openChoice() async {
    final account = _account;
    if (account == null) return;
    setState(() {
      _phase = _Phase.choosing;
      _sheetOpen = true;
    });
    final outcome = await showJourneySheet<({String? planId})>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _LocalPlanChoiceSheet(
        local: _counts(
          widget.snapshot.itemNames.length,
          widget.snapshot.tasks.length,
        ),
        account: _counts(account.items, account.tasks),
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
    widget.onFinished(outcome.planId);
  }

  /// Saves the plan into the account and only then clears it from this
  /// phone. Returns the account plan it became.
  Future<String> _save() async {
    final authStorage = _read<AuthStorage>();
    final offlineSync = _read<OfflineSyncService>();
    try {
      final response = await widget.migrationService.migrate(widget.snapshot);
      // The server confirmed: only now is it safe to clear the phone's plan.
      await authStorage?.saveActivePlanId(response.activePlanId);
      await _clearPhonePlan(offlineSync);
      return response.activePlanId;
    } on ApiException catch (error) {
      throw _SaveFailure(error.message);
    } on Object {
      throw const _SaveFailure(_saveFailed);
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
      builder: (sheetContext) => JourneySheetBody(
        title: 'تمسح الخطة اللي على الجوال؟',
        subtitle: _account == null
            ? 'تنحذف من هذا الجوال وما ترجع.'
            : 'تنحذف من هذا الجوال وما ترجع. خطتك اللي في حسابك ما تتأثر.',
        children: [
          JourneyButton(
            key: const ValueKey('local-plan-drop-confirm'),
            label: 'إيه، امسحها',
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
    return confirmed == true;
  }

  Future<void> _dropFromFailure() async {
    if (_busy || !await _confirmDrop(context) || !mounted) return;
    setState(() => _busy = true);
    await _drop();
    if (!mounted) return;
    widget.onFinished(null);
  }

  @override
  Widget build(BuildContext context) {
    final planName = widget.snapshot.draft.planName?.trim();
    final saving = planName == null || planName.isEmpty ? 'خطتك' : planName;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
        children: [
          const SizedBox(height: AarastV3Space.x8),
          const Center(child: JourneyWordmark(size: 34)),
          const SizedBox(height: AarastV3Space.x8),
          if (_phase == _Phase.checking || _phase == _Phase.saving) ...[
            const Center(child: AarastInlineSpinner(dimension: 32)),
            if (_phase == _Phase.saving) ...[
              const SizedBox(height: AarastV3Space.x4),
              Text(
                'نحفظ $saving في حسابك',
                textAlign: TextAlign.center,
                style: JourneyType.of(
                  JourneyType.body,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ],
          ],
          if (_phase == _Phase.choosing && !_sheetOpen)
            JourneyButton(
              label: 'متابعة',
              expand: true,
              large: true,
              onPressed: _openChoice,
            ),
          if (_phase == _Phase.failed) ...[
            JourneyNote(
              text: _error ?? _saveFailed,
              icon: LucideIcons.alertCircle,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
            const SizedBox(height: AarastV3Space.x2),
            Text(
              'خطتك باقية على هذا الجوال، ما تنحذف لين تنحفظ في حسابك.',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
            const SizedBox(height: AarastV3Space.x4),
            JourneyButton(
              label: 'جرّب مرة ثانية',
              expand: true,
              large: true,
              onPressed: _busy ? null : _retry,
            ),
            const SizedBox(height: AarastV3Space.x1),
            Center(
              child: JourneyTextAction(
                label: 'امسحها من الجوال',
                onPressed: _busy ? null : _dropFromFailure,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

enum _Choice { secondPlan, drop }

/// The w09 sheet: both plans' counts, the two choices and «متابعة». It
/// stays open while the plan saves, so a failure shows here and the choice
/// can be made again.
class _LocalPlanChoiceSheet extends StatefulWidget {
  const _LocalPlanChoiceSheet({
    required this.local,
    required this.account,
    required this.save,
    required this.confirmDrop,
    required this.drop,
  });

  final String local;
  final String account;
  final Future<String> Function() save;
  final Future<bool> Function(BuildContext context) confirmDrop;
  final Future<void> Function() drop;

  @override
  State<_LocalPlanChoiceSheet> createState() => _LocalPlanChoiceSheetState();
}

class _LocalPlanChoiceSheetState extends State<_LocalPlanChoiceSheet> {
  _Choice _choice = _Choice.secondPlan;
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
      Navigator.of(context).pop((planId: null));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final planId = await widget.save();
      if (!mounted) return;
      Navigator.of(context).pop((planId: planId));
    } on _SaveFailure catch (failure) {
      if (!mounted) return;
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
        subtitle: 'سويتها قبل ما تدخل. وحسابك فيه خطة من قبل.',
        children: [
          Row(
            children: [
              Expanded(
                child: _CountCard(label: 'على الجوال', value: widget.local),
              ),
              const SizedBox(width: AarastV3Space.x2),
              Expanded(
                child: _CountCard(label: 'في حسابك', value: widget.account),
              ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x3),
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
            title: 'تجاهلها',
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
            onPressed: _continue,
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
      padding: const EdgeInsets.all(AarastV3Space.x3),
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
