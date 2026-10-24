part of 'aarast_dashboard_view.dart';

/// b14: the home's own shape while it loads (the header, the countdown, a
/// card and the three tiles), so nothing jumps when the plan arrives.
class AarastDashboardSkeleton extends StatelessWidget {
  const AarastDashboardSkeleton({required this.bottomPadding, super.key});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'نجهز خطتك',
      liveRegion: true,
      child: ColoredBox(
        color: AarastV3Color.canvas,
        child: ListView(
          key: const ValueKey('aarast-dashboard-skeleton'),
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SkeletonBlock(width: 150, height: 24),
                            SizedBox(height: 6),
                            _SkeletonBlock(width: 110, height: 12),
                          ],
                        ),
                      ),
                      _SkeletonBlock(width: 44, height: 44, round: true),
                      SizedBox(width: 8),
                      _SkeletonBlock(width: 44, height: 44, round: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _SkeletonBlock(height: 116, radius: 24),
                  const SizedBox(height: 12),
                  const JourneyBox(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        _SkeletonBlock(width: 44, height: 44),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SkeletonBlock(width: 90, height: 10),
                              SizedBox(height: 8),
                              _SkeletonBlock(height: 14),
                              SizedBox(height: 8),
                              _SkeletonBlock(width: 160, height: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(child: _SkeletonBlock(height: 104, radius: 20)),
                      SizedBox(width: 8),
                      Expanded(child: _SkeletonBlock(height: 104, radius: 20)),
                      SizedBox(width: 8),
                      Expanded(child: _SkeletonBlock(height: 104, radius: 20)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'نجهز خطتك…',
              textAlign: TextAlign.center,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// b15: what happened in plain words, one way forward, and nothing else.
class AarastDashboardState extends StatelessWidget {
  const AarastDashboardState({
    required this.bottomPadding,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.actionIcon = LucideIcons.refreshCw,
    this.danger = false,
    super.key,
  });

  final double bottomPadding;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AarastV3Color.danger : context.accent.primary;
    final soft = danger ? AarastV3Color.dangerSoft : context.accent.primarySoft;
    return ColoredBox(
      color: AarastV3Color.canvas,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, 72, 24, bottomPadding),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: soft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: 36),
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: JourneyType.of(
                        JourneyType.title,
                        weight: JourneyType.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: JourneyType.of(
                      JourneyType.body,
                      color: AarastV3Color.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  JourneyButton(
                    label: actionLabel,
                    icon: actionIcon,
                    background: accent,
                    onPressed: onAction,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    this.width,
    required this.height,
    this.radius = 12,
    this.round = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: AarastV3Color.line,
          shape: round ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: round ? null : BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
