import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/local_database.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../shell/main_shell.dart';
import '../data/dashboard_summary_sources.dart';
import 'local_guest_dashboard_screen.dart';

class DashboardEntryScreen extends StatefulWidget {
  const DashboardEntryScreen({super.key});

  @override
  State<DashboardEntryScreen> createState() => _DashboardEntryScreenState();
}

class _DashboardEntryScreenState extends State<DashboardEntryScreen> {
  Future<LocalGuestDashboardSummary?>? _guestSummary;
  LocalGuestDashboardSummarySource? _guestSummarySource;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _guestSummarySource ??= LocalGuestDashboardSummarySource(
      context.read<GuestOnboardingStorage>(),
      database: _localDatabaseOrNull(),
    );
    _guestSummary ??= _guestSummarySource!.loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.status == AuthStatus.checking) {
      return const AarastScaffold(child: AarastScreenLoading());
    }
    if (auth.status == AuthStatus.authenticated) {
      return const MainShell();
    }

    return FutureBuilder<LocalGuestDashboardSummary?>(
      future: _guestSummary,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AarastScaffold(child: AarastScreenLoading());
        }
        final summary = snapshot.data;
        if (summary != null) {
          return LocalGuestDashboardScreen(
            summary: summary,
            summarySource: _guestSummarySource,
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(AppRouter.onboarding);
        });
        return const AarastScaffold(child: AarastScreenLoading());
      },
    );
  }

  LocalDatabase? _localDatabaseOrNull() {
    try {
      return context.read<LocalDatabase>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
