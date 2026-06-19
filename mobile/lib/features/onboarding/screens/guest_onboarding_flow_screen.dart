import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _hydrateDraft() async {
    final preferences = await SharedPreferences.getInstance();
    final provider = GuestOnboardingProvider(
      storage: GuestOnboardingStorage(preferences),
    );
    await provider.loadOrStartDraft();
    if (!mounted) return;
    setState(() {
      _provider = provider;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        selectedPriorities: draft.priorities,
        onChanged: provider.setPriorities,
        onContinue: () => _savePriorities(provider),
        onBack: () => _goTo(GuestOnboardingFlowStep.weddingDate),
      ),
      GuestOnboardingFlowStep.budget => BudgetSetupScreen(
        draft: draft,
        onSaveBudget: ({currency, estimatedBudget}) async {
          await provider.updateBudgetAndSave(
            currency: currency,
            estimatedBudget: estimatedBudget,
          );
          _goTo(GuestOnboardingFlowStep.categories);
        },
        onBack: () => _goTo(GuestOnboardingFlowStep.priorities),
      ),
      GuestOnboardingFlowStep.categories => SuggestedCategoriesScreen(
        selectedCategoryKeys: draft.selectedCategoryKeys,
        onChanged: provider.setCategories,
        onContinue: () => _saveCategories(provider),
        onBack: () => _goTo(GuestOnboardingFlowStep.budget),
      ),
      GuestOnboardingFlowStep.preview => GeneratedDashboardPreviewScreen(
        draft: draft,
        onBack: () => _goTo(GuestOnboardingFlowStep.categories),
      ),
    };
  }

  Future<void> _selectPath(GuestOnboardingPath path) async {
    final provider = _provider;
    if (provider == null) return;
    await provider.updatePathAndSave(path);
    _goTo(
      provider.shouldShowProviderPendingBranch
          ? GuestOnboardingFlowStep.providerPending
          : GuestOnboardingFlowStep.persona,
    );
  }

  Future<void> _continueFromPath(GuestOnboardingDraft draft) async {
    if (draft.selectedPath == GuestOnboardingPath.provider) {
      _goTo(GuestOnboardingFlowStep.providerPending);
      return;
    }
    if (draft.selectedPath == null) {
      await _selectPath(GuestOnboardingPath.weddingUser);
      return;
    }
    _goTo(GuestOnboardingFlowStep.persona);
  }

  Future<void> _savePersona(GuestOnboardingProvider provider) async {
    await provider.updatePersonaAndSave(
      provider.draft.persona ?? GuestPersona.groom,
    );
    _goTo(GuestOnboardingFlowStep.location);
  }

  Future<void> _saveWeddingDate(GuestOnboardingProvider provider) async {
    final draft = provider.draft;
    await provider.updateWeddingDateAndSave(
      draft.weddingDate,
      unknown: draft.weddingDateUnknown || draft.weddingDate == null,
    );
    _goTo(GuestOnboardingFlowStep.priorities);
  }

  Future<void> _savePriorities(GuestOnboardingProvider provider) async {
    final priorities = provider.draft.priorities.isEmpty
        ? PrioritiesScreen.defaultPriorities.take(3).toList(growable: false)
        : provider.draft.priorities;
    await provider.updatePrioritiesAndSave(priorities);
    _goTo(GuestOnboardingFlowStep.budget);
  }

  Future<void> _saveCategories(GuestOnboardingProvider provider) async {
    final categories = provider.draft.selectedCategoryKeys.isEmpty
        ? SuggestedCategoriesScreen.defaultCategories
              .take(4)
              .toList(growable: false)
        : provider.draft.selectedCategoryKeys;
    await provider.updateCategoriesAndSave(categories);
    _goTo(GuestOnboardingFlowStep.preview);
  }

  void _goTo(GuestOnboardingFlowStep step) {
    if (!mounted) return;
    setState(() {
      _step = step;
    });
  }
}
