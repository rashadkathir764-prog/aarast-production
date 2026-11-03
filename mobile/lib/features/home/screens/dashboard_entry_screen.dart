import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/local_database.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController, AccountContextEntryGate;
import '../../auth/auth_api.dart' show AuthController, AuthStatus;
import '../../finance/finance_api.dart' show FinanceApi;
import '../../onboarding/onboarding_api.dart'
    show
        GuestOnboardingStorage,
        LocalPlanMigrationScreen,
        LocalPlanMigrationService,
        LocalPlanSnapshot;
import '../../wedding_plans/wedding_plans_api.dart' show WeddingPlansApi;
import '../data/dashboard_summary_sources.dart';
import 'local_guest_dashboard_screen.dart';

class DashboardEntryScreen extends StatefulWidget {
  const DashboardEntryScreen({super.key});

  @override
  State<DashboardEntryScreen> createState() => _DashboardEntryScreenState();
}

/// D77 (J1-01): the phone plans opened on the phone this session after the
/// account could not take them, by their phone id. Only for the session:
/// the next start offers the move into the account again.
final _openedOnPhoneThisSession = <String>{};

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
          final resume = GoRouterState.of(
            context,
          ).uri.queryParameters['resume'];
          // A provider's sign-up goes on to the joining; a couple's plan on
          // this phone stays there untouched and is offered on the next
          // plain open (D75).
          final toProvider = resume?.startsWith('/provider/') == true;
          final pending = toProvider ? null : snapshot.data;
          final service = _migrationService;
          if (pending != null && service != null) {
            final phoneId = pending.draft.guestPlanId ?? '';
            return LocalPlanMigrationScreen(
              snapshot: pending,
              migrationService: service,
              autoSave: auth.accountJustCreated,
              // D77: a failure never locks the app; the plan opens on the
              // phone, and this session keeps opening it there.
              localPlan: _phonePlanHome,
              startLocally: _openedOnPhoneThisSession.contains(phoneId),
              onOpenedLocally: () => _openedOnPhoneThisSession.add(phoneId),
              onFinished: (planId) {
                _openedOnPhoneThisSession.remove(phoneId);
                if (!mounted) return;
                setState(() {
                  _migrationSnapshot = Future.value(null);
                });
                // The plan just saved opens; a discarded one (no id) leaves
                // the choice to the gate.
                final contexts = context.read<AccountContextController>();
                unawaited(
                  planId == null
                      ? contexts.refresh()
                      : contexts.refreshAndOpenPlan(planId),
                );
              },
            );
          }
          return AccountContextEntryGate(resumeLocation: resume);
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

  /// The phone plan's own home while signed in, its strip saving it into
  /// the account ([saveNow]).
  Widget _phonePlanHome(BuildContext context, VoidCallback saveNow) {
    return FutureBuilder<LocalGuestDashboardSummary?>(
      future: _guestSummary,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        if (summary == null) {
          return const AarastScaffold(child: AarastScreenLoading());
        }
        return LocalGuestDashboardScreen(
          summary: summary,
          summarySource: _guestSummarySource,
          onSaveToAccount: saveNow,
        );
      },
    );
  }

  LocalPlanMigrationService? _buildMigrationService() {
    final WeddingPlansApi weddingPlansApi;
    final FinanceApi financeApi;
    try {
      weddingPlansApi = context.read<WeddingPlansApi>();
      financeApi = context.read<FinanceApi>();
    } on ProviderNotFoundException {
      return null;
    }
    return LocalPlanMigrationService(
      guestStorage: context.read<GuestOnboardingStorage>(),
      weddingPlansApi: weddingPlansApi,
      financeApi: financeApi,
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
