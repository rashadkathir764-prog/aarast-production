import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../finance/finance_api.dart'
    show FinanceProvider, MahrFields, pickMahrDueDate;
import '../../onboarding/onboarding_api.dart'
    show DraftMahr, GuestOnboardingStorage;

/// a06 «اتفقتوا على المهر؟» for a plan that exists (b01's mahr step): the
/// mahr, what was handed over or received, and the day the rest is due. A
/// saved plan records it on the server once (C1); a plan still on the phone
/// keeps it with its draft until the account saves the plan.
class MahrScreen extends StatefulWidget {
  const MahrScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<MahrScreen> createState() => _MahrScreenState();
}

class _MahrScreenState extends State<MahrScreen> {
  /// D86: the plan's currency once its money is loaded; rial until then.
  String _currency(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    return finance.loadedPlanId == widget.weddingPlanId
        ? finance.summary.currency
        : 'YER';
  }

  final _total = TextEditingController();
  final _settled = TextEditingController();
  DateTime? _dueDate;
  String? _totalError;
  String? _settledError;
  String? _error;
  bool _saving = false;

  bool get _isLocalPlan =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void dispose() {
    _total.dispose();
    _settled.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await pickMahrDueDate(context, _dueDate);
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final total = MahrFields.amountOf(_total) ?? 0;
    final settled = MahrFields.amountOf(_settled) ?? 0;
    setState(() {
      _error = null;
      _totalError = total <= 0
          ? context.say('اكتب كم المهر', 'اكتبي كم المهر')
          : null;
      _settledError = settled > total ? 'أكثر من المهر نفسه' : null;
    });
    if (_totalError != null || _settledError != null) return;
    final due = settled < total ? _dueDate : null;
    setState(() => _saving = true);
    var saved = false;
    if (_isLocalPlan) {
      final storage = context.read<GuestOnboardingStorage>();
      final draft = await storage.loadDraft();
      if (draft != null) {
        await storage.saveDraft(
          draft.copyWith(
            mahr: DraftMahr(
              total: '$total',
              settled: '$settled',
              remainingDueDate: due,
            ),
          ),
        );
        saved = true;
      }
    } else {
      final finance = context.read<FinanceProvider>();
      if (finance.loadedPlanId != widget.weddingPlanId) {
        await finance.loadMoney(widget.weddingPlanId);
      }
      saved = await finance.recordMahr(
        planId: widget.weddingPlanId,
        total: '$total',
        settled: '$settled',
        remainingDueDate: due,
      );
      if (!saved) _error = finance.errorMessage;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      setState(
        () => _error ??= context.say(
          'ما قدرنا نحفظ المهر. حاول مرة ثانية.',
          'ما قدرنا نحفظ المهر. حاولي مرة ثانية.',
        ),
      );
      return;
    }
    context.popOrGo(AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    // The plan's side: the groom's plan pays it, the bride's receives it.
    final pays = !context.journeyProfile.isBride;
    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: JourneyQuestionPage(
        step: 0,
        total: 1,
        question: 'اتفقتوا على المهر؟',
        help: pays
            ? context.say(
                'اللي بتسلّمه لأهل العروسة. نحسبه لحاله ونذكرك بموعد تسليمه.',
                'اللي بتسلّمينه لأهل العروسة. نحسبه لحاله ونذكرك بموعد تسليمه.',
              )
            : context.say(
                'اللي بتستلمه من العريس. نحسبه لحاله ونذكرك بموعد استلامه.',
                'اللي بتستلمينه من العريس. نحسبه لحاله ونذكرك بموعد استلامه.',
              ),
        primaryLabel: 'احفظ المهر',
        loading: _saving,
        onPrimary: _saving ? null : _save,
        onBack: () => context.popOrGo(AppRouter.home),
        skipLabel: 'ما اتفقنا بعد',
        onSkip: () => context.popOrGo(AppRouter.home),
        children: [
          MahrFields(
            // D86: the plan's currency, as the money tab shows it.
            currency: _currency(context),
            pays: pays,
            totalController: _total,
            settledController: _settled,
            dueDate: _dueDate,
            onPickDueDate: _pickDueDate,
            onChanged: () => setState(() {}),
            totalError: _totalError,
            settledError: _settledError,
          ),
          if (_error != null) ...[
            const SizedBox(height: AarastV3Space.x3),
            JourneyNote(
              text: _error!,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
          ],
        ],
      ),
    );
  }
}
