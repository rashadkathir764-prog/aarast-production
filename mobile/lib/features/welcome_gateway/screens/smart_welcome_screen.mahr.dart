part of 'smart_welcome_screen.dart';

/// a06 «اتفقتوا على المهر؟»: the mahr, what was handed over or received,
/// the rest's day; and on a groom's plan with a budget, once the mahr is
/// typed, whether the budget holds it (D114).
class _MahrStep extends StatelessWidget {
  const _MahrStep({
    required this.bride,
    required this.totalController,
    required this.settledController,
    required this.dueDate,
    required this.onPickDueDate,
    required this.onChanged,
    required this.settledError,
    required this.remindsOfRest,
    required this.signedIn,
    required this.totalMissing,
    required this.askInside,
    required this.inside,
    required this.budget,
    required this.onInside,
    required this.onNext,
    required this.onSkip,
    required this.onBack,
  });

  final bool bride;
  final TextEditingController totalController;
  final TextEditingController settledController;
  final DateTime? dueDate;
  final VoidCallback onPickDueDate;
  final VoidCallback onChanged;
  final String? settledError;

  /// The groom's rest has a day: the server reminds of it.
  final bool remindsOfRest;
  final bool signedIn;
  final bool totalMissing;

  /// D114: the budget is typed and so is the mahr, on a groom's plan.
  final bool askInside;
  final bool inside;
  final int? budget;
  final ValueChanged<bool> onInside;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return JourneyQuestionPage(
      step: 2,
      total: _questionCount,
      question: 'اتفقتوا على المهر؟',
      // D114: where the groom's mahr counts is his answer below.
      help: bride
          ? 'اللي بتستلمينه من العريس. نحسبه برّا الميزانية ونقول لك كم باقي.'
          : 'اللي بتسلّمه لأهل العروسة. نتابع كم سلّمت وكم باقي.',
      primaryLabel: 'التالي',
      // J1-18, as the two steps before it: «التالي» waits, greyed, and a
      // quiet line says what it waits for. This step alone kept it live
      // and answered a press with a red error, so a reader who had learnt
      // «grey means something is missing» over two steps met a green
      // button on the third and was told off for trusting it. «ما اتفقنا
      // بعد» stays the way past, which is the real answer when there is
      // no mahr yet.
      onPrimary: totalMissing ? null : onNext,
      onBack: onBack,
      skipLabel: 'ما اتفقنا بعد',
      onSkip: onSkip,
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
          pays: !bride,
          totalController: totalController,
          settledController: settledController,
          dueDate: dueDate,
          onPickDueDate: onPickDueDate,
          onChanged: onChanged,
          settledError: settledError,
        ),
        // A reminder needs a day to remind of, and an account to send
        // it to: before the account it is a promise kept on saving.
        // J1-16: only the groom's rest becomes a payment the server
        // reminds of; the bride is promised none.
        if (remindsOfRest) ...[
          const SizedBox(height: AarastV3Space.x2),
          JourneyNote(
            text: signedIn
                ? 'نذكّرك قبل الموعد.'
                : context.say(
                    'لو حفظت خطتك برقمك، نذكّرك قبل الموعد.',
                    'لو حفظتي خطتك برقمك، نذكّرك قبل الموعد.',
                  ),
            icon: LucideIcons.bell,
            tone: JourneyNoteTone.bare,
          ),
        ],
        if (askInside) ...[
          const SizedBox(height: AarastV3Space.x4),
          MahrBudgetChoice(
            inside: inside,
            budget: budget,
            mahr: MahrFields.amountOf(totalController),
            onChanged: onInside,
          ),
        ],
        ..._missingLine(
          totalMissing ? context.say('اكتب كم المهر', 'اكتبي كم المهر') : null,
        ),
      ],
    );
  }
}
