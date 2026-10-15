import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/yemen_administrative_provider.dart';
import '../models/yemen_administrative_area.dart';

class LocationPickerSection extends StatelessWidget {
  const LocationPickerSection({
    required this.governorateController,
    required this.cityOrDistrictController,
    required this.areaOrNeighborhoodController,
    required this.neighborhoodController,
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
  final TextEditingController neighborhoodController;
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
        const <String>[];
    final districtSuggestions =
        catalog
            ?.districtsForGovernorateName(governorate)
            .map((item) => item.nameAr)
            .toList(growable: false) ??
        const <String>[];
    final district = cityOrDistrictController.text.trim();
    final localities =
        catalog?.localitiesForDistrictName(governorate, district) ??
        const <YemenLocality>[];
    final areaSuggestions = localities
        .where((item) => item.type != YemenLocalityType.neighborhood)
        .map((item) => item.nameAr)
        .toList(growable: false);
    final neighborhoodSuggestions = localities
        .where((item) => item.type == YemenLocalityType.neighborhood)
        .map((item) => item.nameAr)
        .toList(growable: false);
    final isLoadingDistricts =
        (catalog?.isLoadingDistrictsForGovernorateName(governorate) ?? false) &&
        districtSuggestions.isEmpty;
    final isLoadingGovernorates =
        (catalog?.isLoadingGovernorates ?? false) &&
        governorateSuggestions.isEmpty;
    final isLoadingLocalities =
        catalog?.isLoadingLocalitiesForDistrictName(governorate, district) ??
        false;

    if (governorate.isNotEmpty && catalog != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        catalog.loadDistrictsForGovernorateName(governorate);
      });
    }
    if (governorate.isNotEmpty && district.isNotEmpty && catalog != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        catalog.loadLocalitiesForDistrictName(governorate, district);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showRequiredHint) ...[
          const _LocationGuidance(),
          const SizedBox(height: 10),
        ],
        _LocationSelect(
          controller: governorateController,
          label: 'المحافظة',
          hintText: isLoadingGovernorates
              ? 'جاري تحميل المحافظات…'
              : 'اختر المحافظة',
          icon: LucideIcons.map,
          items: governorateSuggestions,
          loading: isLoadingGovernorates,
          allowManualInput:
              catalog == null ||
              (catalog.errorMessage != null && governorateSuggestions.isEmpty),
          onSelected: (value) {
            catalog?.loadDistrictsForGovernorateName(value);
            cityOrDistrictController.clear();
            areaOrNeighborhoodController.clear();
            neighborhoodController.clear();
            onChanged?.call();
          },
        ),
        if (catalog?.errorMessage case final errorMessage?) ...[
          const SizedBox(height: 8),
          _LocationCatalogError(
            message: errorMessage,
            onRetry: () {
              if (governorate.isNotEmpty && district.isNotEmpty) {
                catalog?.loadLocalitiesForDistrictName(governorate, district);
              } else if (governorate.isEmpty) {
                catalog?.loadGovernorates(force: true);
              } else {
                catalog?.loadDistrictsForGovernorateName(governorate);
              }
            },
          ),
        ],
        const SizedBox(height: 10),
        _LocationSelect(
          controller: cityOrDistrictController,
          label: 'المديرية',
          hintText: governorate.isEmpty
              ? 'اختر المحافظة أولًا'
              : isLoadingDistricts
              ? 'جاري تحميل المديريات…'
              : 'اختر المديرية',
          icon: LucideIcons.mapPin,
          items: districtSuggestions,
          loading: isLoadingDistricts,
          enabled: governorate.isNotEmpty,
          allowManualInput:
              catalog == null ||
              (governorate.isNotEmpty &&
                  !isLoadingDistricts &&
                  districtSuggestions.isEmpty),
          onSelected: (value) {
            areaOrNeighborhoodController.clear();
            neighborhoodController.clear();
            catalog?.loadLocalitiesForDistrictName(governorate, value);
            onChanged?.call();
          },
        ),
        const SizedBox(height: 10),
        _AreaAndNeighborhoodFields(
          areaController: areaOrNeighborhoodController,
          neighborhoodController: neighborhoodController,
          areaSuggestions: areaSuggestions,
          neighborhoodSuggestions: neighborhoodSuggestions,
          enabled: district.isNotEmpty,
          loading: isLoadingLocalities,
          onChanged: onChanged,
        ),
        if (showOptionalDetails) ...[
          const SizedBox(height: 10),
          _LocationField(
            controller: streetController,
            label: 'الشارع أو أقرب معلم',
            hintText: 'مثال: شارع تعز',
            icon: LucideIcons.navigation,
            onChanged: (_) => onChanged?.call(),
          ),
          const SizedBox(height: 10),
          _LocationField(
            controller: detailedAddressController,
            label: 'تفاصيل إضافية',
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

class _LocationGuidance extends StatelessWidget {
  const _LocationGuidance();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, size: 18, color: AppTheme.focus),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'اختر المحافظة ثم المديرية بالترتيب، واكتب المنطقة أو العزلة والحي عند توفرهما.',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaAndNeighborhoodFields extends StatelessWidget {
  const _AreaAndNeighborhoodFields({
    required this.areaController,
    required this.neighborhoodController,
    required this.areaSuggestions,
    required this.neighborhoodSuggestions,
    required this.enabled,
    required this.loading,
    this.onChanged,
  });

  final TextEditingController areaController;
  final TextEditingController neighborhoodController;
  final List<String> areaSuggestions;
  final List<String> neighborhoodSuggestions;
  final bool enabled;
  final bool loading;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = _LocationSelect(
          controller: areaController,
          label: 'المنطقة أو العزلة',
          hintText: enabled ? 'اختر أو اكتب' : 'اختر المديرية أولًا',
          icon: LucideIcons.layers,
          items: areaSuggestions,
          enabled: enabled,
          loading: loading && areaSuggestions.isEmpty,
          allowManualInput: true,
          requiredField: false,
          onSelected: (_) => onChanged?.call(),
        );
        final neighborhood = _LocationSelect(
          controller: neighborhoodController,
          label: 'الحي',
          hintText: enabled ? 'اختر أو اكتب' : 'اختر المديرية أولًا',
          icon: LucideIcons.building2,
          items: neighborhoodSuggestions,
          enabled: enabled,
          loading: loading && neighborhoodSuggestions.isEmpty,
          allowManualInput: true,
          requiredField: false,
          onSelected: (_) => onChanged?.call(),
        );
        if (constraints.maxWidth < 350 || textScale > 1.3) {
          return Column(
            children: [area, const SizedBox(height: 10), neighborhood],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: area),
            const SizedBox(width: 10),
            Expanded(child: neighborhood),
          ],
        );
      },
    );
  }
}

class _LocationCatalogError extends StatelessWidget {
  const _LocationCatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$message يمكنك الكتابة يدويًا الآن.',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
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
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      onChanged: onChanged,
      decoration: _locationDecoration(label: label, hint: hintText, icon: icon),
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
    this.loading = false,
    this.enabled = true,
    this.allowManualInput = false,
    this.requiredField = true,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String> onSelected;
  final bool loading;
  final bool enabled;
  final bool allowManualInput;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    if (allowManualInput && items.isEmpty && !loading) {
      return TextField(
        controller: controller,
        enabled: enabled,
        textAlign: TextAlign.right,
        textInputAction: TextInputAction.next,
        onChanged: onSelected,
        decoration: _locationDecoration(
          label: requiredField ? '$label *' : label,
          hint: hintText,
          icon: icon,
        ),
      );
    }

    final selected = controller.text.trim();
    return Semantics(
      button: true,
      enabled: enabled && !loading && items.isNotEmpty,
      label: '$label، ${selected.isEmpty ? hintText : selected}',
      child: InkWell(
        onTap: !enabled || loading || items.isEmpty
            ? null
            : () async {
                final value = await showAarastBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => _LocationPickerSheet(
                    title: 'اختر $label',
                    items: items,
                    selected: selected,
                    allowManualInput: allowManualInput,
                  ),
                );
                if (value == null || !context.mounted) return;
                controller.text = value;
                onSelected(value);
              },
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 10, 6),
          decoration: BoxDecoration(
            color: enabled ? AppTheme.surfaceRaised : AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(
              color: selected.isEmpty ? AppTheme.border : AppTheme.brand,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: enabled ? AppTheme.focus : AppTheme.textDisabled,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requiredField ? '$label *' : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      selected.isEmpty ? hintText : selected,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected.isEmpty
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const AarastInlineSpinner()
              else
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

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.allowManualInput,
  });

  final String title;
  final List<String> items;
  final String selected;
  final bool allowManualInput;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim();
    final visible = normalized.isEmpty
        ? widget.items
        : widget.items
              .where((item) => item.contains(normalized))
              .toList(growable: false);
    final canUseCustom =
        widget.allowManualInput &&
        normalized.isNotEmpty &&
        !widget.items.contains(normalized);
    final height = (MediaQuery.sizeOf(context).height * .76).clamp(
      360.0,
      620.0,
    );

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastBottomSheetHandle(),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              // No autofocus: the keyboard would cover most of the list the
              // user came to tap. Search is one tap away.
              textAlign: TextAlign.right,
              onChanged: (value) => setState(() => _query = value),
              decoration: _locationDecoration(
                label: 'بحث',
                hint: 'اكتب الاسم',
                icon: LucideIcons.search,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: visible.isEmpty && !canUseCustom
                ? Center(
                    child: Text(
                      'لا توجد نتيجة مطابقة',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: visible.length + (canUseCustom ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: AppTheme.border,
                    ),
                    itemBuilder: (context, index) {
                      if (canUseCustom && index == 0) {
                        return ListTile(
                          minTileHeight: 52,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          leading: const Icon(
                            LucideIcons.pencil,
                            size: 18,
                            color: AppTheme.focus,
                          ),
                          title: Text(
                            'استخدام «$normalized»',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.focus,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          onTap: () => Navigator.of(context).pop(normalized),
                        );
                      }
                      final itemIndex = index - (canUseCustom ? 1 : 0);
                      final item = visible[itemIndex];
                      final selected = item == widget.selected;
                      return ListTile(
                        minTileHeight: 50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        title: Text(
                          item,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                              ),
                        ),
                        trailing: selected
                            ? const Icon(
                                LucideIcons.check,
                                size: 18,
                                color: AppTheme.brand,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _locationDecoration({
  required String label,
  required String hint,
  required IconData icon,
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
    prefixIcon: Icon(icon, size: 19, color: AppTheme.focus),
    prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
    border: border,
    enabledBorder: border,
    disabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusControl)),
      borderSide: BorderSide(color: AppTheme.border),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusControl)),
      borderSide: BorderSide(color: AppTheme.brand, width: 1.5),
    ),
  );
}
