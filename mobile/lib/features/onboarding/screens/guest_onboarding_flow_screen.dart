import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/models/onboarding_complete.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../data/guest_onboarding_storage.dart';
import '../models/guest_onboarding_draft.dart';
import '../providers/guest_onboarding_provider.dart';
import 'budget_setup_screen.dart';
import 'choose_path_screen.dart';
import 'generated_dashboard_preview_screen.dart';
import 'guest_welcome_screen.dart';
import 'location_setup_screen.dart';
import 'persona_screen.dart';
import 'priorities_screen.dart';
import 'provider_path_pending_screen.dart';
import 'suggested_categories_screen.dart';
import 'wedding_date_screen.dart';

enum GuestOnboardingFlowStep {
  welcome,
  choosePath,
  providerPending,
  persona,
  location,
  weddingDate,
  priorities,
  budget,
  categories,
  preview,
}

class GuestOnboardingFlowScreen extends StatefulWidget {
  const GuestOnboardingFlowScreen({super.key});

  @override
  State<GuestOnboardingFlowScreen> createState() =>
      _GuestOnboardingFlowScreenState();
}

class _GuestOnboardingFlowScreenState extends State<GuestOnboardingFlowScreen> {
  GuestOnboardingProvider? _provider;
  GuestOnboardingFlowStep _step = GuestOnboardingFlowStep.welcome;

  @override
  void initState() {
    super.initState();
    _hydrateDraft();
  }

  @override
  void dispose() {
    _provider?.removeListener(_handleDraftChanged);
    super.dispose();
  }

  Future<void> _hydrateDraft() async {
    final preferences = await SharedPreferences.getInstance();
    final provider = GuestOnboardingProvider(
      storage: GuestOnboardingStorage(preferences),
    );
    await provider.loadOrStartDraft();
    if (!mounted) return;
    provider.addListener(_handleDraftChanged);
    setState(() {
      _provider = provider;
    });
  }

  void _handleDraftChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) {
      return const AarastScaffold(child: AarastScreenLoading());
    }

    final draft = provider.draft;
    return switch (_step) {
      GuestOnboardingFlowStep.welcome => GuestWelcomeScreen(
        onContinue: () => _goTo(GuestOnboardingFlowStep.choosePath),
      ),
      GuestOnboardingFlowStep.choosePath => ChoosePathScreen(
        selectedPath: draft.selectedPath,
        onSelectPath: _selectPath,
        onContinue: () => _continueFromPath(draft),
        onBack: () => _goTo(GuestOnboardingFlowStep.welcome),
      ),
      GuestOnboardingFlowStep.providerPending => ProviderPathPendingScreen(
        onContinue: () => context.go(AppRouter.providerApply),
        onBack: () => _goTo(GuestOnboardingFlowStep.choosePath),
      ),
      GuestOnboardingFlowStep.persona => PersonaScreen(
        selectedPersona: draft.persona,
        onSelectPersona: provider.setPersona,
        onContinue: () => _savePersona(provider),
        onBack: () => _goTo(GuestOnboardingFlowStep.choosePath),
      ),
      GuestOnboardingFlowStep.location => LocationSetupScreen(
        draft: draft,
        onSaveLocation:
            ({
              governorate,
              city,
              district,
              neighborhood,
              street,
              addressNote,
            }) async {
              await provider.updateLocationAndSave(
                governorate: governorate,
                city: city,
                district: district,
                neighborhood: neighborhood,
                street: street,
                addressNote: addressNote,
              );
              _goTo(GuestOnboardingFlowStep.weddingDate);
            },
        onBack: () => _goTo(GuestOnboardingFlowStep.persona),
      ),
      GuestOnboardingFlowStep.weddingDate => WeddingDateScreen(
        draft: draft,
        onSelectDate: provider.setWeddingDate,
        onContinue: () => _saveWeddingDate(provider),
        onBack: () => _goTo(GuestOnboardingFlowStep.location),
      ),
      GuestOnboardingFlowStep.priorities => PrioritiesScreen(
        persona: draft.persona,
        selectedPriorities: draft.priorities,
        onChanged: provider.setPriorities,
        onContinue: () => _savePriorities(provider),
        onBack: () => _goTo(GuestOnboardingFlowStep.weddingDate),
      ),
      GuestOnboardingFlowStep.budget => BudgetSetupScreen(
        draft: draft,
        onSaveBudget: ({currency, estimatedBudget, skipped = false}) async {
          await provider.updateBudgetAndSave(
            currency: currency,
            estimatedBudget: estimatedBudget,
            skipped: skipped,
          );
          _goTo(GuestOnboardingFlowStep.categories);
        },
        onBack: () => _goTo(GuestOnboardingFlowStep.priorities),
      ),
      GuestOnboardingFlowStep.categories => SuggestedCategoriesScreen(
        persona: draft.persona,
        selectedCategoryKeys: draft.selectedCategoryKeys,
        onChanged: provider.setCategories,
        onContinue: () => _saveCategories(provider),
        onBack: () => _goTo(GuestOnboardingFlowStep.budget),
      ),
      GuestOnboardingFlowStep.preview => GeneratedDashboardPreviewScreen(
        draft: draft,
        onContinue: _completePlan,
        onBack: () => _goTo(GuestOnboardingFlowStep.categories),
      ),
    };
  }

  Future<void> _selectPath(GuestOnboardingPath path) async {
    final provider = _provider;
    if (provider == null) return;
    await provider.updatePathAndSave(path);
  }

  Future<void> _continueFromPath(GuestOnboardingDraft draft) async {
    if (draft.selectedPath == GuestOnboardingPath.provider) {
      _goTo(GuestOnboardingFlowStep.providerPending);
      return;
    }
    if (draft.selectedPath == null) {
      return;
    }
    _goTo(GuestOnboardingFlowStep.persona);
  }

  Future<void> _savePersona(GuestOnboardingProvider provider) async {
    final persona = provider.draft.persona;
    if (persona == null) return;
    await provider.updatePersonaAndSave(persona);
    _goTo(GuestOnboardingFlowStep.location);
  }

  Future<void> _saveWeddingDate(GuestOnboardingProvider provider) async {
    final draft = provider.draft;
    if (!draft.hasTimelineSeed) return;
    await provider.updateWeddingDateAndSave(
      draft.weddingDate,
      unknown: draft.weddingDateUnknown || draft.weddingDate == null,
    );
    _goTo(GuestOnboardingFlowStep.priorities);
  }

  Future<void> _savePriorities(GuestOnboardingProvider provider) async {
    if (provider.draft.priorities.isEmpty) return;
    await provider.updatePrioritiesAndSave(provider.draft.priorities);
    _goTo(GuestOnboardingFlowStep.budget);
  }

  Future<void> _saveCategories(GuestOnboardingProvider provider) async {
    if (provider.draft.selectedCategoryKeys.isEmpty) return;
    await provider.updateCategoriesAndSave(provider.draft.selectedCategoryKeys);
    _goTo(GuestOnboardingFlowStep.preview);
  }

  Future<void> _completePlan() async {
    final provider = _provider;
    if (provider == null) return;
    final draft = provider.draft;
    final authStorage = context.read<AuthStorage>();
    final guestStorage = context.read<GuestOnboardingStorage>();
    final weddingPlansProvider = context.read<WeddingPlansProvider>();
    final accessToken = await authStorage.readAccessToken();

    if (accessToken == null || accessToken.trim().isEmpty) {
      final now = DateTime.now();
      await guestStorage.saveDraft(
        draft.copyWith(
          guestPlanId: 'guest-plan-${now.microsecondsSinceEpoch}',
          createdAt: now,
          isGuestPlan: true,
          needsSync: true,
        ),
      );
      if (!mounted) return;
      context.go(AppRouter.home);
      return;
    }

    final location = draft.weddingLocation;
    final city = location.cityOrDistrict?.trim();
    final response = await weddingPlansProvider.completeOnboarding(
      OnboardingCompleteRequest(
        path: 'USER',
        persona: switch (draft.persona) {
          GuestPersona.bride => 'BRIDE',
          GuestPersona.helper => 'HELPER',
          _ => 'GROOM',
        },
        title: (location.shortLabel ?? '').isEmpty
            ? 'خطة زفافي'
            : 'خطة زفاف ${location.shortLabel}',
        city: (city ?? '').isEmpty ? null : city,
        location: location.toJson(),
        weddingDate: draft.weddingDate?.toIso8601String(),
        priorities: draft.priorities,
        estimatedBudget: draft.estimatedBudget,
        currency: draft.currency ?? 'YER',
        selectedCategories: draft.selectedCategoryKeys,
      ),
    );
    if (response == null || !mounted) return;
    await authStorage.saveActivePlanId(response.activePlanId);
    if (!mounted) return;
    context.go(AppRouter.home);
  }

  void _goTo(GuestOnboardingFlowStep step) {
    if (!mounted) return;
    setState(() {
      _step = step;
    });
  }
}
