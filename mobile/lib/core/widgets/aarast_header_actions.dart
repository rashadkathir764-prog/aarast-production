import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/aarast_design_tokens.dart';
import '../theme/app_theme.dart';
import 'aarast_pressable.dart';
import '../experience_v3/aarast_v3_foundations.dart';
import '../experience_v3/aarast_journey.dart';

/// Borderless header action with a full accessible touch target.
class AarastHeaderIconAction extends StatelessWidget {
  const AarastHeaderIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final visibleBadge = badgeCount.clamp(0, 99);
    final semanticLabel = badgeCount > 0
        ? '$label، $badgeCount غير مقروءة'
        : label;

    return AarastPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: SizedBox.square(
        dimension: AppTheme.minTapTarget,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, color: AppTheme.textPrimary, size: AppTheme.iconMd),
            if (badgeCount > 0)
              PositionedDirectional(
                top: 3,
                end: 1,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AarastV3Space.x1,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AarastSemanticTokens.danger,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(color: AppTheme.canvas, width: 2),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$visibleBadge',
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontSize: JourneyType.badge,
                      fontWeight: FontWeight.w900,
                      height: 1,
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

/// Account avatar used by primary headers.
///
/// The avatar URL is sourced from the authenticated user. If it is absent or
/// the image cannot be decoded, the first character of the user's name is
/// shown instead of a broken-image placeholder.
class AarastHeaderAvatarAction extends StatelessWidget {
  const AarastHeaderAvatarAction({
    required this.userName,
    required this.onTap,
    this.avatarUrl,
    this.label = 'الحساب والمزيد',
    super.key,
  });

  final String? userName;
  final String? avatarUrl;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = avatarUrl?.trim();
    return AarastPressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: SizedBox.square(
        dimension: AppTheme.minTapTarget,
        child: Center(
          child: AarastAccountAvatar(
            userName: userName,
            avatarUrl: imageUrl,
            size: 38,
          ),
        ),
      ),
    );
  }
}

/// One resilient account identity image shared by headers and profile surfaces.
class AarastAccountAvatar extends StatelessWidget {
  const AarastAccountAvatar({
    required this.userName,
    this.avatarUrl,
    this.size = 38,
    super.key,
  });

  final String? userName;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = avatarUrl?.trim();
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: imageUrl == null || imageUrl.isEmpty
            ? _AvatarFallback(userName: userName)
            : Image.network(
                imageUrl,
                key: const ValueKey('aarast-header-avatar-image'),
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (context, error, stackTrace) =>
                    _AvatarFallback(userName: userName),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final initial = _firstCharacter(userName);
    return ColoredBox(
      key: const ValueKey('aarast-header-avatar-fallback'),
      color: AppTheme.surfaceMuted,
      child: Center(
        child: initial == null
            ? const Icon(LucideIcons.user, color: AppTheme.focus, size: 20)
            : Text(
                initial,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.focus,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
      ),
    );
  }

  static String? _firstCharacter(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return String.fromCharCode(normalized.runes.first);
  }
}
