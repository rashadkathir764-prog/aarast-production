import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../models/yemen_location_suggestions.dart';

class LocationPickerSection extends StatelessWidget {
  const LocationPickerSection({
    required this.governorateController,
    required this.cityOrDistrictController,
    required this.areaOrNeighborhoodController,
    required this.streetController,
    required this.detailedAddressController,
    this.onChanged,
    this.showRequiredHint = true,
    this.showOptionalDetails = true,
    super.key,
  });

  final TextEditingController governorateController;
  final TextEditingController cityOrDistrictController;
  final TextEditingController areaOrNeighborhoodController;
  final TextEditingController streetController;
  final TextEditingController detailedAddressController;
  final VoidCallback? onChanged;
  final bool showRequiredHint;
  final bool showOptionalDetails;

  @override
  Widget build(BuildContext context) {
    final governorate = governorateController.text.trim();
    final cityOrDistrict = cityOrDistrictController.text.trim();
    final citySuggestions = YemenLocationSuggestions.cityOrDistrictsFor(
      governorate,
    );
    final areaSuggestions = YemenLocationSuggestions.areasFor(
      governorate: governorate,
      cityOrDistrict: cityOrDistrict,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showRequiredHint) ...[
          const _LocationGuidanceCard(),
          const SizedBox(height: 12),
        ],
        _LocationField(
          controller: governorateController,
          label: 'حدد المحافظة',
          hintText: 'مثال: صنعاء',
          icon: LucideIcons.map,
          requiredField: true,
          onChanged: (_) => onChanged?.call(),
        ),
        const SizedBox(height: 10),
        _SuggestionWrap(
          suggestions: YemenLocationSuggestions.governorates,
          selectedValue: governorate,
          onSelected: (value) {
            governorateController.text = value;
            cityOrDistrictController.clear();
            areaOrNeighborhoodController.clear();
            onChanged?.call();
          },
        ),
        const SizedBox(height: 12),
        _LocationField(
          controller: cityOrDistrictController,
          label: 'اختر المدينة أو المديرية',
          hintText: governorate.isEmpty ? 'اختر المحافظة أولاً' : 'مثال: شميلة',
          icon: LucideIcons.mapPin,
          requiredField: true,
          onChanged: (_) => onChanged?.call(),
        ),
        if (citySuggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SuggestionWrap(
            suggestions: citySuggestions,
            selectedValue: cityOrDistrict,
            onSelected: (value) {
              cityOrDistrictController.text = value;
              areaOrNeighborhoodController.clear();
              onChanged?.call();
            },
          ),
        ],
        if (showOptionalDetails) ...[
          const SizedBox(height: 12),
          _LocationField(
            controller: areaOrNeighborhoodController,
            label: 'اكتب الحي أو المنطقة',
            hintText: 'مثال: حي الأنصار',
            icon: LucideIcons.building2,
            onChanged: (_) => onChanged?.call(),
          ),
          if (areaSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SuggestionWrap(
              suggestions: areaSuggestions,
              selectedValue: areaOrNeighborhoodController.text.trim(),
              onSelected: (value) {
                areaOrNeighborhoodController.text = value;
                onChanged?.call();
              },
            ),
          ],
          const SizedBox(height: 10),
          _LocationField(
            controller: streetController,
            label: 'أضف الشارع أو أقرب معلم',
            hintText: 'مثال: شارع تعز',
            icon: LucideIcons.navigation,
            onChanged: (_) => onChanged?.call(),
          ),
          const SizedBox(height: 12),
          _LocationField(
            controller: detailedAddressController,
            label: 'العنوان التفصيلي أو المعلم القريب',
            hintText: 'مثال: بجوار القاعة الكبرى',
            icon: LucideIcons.fileText,
            maxLines: 2,
            onChanged: (_) => onChanged?.call(),
          ),
        ],
      ],
    );
  }
}

class _LocationGuidanceCard extends StatelessWidget {
  const _LocationGuidanceCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'المحافظة والمدينة/المديرية مطلوبتان. التفاصيل الأخرى تساعدنا نقترح لك موردين أقرب بدون خرائط أو GPS.',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w700, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.requiredField = false,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final bool requiredField;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.right,
      maxLines: maxLines,
      textInputAction: maxLines > 1 ? TextInputAction.newline : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _SuggestionWrap extends StatelessWidget {
  const _SuggestionWrap({
    required this.suggestions,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<String> suggestions;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final suggestion in suggestions)
          ChoiceChip(
            label: Text(suggestion),
            selected: suggestion == selectedValue,
            onSelected: (_) => onSelected(suggestion),
          ),
      ],
    );
  }
}
