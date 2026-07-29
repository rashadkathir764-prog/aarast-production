import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/yemen_administrative_provider.dart';

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
    final catalog = context.watch<YemenAdministrativeProvider?>();
    final governorateSuggestions =
        catalog?.governorates
            .map((item) => item.nameAr)
            .toList(growable: false) ??
        const [];
    final districtSuggestions =
        catalog
            ?.districtsForGovernorateName(governorate)
            .map((item) => item.nameAr)
            .toList(growable: false) ??
        const [];
    if (governorate.isNotEmpty && catalog != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        catalog.loadDistrictsForGovernorateName(governorate);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showRequiredHint) ...[
          const _LocationGuidanceCard(),
          const SizedBox(height: 12),
        ],
        _LocationSelect(
          controller: governorateController,
          label: 'حدد المحافظة',
          hintText: 'مثال: صنعاء',
          icon: LucideIcons.map,
          items: governorateSuggestions,
          onSelected: (value) {
            catalog?.loadDistrictsForGovernorateName(value);
            cityOrDistrictController.clear();
            areaOrNeighborhoodController.clear();
            onChanged?.call();
          },
        ),
        if (catalog?.isLoadingGovernorates == true) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (catalog?.errorMessage case final errorMessage?) ...[
          const SizedBox(height: 8),
          _LocationCatalogError(
            message: errorMessage,
            onRetry: () {
              if (governorate.isEmpty) {
                catalog?.loadGovernorates();
              } else {
                catalog?.loadDistrictsForGovernorateName(governorate);
              }
            },
          ),
        ],
        const SizedBox(height: 12),
        _LocationSelect(
          controller: cityOrDistrictController,
          label: 'اختر المديرية',
          hintText: governorate.isEmpty
              ? 'اختر المحافظة أولاً'
              : 'اكتب أو اختر المديرية',
          icon: LucideIcons.mapPin,
          items: districtSuggestions,
          onSelected: (_) {
            areaOrNeighborhoodController.clear();
            onChanged?.call();
          },
        ),
        if (showOptionalDetails) ...[
          const SizedBox(height: 12),
          _LocationField(
            controller: areaOrNeighborhoodController,
            label: 'اكتب الحي أو المنطقة',
            hintText: 'مثال: حي الأنصار',
            icon: LucideIcons.building2,
            onChanged: (_) => onChanged?.call(),
          ),
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

class _LocationCatalogError extends StatelessWidget {
  const _LocationCatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
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
              'المحافظة والمديرية مطلوبتان. أضف الحي والشارع إن توفّرا لنقترح لك مزوّدين أقرب.',
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
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
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
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _LocationSelect extends StatelessWidget {
  const _LocationSelect({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.items,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = controller.text.trim();
    final options = [
      if (selected.isNotEmpty && !items.contains(selected)) selected,
      ...items,
    ];
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:$selected:${items.length}'),
      initialValue: selected.isEmpty ? null : selected,
      isExpanded: true,
      menuMaxHeight: 360,
      items: [
        for (final item in options)
          DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: options.isEmpty
          ? null
          : (value) {
              if (value == null) return;
              controller.text = value;
              onSelected(value);
            },
      decoration: InputDecoration(
        labelText: '$label *',
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
