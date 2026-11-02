part of 'provider_apply_screen.dart';

/// A step's heading (24 bold), and its line under it when it has one.
class _StepTitle extends StatelessWidget {
  const _StepTitle(this.text, {this.sub});

  final String text;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            text,
            style: JourneyType.of(
              JourneyType.display,
              weight: JourneyType.bold,
            ),
          ),
        ),
        if (sub case final line?)
          Text(
            line,
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
              height: 1.45,
            ),
          ),
      ],
    );
  }
}

/// Why a picker is not done yet, as a text field says it.
class _FieldError extends StatelessWidget {
  const _FieldError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x2,
        AarastV3Space.x1,
        AarastV3Space.x2,
        0,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.alertCircle,
            size: 16,
            color: AarastV3Color.danger,
          ),
          const SizedBox(width: AarastV3Space.x1),
          Expanded(
            child: Text(
              text,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «نشاطك · وين · خدمتك · أرسل» (prototype `pSteps`): the current step is
/// filled, the ones behind it are soft.
class _JoinSteps extends StatelessWidget {
  const _JoinSteps({required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'الخطوة ${current + 1} من ${labels.length}: ${labels[current]}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AarastV3Space.x1),
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(AarastV3Radius.pill),
          border: Border.all(color: AarastV3Color.line),
        ),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: Container(
                  key: ValueKey('provider-apply-step-$index'),
                  padding: const EdgeInsets.symmetric(
                    vertical: AarastV3Space.x2,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == current
                        ? AarastV3Color.primary
                        : index < current
                        ? AarastV3Color.primarySoft
                        : null,
                    borderRadius: BorderRadius.circular(AarastV3Radius.pill),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[index],
                      maxLines: 1,
                      style: JourneyType.of(
                        JourneyType.caption,
                        weight: JourneyType.bold,
                        color: index == current
                            ? AarastV3Color.onPrimary
                            : index < current
                            ? AarastV3Color.primary
                            : AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
