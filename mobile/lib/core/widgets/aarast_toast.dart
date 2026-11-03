import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../experience_v3/aarast_v3_foundations.dart';
import '../experience_v3/aarast_journey.dart';

/// Compact, app-wide transient feedback shown at the top of the active screen.
///
/// The root overlay keeps a receipt visible when a successful form immediately
/// pops its route. Only one receipt is mounted at a time, so rapid operations
/// replace stale feedback instead of stacking banners over the page.
class AarastToast {
  static OverlayEntry? _activeEntry;

  static void showSuccess(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    bool haptic = true,
  }) {
    if (haptic) unawaited(HapticFeedback.lightImpact());
    _show(
      context,
      message: message,
      foreground: AppTheme.success,
      softColor: AppTheme.successSoft,
      icon: LucideIcons.check,
      action: action,
      duration: const Duration(milliseconds: 2700),
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      foreground: AppTheme.danger,
      softColor: AppTheme.dangerSoft,
      icon: LucideIcons.alertCircle,
      action: action,
      duration: const Duration(milliseconds: 4200),
    );
  }

  /// A caller above the navigator passes the navigator's [overlay].
  static void showInfo(
    BuildContext context,
    String message, {
    SnackBarAction? action,
    OverlayState? overlay,
  }) {
    _show(
      context,
      message: message,
      foreground: AppTheme.focus,
      softColor: AppTheme.infoSoft,
      icon: LucideIcons.info,
      action: action,
      duration: const Duration(milliseconds: 3200),
      overlay: overlay,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    _show(
      context,
      message: message,
      foreground: AppTheme.warning,
      softColor: AppTheme.warningSoft,
      icon: LucideIcons.alertTriangle,
      action: action,
      duration: const Duration(milliseconds: 3600),
    );
  }

  /// A push notice while the app is open. A caller that lives above the
  /// navigator (no overlay above it) passes the navigator's [overlay].
  static void showNotification(
    BuildContext context, {
    required String title,
    required String message,
    OverlayState? overlay,
  }) {
    _show(
      context,
      title: title,
      message: message,
      foreground: AppTheme.brand,
      softColor: AppTheme.brandMuted,
      icon: LucideIcons.bell,
      duration: const Duration(milliseconds: 4200),
      overlay: overlay,
    );
  }

  static void _show(
    BuildContext context, {
    String? title,
    required String message,
    required Color foreground,
    required Color softColor,
    required IconData icon,
    SnackBarAction? action,
    required Duration duration,
    OverlayState? overlay,
  }) {
    overlay ??= Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _removeActive();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AarastToastOverlay(
        title: title,
        message: message,
        foreground: foreground,
        softColor: softColor,
        icon: icon,
        action: action,
        duration: action == null
            ? duration
            : const Duration(milliseconds: 5200),
        onDismissed: () {
          if (!identical(_activeEntry, entry)) return;
          _activeEntry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }

  static void _removeActive() {
    final entry = _activeEntry;
    _activeEntry = null;
    if (entry?.mounted == true) entry!.remove();
  }
}

class _AarastToastOverlay extends StatefulWidget {
  const _AarastToastOverlay({
    required this.message,
    required this.foreground,
    required this.softColor,
    required this.icon,
    required this.duration,
    required this.onDismissed,
    this.title,
    this.action,
  });

  final String? title;
  final String message;
  final Color foreground;
  final Color softColor;
  final IconData icon;
  final SnackBarAction? action;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AarastToastOverlay> createState() => _AarastToastOverlayState();
}

class _AarastToastOverlayState extends State<_AarastToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppTheme.motionCurve,
      reverseCurve: AppTheme.motionExitCurve,
    );
    _opacity = curved;
    _position = Tween<Offset>(
      begin: const Offset(0, -0.28),
      end: Offset.zero,
    ).animate(curved);
    unawaited(_controller.forward());
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  void _runAction() {
    final action = widget.action;
    if (action == null) return;
    unawaited(_dismiss());
    action.onPressed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title?.trim();
    final semanticsLabel = title == null || title.isEmpty
        ? widget.message
        : '$title. ${widget.message}';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.only(top: AarastV3Space.x2),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SlideTransition(
                position: _position,
                child: FadeTransition(
                  opacity: _opacity,
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: semanticsLabel,
                    child: ExcludeSemantics(
                      child: _ToastCard(
                        title: title,
                        message: widget.message,
                        foreground: widget.foreground,
                        softColor: widget.softColor,
                        icon: widget.icon,
                        action: widget.action,
                        onAction: _runAction,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.title,
    required this.message,
    required this.foreground,
    required this.softColor,
    required this.icon,
    required this.action,
    required this.onAction,
  });

  final String? title;
  final String message;
  final Color foreground;
  final Color softColor;
  final IconData icon;
  final SnackBarAction? action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const Key('aarast-top-toast'),
      child: Material(
        color: AppTheme.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AarastV3Radius.card),
          side: const BorderSide(color: AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final stackAction =
                action != null &&
                (constraints.maxWidth < 330 || textScale > 1.3);
            final actionButton = action == null
                ? null
                : TextButton(
                    key: const Key('aarast-toast-action'),
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: foreground,
                      backgroundColor: softColor,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AarastV3Space.x3,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      action!.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: JourneyType.label,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );

            return Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AarastV3Space.x2,
                AarastV3Space.x2,
                AarastV3Space.x3,
                AarastV3Space.x2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: softColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 17, color: foreground),
                  ),
                  const SizedBox(width: AarastV3Space.x2),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null && title!.isNotEmpty) ...[
                          Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: AarastV3Space.half),
                        ],
                        Text(
                          message,
                          maxLines: title == null ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: title == null
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                height: 1.35,
                              ),
                        ),
                        if (stackAction && actionButton != null) ...[
                          const SizedBox(height: AarastV3Space.x1),
                          actionButton,
                        ],
                      ],
                    ),
                  ),
                  if (!stackAction && actionButton != null) ...[
                    const SizedBox(width: AarastV3Space.x2),
                    actionButton,
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
