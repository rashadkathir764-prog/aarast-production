import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/guest_onboarding_storage.dart';
import '../models/guest_onboarding_draft.dart';
import '../models/wedding_location_draft.dart';
import '../widgets/location_picker_section.dart';
import '../../wedding_plans/models/onboarding_complete.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';

class ActivePlanOnboardingScreen extends StatefulWidget {
  const ActivePlanOnboardingScreen({super.key});

  @override
  State<ActivePlanOnboardingScreen> createState() =>
      _ActivePlanOnboardingScreenState();
}

class _ActivePlanOnboardingScreenState
    extends State<ActivePlanOnboardingScreen> {
  final _governorateController = TextEditingController(text: 'صنعاء');
  final _cityController = TextEditingController(text: 'صنعاء');
  final _districtController = TextEditingController(text: 'السبعين');
  final _neighborhoodController = TextEditingController(text: 'حدة');
  final _streetController = TextEditingController();
  final _addressNoteController = TextEditingController();
  final _budgetController = TextEditingController(text: '120000');

  int _step = 0;
  String _path = 'USER';
  String _persona = 'GROOM';
  String _currency = 'SAR';
  DateTime _weddingDate = DateTime.now().add(const Duration(days: 180));
  final Set<String> _priorities = {'budget', 'tasks', 'providers'};
  final Set<String> _categories = {
    'القاعة',
    'المطعم / العشاء',
    'التصوير',
    'الكوشة',
    'الفستان',
    'الذهب',
  };

  static const _priorityOptions = [
    _ChoiceValue('budget', 'الميزانية والمصاريف', Icons.wallet_rounded),
    _ChoiceValue('debts', 'الديون والأقساط', Icons.credit_card_rounded),
    _ChoiceValue('tasks', 'المهام والمواعيد', Icons.checklist_rounded),
    _ChoiceValue('guests', 'الضيوف', Icons.groups_2_rounded),
    _ChoiceValue('providers', 'الموردون القريبون', Icons.storefront_rounded),
    _ChoiceValue('sharing', 'مشاركة الخطة', Icons.group_add_rounded),
  ];

  static const _categoryOptions = [
    _ChoiceValue('القاعة', 'القاعة', Icons.account_balance_rounded),
    _ChoiceValue(
      'المطعم / العشاء',
      'المطعم / العشاء',
      Icons.restaurant_rounded,
    ),
    _ChoiceValue('التصوير', 'التصوير', Icons.photo_camera_rounded),
    _ChoiceValue('الكوشة', 'الكوشة', Icons.chair_alt_rounded),
    _ChoiceValue('الفستان', 'الفستان', Icons.checkroom_rounded),
    _ChoiceValue('البدلة', 'البدلة', Icons.man_2_rounded),
    _ChoiceValue('الذهب', 'الذهب', Icons.diamond_rounded),
    _ChoiceValue('الحناء', 'الحناء', Icons.spa_rounded),
    _ChoiceValue('الدعوات', 'الدعوات', Icons.mail_rounded),
    _ChoiceValue('النقل', 'النقل', Icons.directions_car_rounded),
    _ChoiceValue('الضيافة', 'الضيافة', Icons.room_service_rounded),
    _ChoiceValue('الطوارئ', 'الطوارئ', Icons.emergency_rounded),
  ];

  @override
  void dispose() {
    _governorateController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _neighborhoodController.dispose();
    _streetController.dispose();
    _addressNoteController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeddingPlansProvider>();

    return AarastScreenFrame(
      maxWidth: 520,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _Header(step: _step),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: AppTheme.motionMedium,
                  child: _buildStep(context, provider),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, WeddingPlansProvider provider) {
    return switch (_step) {
      0 => _WelcomeStep(onContinue: _next),
      1 => _PathAndRoleStep(
        selectedPath: _path,
        selectedPersona: _persona,
        onPathChanged: (value) => setState(() => _path = value),
        onPersonaChanged: (value) => setState(() => _persona = value),
        onBack: _previous,
        onContinue: _next,
      ),
      2 => _LocationDateStep(
        governorateController: _governorateController,
        cityController: _cityController,
        districtController: _districtController,
        streetController: _streetController,
        addressNoteController: _addressNoteController,
        weddingDate: _weddingDate,
        onLocationChanged: () => setState(() {}),
        onDateChanged: (date) => setState(() => _weddingDate = date),
        onBack: _previous,
        onContinue: _next,
      ),
      _ => _BudgetCategoriesStep(
        budgetController: _budgetController,
        currency: _currency,
        priorities: _priorities,
        categories: _categories,
        priorityOptions: _priorityOptions,
        categoryOptions: _categoryOptions,
        isSubmitting: provider.isSubmitting,
        errorMessage: provider.errorMessage,
        onCurrencyChanged: (value) => setState(() => _currency = value),
        onTogglePriority: (value) => _toggle(_priorities, value),
        onToggleCategory: (value) => _toggle(_categories, value),
        onBack: _previous,
        onSubmit: _submit,
      ),
    };
  }

  void _next() {
    if (_path == 'PROVIDER' && _step == 1) {
      context.go(AppRouter.providerApply);
      return;
    }
    setState(() => _step = (_step + 1).clamp(0, 3));
  }

  void _previous() {
    setState(() => _step = (_step - 1).clamp(0, 3));
  }

  void _toggle(Set<String> values, String value) {
    setState(() {
      if (values.contains(value)) {
        values.remove(value);
      } else {
        values.add(value);
      }
    });
  }

  Future<void> _submit() async {
    if (_path != 'USER') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أنشئ الخطة من مسار تنظيم الزفاف فقط.')),
      );
      return;
    }

    final locationDraft = WeddingLocationDraft.fromLegacyFields(
      governorate: _governorateController.text,
      city: _cityController.text,
      district: _districtController.text,
      neighborhood: _neighborhoodController.text,
      street: _streetController.text,
      addressNote: _addressNoteController.text,
    );
    if (!locationDraft.hasRequiredLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد المحافظة والمدينة أو المديرية.')),
      );
      return;
    }
    final city = locationDraft.cityOrDistrict ?? _cityController.text.trim();
    final location = locationDraft.toJson();
    final priorities = _priorities.toList(growable: false);
    final categories = _categories.toList(growable: false);
    final authStorage = context.read<AuthStorage>();
    final guestStorage = context.read<GuestOnboardingStorage>();
    final weddingPlansProvider = context.read<WeddingPlansProvider>();
    final accessToken = await authStorage.readAccessToken();

    if (accessToken == null || accessToken.trim().isEmpty) {
      final now = DateTime.now();
      final planTitle = locationDraft.shortLabel == null
          ? 'خطة زفافي'
          : 'خطة زفاف ${locationDraft.shortLabel}';
      final guestPlan = GuestOnboardingDraft(
        guestPlanId: 'guest-plan-${now.microsecondsSinceEpoch}',
        planName: planTitle,
        createdAt: now,
        isGuestPlan: true,
        needsSync: true,
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: switch (_persona) {
          'BRIDE' => GuestPersona.bride,
          'HELPER' => GuestPersona.helper,
          _ => GuestPersona.groom,
        },
        governorate: location['governorate'],
        city: city.isEmpty ? null : city,
        district: location['district'],
        neighborhood: location['neighborhood'],
        street: location['street'],
        addressNote: location['addressNote'],
        weddingDate: _weddingDate,
        weddingDateUnknown: false,
        priorities: priorities,
        currency: _currency,
        estimatedBudget: _budgetController.text.trim(),
        selectedCategoryKeys: categories,
      );
      await guestStorage.saveDraft(guestPlan);
      if (!mounted) return;
      context.go(AppRouter.home);
      return;
    }

    final response = await weddingPlansProvider.completeOnboarding(
      OnboardingCompleteRequest(
        path: 'USER',
        persona: _persona,
        title: locationDraft.shortLabel == null
            ? 'خطة زفافي'
            : 'خطة زفاف ${locationDraft.shortLabel}',
        city: city.isEmpty ? null : city,
        location: location,
        weddingDate: _weddingDate.toIso8601String(),
        priorities: priorities,
        estimatedBudget: _budgetController.text.trim(),
        currency: _currency,
        selectedCategories: categories,
      ),
    );

    if (response != null && mounted) {
      await authStorage.saveActivePlanId(response.activePlanId);
      if (!mounted) return;
      context.go(AppRouter.home);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.goldGradient,
          ),
          child: const Icon(Icons.favorite_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'أعرست',
                style: TextStyle(
                  color: AppTheme.burgundyDeep,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                minHeight: 7,
                value: (step + 1) / 4,
                borderRadius: BorderRadius.circular(20),
                backgroundColor: AppTheme.border,
                valueColor: const AlwaysStoppedAnimation(AppTheme.burgundy),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      key: const ValueKey('welcome'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: AppTheme.heroDecoration(),
            child: const Column(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  color: AppTheme.gold2,
                  size: 48,
                ),
                SizedBox(height: 18),
                Text(
                  'ألف مبروك!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'رحلتك نحو يوم زفافك المثالي تبدأ من هنا. نرتب معك الخطة خطوة بخطوة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _PrimaryButton(
            key: const Key('active-onboarding-primary-action'),
            label: 'ابدأ الآن',
            icon: Icons.arrow_back_rounded,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class _PathAndRoleStep extends StatelessWidget {
  const _PathAndRoleStep({
    required this.selectedPath,
    required this.selectedPersona,
    required this.onPathChanged,
    required this.onPersonaChanged,
    required this.onBack,
    required this.onContinue,
  });

  final String selectedPath;
  final String selectedPersona;
  final ValueChanged<String> onPathChanged;
  final ValueChanged<String> onPersonaChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      key: const ValueKey('path-role'),
      title: 'اختر ما يناسبك',
      subtitle: 'نخصص التجربة حسب مسارك ودورك في الخطة.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceCard(
            title: 'أريد تنظيم زفافي',
            subtitle: 'خطة، ميزانية، مهام وموردون في مكان واحد',
            icon: Icons.favorite_border_rounded,
            selected: selectedPath == 'USER',
            onTap: () => onPathChanged('USER'),
          ),
          const SizedBox(height: 10),
          _ChoiceCard(
            title: 'أنا مزود خدمة',
            subtitle: 'قدّم طلب الانضمام وأدر خدماتك بعد المراجعة',
            icon: Icons.storefront_rounded,
            selected: selectedPath == 'PROVIDER',
            onTap: () => onPathChanged('PROVIDER'),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('اختر دورك'),
          const SizedBox(height: 10),
          _ChoiceCard(
            title: 'العريس',
            subtitle: 'أنا العريس',
            icon: Icons.person_rounded,
            selected: selectedPersona == 'GROOM',
            onTap: () => onPersonaChanged('GROOM'),
          ),
          const SizedBox(height: 10),
          _ChoiceCard(
            title: 'العروسة',
            subtitle: 'أنا العروسة',
            icon: Icons.person_2_rounded,
            selected: selectedPersona == 'BRIDE',
            onTap: () => onPersonaChanged('BRIDE'),
          ),
          const SizedBox(height: 10),
          _ChoiceCard(
            title: 'مساعد / مساهم',
            subtitle: 'أساعد في التخطيط أو المساهمة',
            icon: Icons.groups_rounded,
            selected: selectedPersona == 'HELPER',
            onTap: () => onPersonaChanged('HELPER'),
          ),
          const SizedBox(height: 18),
          _FooterActions(onBack: onBack, onContinue: onContinue),
        ],
      ),
    );
  }
}

class _LocationDateStep extends StatelessWidget {
  const _LocationDateStep({
    required this.governorateController,
    required this.cityController,
    required this.districtController,
    required this.streetController,
    required this.addressNoteController,
    required this.weddingDate,
    required this.onLocationChanged,
    required this.onDateChanged,
    required this.onBack,
    required this.onContinue,
  });

  final TextEditingController governorateController;
  final TextEditingController cityController;
  final TextEditingController districtController;
  final TextEditingController streetController;
  final TextEditingController addressNoteController;
  final DateTime weddingDate;
  final VoidCallback onLocationChanged;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      key: const ValueKey('location-date'),
      title: 'أين ومتى سيكون زفافك؟',
      subtitle: 'الموقع والتاريخ يساعدان في بناء خطة واقعية.',
      child: Column(
        children: [
          LocationPickerSection(
            governorateController: governorateController,
            cityOrDistrictController: cityController,
            areaOrNeighborhoodController: districtController,
            streetController: streetController,
            detailedAddressController: addressNoteController,
            onChanged: onLocationChanged,
          ),
          const SizedBox(height: 16),
          _DatePanel(date: weddingDate, onDateChanged: onDateChanged),
          const SizedBox(height: 18),
          _FooterActions(onBack: onBack, onContinue: onContinue),
        ],
      ),
    );
  }
}

class _BudgetCategoriesStep extends StatelessWidget {
  const _BudgetCategoriesStep({
    required this.budgetController,
    required this.currency,
    required this.priorities,
    required this.categories,
    required this.priorityOptions,
    required this.categoryOptions,
    required this.isSubmitting,
    required this.onCurrencyChanged,
    required this.onTogglePriority,
    required this.onToggleCategory,
    required this.onBack,
    required this.onSubmit,
    this.errorMessage,
  });

  final TextEditingController budgetController;
  final String currency;
  final Set<String> priorities;
  final Set<String> categories;
  final List<_ChoiceValue> priorityOptions;
  final List<_ChoiceValue> categoryOptions;
  final bool isSubmitting;
  final String? errorMessage;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<String> onTogglePriority;
  final ValueChanged<String> onToggleCategory;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      key: const ValueKey('budget-categories'),
      title: 'جهز خطتك الأولى',
      subtitle: 'حدد الأولويات والميزانية والفئات المقترحة.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('الأولويات'),
          const SizedBox(height: 10),
          _ChipGrid(
            options: priorityOptions,
            selectedValues: priorities,
            onToggle: onTogglePriority,
          ),
          const SizedBox(height: 18),
          const _SectionTitle('الميزانية'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: currency,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'العملة'),
            items: const [
              DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي')),
              DropdownMenuItem(value: 'YER', child: Text('ريال يمني')),
            ],
            onChanged: (value) {
              if (value != null) onCurrencyChanged(value);
            },
          ),
          const SizedBox(height: 10),
          _Input(
            controller: budgetController,
            label: 'الميزانية التقديرية',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),
          const _SectionTitle('الفئات المقترحة'),
          const SizedBox(height: 10),
          _ChipGrid(
            options: categoryOptions,
            selectedValues: categories,
            onToggle: onToggleCategory,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            _InlineError(message: errorMessage!),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSubmitting ? null : onBack,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('رجوع'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _PrimaryButton(
                  key: const Key('active-onboarding-create-plan'),
                  label: 'أنشئ خطتي',
                  icon: Icons.auto_awesome_rounded,
                  isLoading: isSubmitting,
                  onPressed: onSubmit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatePanel extends StatelessWidget {
  const _DatePanel({required this.date, required this.onDateChanged});

  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final label = formatArabicCompactDate(date);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.premiumCardDecoration(radius: AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('موعد الزفاف'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 900)),
              );
              if (picked != null) onDateChanged(picked);
            },
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(label),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickDateChip(
                label: 'بعد 3 أشهر',
                onTap: () =>
                    onDateChanged(DateTime.now().add(const Duration(days: 90))),
              ),
              _QuickDateChip(
                label: 'بعد 6 أشهر',
                onTap: () => onDateChanged(
                  DateTime.now().add(const Duration(days: 180)),
                ),
              ),
              _QuickDateChip(
                label: 'بعد سنة',
                onTap: () => onDateChanged(
                  DateTime.now().add(const Duration(days: 365)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.child, this.title, this.subtitle, super.key});

  final Widget child;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.premiumCardDecoration(radius: AppTheme.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 18),
          ],
          child,
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AnimatedContainer(
        duration: AppTheme.motionFast,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.burgundySoft : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.burgundy : AppTheme.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected ? AppTheme.burgundy : AppTheme.ivory,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: selected ? Colors.white : AppTheme.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.chevron_left_rounded,
              color: selected ? AppTheme.burgundy : AppTheme.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipGrid extends StatelessWidget {
  const _ChipGrid({
    required this.options,
    required this.selectedValues,
    required this.onToggle,
  });

  final List<_ChoiceValue> options;
  final Set<String> selectedValues;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          FilterChip(
            selected: selectedValues.contains(option.value),
            avatar: Icon(option.icon, size: 18),
            label: Text(option.label),
            onSelected: (_) => onToggle(option.value),
          ),
      ],
    );
  }
}

class _ChoiceValue {
  const _ChoiceValue(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.burgundyDeep,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({required this.onBack, required this.onContinue});

  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('رجوع'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _PrimaryButton(
            key: const Key('active-onboarding-primary-action'),
            label: 'متابعة',
            icon: Icons.arrow_back_rounded,
            onPressed: onContinue,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.burgundySoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.burgundy.withValues(alpha: 0.25)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.burgundyDeep,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
