part of 'aarast_dashboard_view.dart';

class AarastDashboardSkeleton extends StatelessWidget {
  const AarastDashboardSkeleton({required this.bottomPadding, super.key});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.canvas,
      child: ListView(
        key: const ValueKey('aarast-dashboard-skeleton'),
        padding: EdgeInsets.fromLTRB(
          AppTheme.space16,
          AppTheme.space20,
          AppTheme.space16,
          bottomPadding,
        ),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _SkeletonLine(width: 210, height: 24),
          SizedBox(height: AppTheme.space8),
          _SkeletonLine(width: 150, height: 14),
          SizedBox(height: AppTheme.space20),
          _SkeletonLine(height: 210),
          SizedBox(height: AppTheme.space16),
          _SkeletonLine(height: 108),
          SizedBox(height: AppTheme.space24),
          _SkeletonLine(width: 130, height: 18),
          SizedBox(height: AppTheme.space12),
          _SkeletonLine(height: 220),
        ],
      ),
    );
  }
}

class AarastDashboardState extends StatelessWidget {
  const AarastDashboardState({
    required this.bottomPadding,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.danger = false,
    super.key,
  });

  final double bottomPadding;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AarastSemanticTokens.danger : AppTheme.brand;
    final muted = danger
        ? AarastSemanticTokens.dangerMuted
        : AppTheme.brandMuted;
    return ColoredBox(
      color: AppTheme.canvas,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppTheme.space20,
          AppTheme.space32,
          AppTheme.space20,
          bottomPadding,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AarastSurface(
                borderColor: AarastSemanticTokens.border,
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: muted,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSurface,
                        ),
                      ),
                      child: Icon(icon, color: accent, size: 26),
                    ),
                    const SizedBox(height: AppTheme.space16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space20),
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(LucideIcons.refreshCw),
                      label: Text(actionLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: AppTheme.surfaceRaised,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusControl,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTheme.radiusSurface),
        ),
      ),
    );
  }
}
