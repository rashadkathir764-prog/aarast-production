import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'aarast_ui.dart';

class AarastAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AarastAppBar({
    this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
    this.onBack,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: AarastPageHeader(
          title: title,
          subtitle: subtitle,
          actions: actions,
          showBack: showBack,
          onBack: onBack,
        ),
      ),
    );
  }
}

class AarastSliverAppBar extends StatelessWidget {
  const AarastSliverAppBar({
    this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
    this.onBack,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
        child: AarastPageHeader(
          title: title,
          subtitle: subtitle,
          actions: actions,
          showBack: showBack,
          onBack: onBack,
        ),
      ),
    );
  }
}
