import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../onboarding/widgets/location_picker_section.dart';

/// The single presentation contract for every wedding-plan creation route.
///
/// Business logic, persistence and navigation stay with the owning screen;
/// this widget only guarantees that the first-plan and additional-plan forms
/// cannot drift into two different experiences again.
class WeddingPlanCreationScope extends StatelessWidget {
  const WeddingPlanCreationScope({
    required this.formKey,
    required this.child,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Form(key: formKey, child: child);
  }
}

class WeddingPlanCreationFields extends StatelessWidget {
  const WeddingPlanCreationFields({
    required this.titleController,
    required this.governorateController,
    required this.cityOrDistrictController,
    required this.areaOrNeighborhoodController,
    required this.neighborhoodController,
    required this.streetController,
    required this.detailedAddressController,
    required this.budgetController,
    required this.currency,
    required this.weddingDate,
    required this.showOptionalAddress,
    required this.onSelectDate,
    required this.onCurrencyChanged,
    required this.onToggleOptionalAddress,
    this.onChanged,
    this.draftStatus,
    this.errorMessage,
    super.key,
  });

  final TextEditingController titleController;
  final TextEditingController governorateController;
  final TextEditingController cityOrDistrictController;
  final TextEditingController areaOrNeighborhoodController;
  final TextEditingController neighborhoodController;
  final TextEditingController streetController;
  final TextEditingController detailedAddressController;
  final TextEditingController budgetController;
  final String currency;
  final DateTime? weddingDate;
  final bool showOptionalAddress;
  final VoidCallback onSelectDate;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onToggleOptionalAddress;
  final VoidCallback? onChanged;
  final Widget? draftStatus;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return AarastV3FormSurface(
      children: [
        const AarastV3FocusPrompt(
          eyebrow: 'الأساس',
          question: 'ما الخطة التي سنرتّبها؟',
          supportingText: 'سمّها وحدد موقعها وتاريخها، والباقي لاحقًا.',
          icon: LucideIcons.calendarHeart,
        ),
        ?draftStatus,
        TextFormField(
          key: const ValueKey('wedding-plan-title-field'),
          controller: titleController,
          textAlign: TextAlign.right,
          textInputAction: TextInputAction.next,
          onChanged: (_) => onChanged?.call(),
          decoration: _compactDecoration(
            label: 'عنوان الخطة',
            hint: 'مثال: عرسنا',
            icon: LucideIcons.list,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'عنوان الخطة مطلوب';
            }
            return null;
          },
        ),
        LocationPickerSection(
          key: const ValueKey('wedding-plan-location-section'),
          governorateController: governorateController,
          cityOrDistrictController: cityOrDistrictController,
          areaOrNeighborhoodController: areaOrNeighborhoodController,
          neighborhoodController: neighborhoodController,
          streetController: streetController,
          detailedAddressController: detailedAddressController,
          onChanged: onChanged,
          showOptionalDetails: showOptionalAddress,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onToggleOptionalAddress,
            icon: Icon(
              showOptionalAddress
                  ? LucideIcons.chevronUp
                  : LucideIcons.chevronDown,
              size: 17,
            ),
            label: Text(
              showOptionalAddress
                  ? 'إخفاء تفاصيل العنوان'
                  : 'تفاصيل عنوان إضافية',
            ),
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
        _PlanDecisionField(
          key: const ValueKey('wedding-plan-date-field'),
          label: 'تاريخ الزفاف',
          value: weddingDate == null
              ? 'اختر التاريخ'
              : formatArabicCompactDate(weddingDate!),
          icon: LucideIcons.calendarDays,
          selected: weddingDate != null,
          onTap: onSelectDate,
        ),
        AarastV3Disclosure(
          title: 'ميزانية أولية',
          subtitle: 'يمكن تخطيها وتعديلها لاحقًا',
          icon: LucideIcons.wallet,
          initiallyExpanded: budgetController.text.trim().isNotEmpty,
          child: _PlanBudgetFields(
            controller: budgetController,
            currency: currency,
            onCurrencyChanged: onCurrencyChanged,
            onChanged: onChanged,
          ),
        ),
        if (errorMessage case final message?)
          _PlanCreationError(message: message),
      ],
    );
  }
}

class _PlanDecisionField extends StatelessWidget {
  const _PlanDecisionField({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label، $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 10, 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(
              color: selected ? AppTheme.brand : AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? AppTheme.brand : AppTheme.focus,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronDown,
                size: 17,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanBudgetFields extends StatelessWidget {
  const _PlanBudgetFields({
    required this.controller,
    required this.currency,
    required this.onCurrencyChanged,
    this.onChanged,
  });

  final TextEditingController controller;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackFields = constraints.maxWidth < 300 || textScale > 1.35;
        final budget = TextFormField(
          key: const ValueKey('wedding-plan-budget-field'),
          controller: controller,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩,\.]')),
          ],
          onChanged: (_) => onChanged?.call(),
          decoration: _compactDecoration(
            label: 'المبلغ التقديري',
            hint: 'مثال: 2,500,000',
            icon: LucideIcons.wallet,
          ),
        );
        final currencyField = DropdownButtonFormField<String>(
          key: const ValueKey('wedding-plan-currency-field'),
          initialValue: _supportedCurrencies.contains(currency)
              ? currency
              : 'YER',
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'YER', child: Text('ر.ي')),
            DropdownMenuItem(value: 'SAR', child: Text('ر.س')),
            DropdownMenuItem(value: 'USD', child: Text(r'$')),
          ],
          onChanged: (value) {
            if (value == null) return;
            onCurrencyChanged(value);
            onChanged?.call();
          },
          decoration: _compactDecoration(label: 'العملة'),
        );

        if (stackFields) {
          return Column(
            children: [budget, const SizedBox(height: 10), currencyField],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: budget),
            const SizedBox(width: 10),
            SizedBox(width: 90, child: currencyField),
          ],
        );
      },
    );
  }
}

class _PlanCreationError extends StatelessWidget {
  const _PlanCreationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.dangerSoft,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.danger.withValues(alpha: .24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.info, color: AppTheme.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _compactDecoration({
  required String label,
  String? hint,
  IconData? icon,
}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusControl)),
    borderSide: BorderSide(color: AppTheme.border),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: AppTheme.surfaceRaised,
    constraints: const BoxConstraints(minHeight: 48),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 19, color: AppTheme.focus),
    prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
    border: border,
    enabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusControl)),
      borderSide: BorderSide(color: AppTheme.brand, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusControl)),
      borderSide: BorderSide(color: AppTheme.danger),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusControl)),
      borderSide: BorderSide(color: AppTheme.danger, width: 1.5),
    ),
  );
}

const _supportedCurrencies = {'YER', 'SAR', 'USD'};
