import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/local_database.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/providers/account_context_controller.dart';
import '../../account_contexts/widgets/account_context_entry_gate.dart';
import '../../auth/providers/auth_controller.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/data/local_plan_migration.dart';
import '../../onboarding/screens/local_plan_migration_screen.dart';
import '../../wedding_plans/data/wedding_plans_api.dart';
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
  Future<LocalPlanSnapshot?>? _migrationSnapshot;
  LocalPlanMigrationService? _migrationService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _guestSummarySource ??= LocalGuestDashboardSummarySource(
      context.read<GuestOnboardingStorage>(),
      database: _localDatabaseOrNull(),
    );
    _guestSummary ??= _guestSummarySource!.loadSummary();
    _migrationService ??= _buildMigrationService();
    _migrationSnapshot ??=
        _migrationService?.loadSnapshot() ?? Future.value(null);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.status == AuthStatus.checking) {
      return const AarastScaffold(child: AarastScreenLoading());
    }
    if (auth.status == AuthStatus.authenticated) {
      // A complete guest plan on this device must be offered for migration
      // BEFORE the shell loads — otherwise weeks of local planning are
      // silently stranded.
      return FutureBuilder<LocalPlanSnapshot?>(
        future: _migrationSnapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AarastScaffold(child: AarastScreenLoading());
          }
          final pending = snapshot.data;
          final service = _migrationService;
          if (pending != null && service != null) {
            return LocalPlanMigrationScreen(
              snapshot: pending,
              migrationService: service,
              onFinished: () {
                if (!mounted) return;
                setState(() {
                  _migrationSnapshot = Future.value(null);
                });
                unawaited(context.read<AccountContextController>().refresh());
              },
            );
          }
          return AccountContextEntryGate(
            resumeLocation: GoRouterState.of(
              context,
            ).uri.queryParameters['resume'],
          );
        },
      );
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

  LocalPlanMigrationService? _buildMigrationService() {
    final WeddingPlansApi weddingPlansApi;
    try {
      weddingPlansApi = context.read<WeddingPlansApi>();
    } on ProviderNotFoundException {
      return null;
    }
    return LocalPlanMigrationService(
      guestStorage: context.read<GuestOnboardingStorage>(),
      weddingPlansApi: weddingPlansApi,
      database: _localDatabaseOrNull(),
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
