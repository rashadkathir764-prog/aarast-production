import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceService, ProviderPackage;
import '../providers/provider_dashboard_provider.dart';

class ProviderPackageManagementCard extends StatelessWidget {
  const ProviderPackageManagementCard({
    required this.item,
    required this.priceLabel,
    required this.busy,
    required this.onEdit,
    required this.onToggleActive,
    super.key,
  });

  final ProviderPackage item;
  final String? priceLabel;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.gem, color: AppTheme.focus),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (priceLabel != null)
                      Text(
                        priceLabel!,
                        style: const TextStyle(
                          color: AppTheme.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
              AarastStatusPill(
                label: item.isActive ? 'نشطة' : 'متوقفة',
                icon: item.isActive ? LucideIcons.check : LucideIcons.pause,
                color: item.isActive
                    ? AppTheme.success
                    : AppTheme.textSecondary,
                backgroundColor: item.isActive
                    ? AppTheme.successSoft
                    : AppTheme.canvas,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('provider-package-edit-${item.id}'),
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(LucideIcons.pencil),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('provider-package-toggle-${item.id}'),
                  onPressed: busy ? null : onToggleActive,
                  icon: Icon(
                    item.isActive ? LucideIcons.pause : LucideIcons.play,
                  ),
                  label: Text(item.isActive ? 'إيقاف' : 'تفعيل'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<bool?> confirmProviderListingPause(
  BuildContext context, {
  required String kind,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AarastDialog(
      title: Text('إيقاف $kind؟'),
      content: Text(
        'لن يظهر $kind للعملاء حتى تعيد تفعيله، ولن تُحذف بياناته.',
        style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('إيقاف'),
        ),
      ],
    ),
  );
}

Future<bool?> showProviderServiceEditDialog(
  BuildContext context,
  MarketplaceService service,
) async {
  final title = TextEditingController(text: service.title);
  final description = TextEditingController(text: service.description);
  final price = TextEditingController(text: service.basePrice);
  final priceUnit = TextEditingController(text: service.priceUnit);
  final formKey = GlobalKey<FormState>();
  final currency = service.currency ?? defaultCurrencyCode;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      var submitting = false;
      String? errorMessage;
      return StatefulBuilder(
        builder: (context, setDialogState) => AarastDialog(
          title: const Text('تعديل الخدمة'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AarastV3FocusPrompt(
                  question: 'ما الذي تغيّر في هذه الخدمة؟',
                  supportingText:
                      'ثبّت الاسم والسعر أولًا، ثم أضف التفاصيل التي يحتاجها العرض.',
                  icon: LucideIcons.wand,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('provider-service-edit-title'),
                  controller: title,
                  decoration: const InputDecoration(labelText: 'اسم الخدمة'),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'اكتب اسم الخدمة.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'السعر من (${currencyLabelAr(currency)})',
                  ),
                  validator: validateOptionalProviderListingPrice,
                ),
                const SizedBox(height: 10),
                AarastDisclosureCard(
                  title: 'تفاصيل الخدمة',
                  subtitle: 'الوصف وملاحظة السعر',
                  icon: LucideIcons.fileText,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: description,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'الوصف'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: priceUnit,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة السعر',
                        ),
                      ),
                    ],
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              key: const Key('provider-service-edit-save'),
              onPressed: submitting
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() != true) return;
                      setDialogState(() {
                        submitting = true;
                        errorMessage = null;
                      });
                      final dashboard = context
                          .read<ProviderDashboardProvider>();
                      final success = await dashboard.updateService(
                        serviceId: service.id,
                        title: title.text,
                        description: description.text,
                        basePrice: price.text.replaceAll(',', ''),
                        priceUnit: priceUnit.text,
                        currency: currency,
                      );
                      if (!dialogContext.mounted) return;
                      if (success) {
                        Navigator.pop(dialogContext, true);
                      } else {
                        setDialogState(() {
                          submitting = false;
                          errorMessage =
                              dashboard.errorMessage ?? 'تعذر تحديث الخدمة.';
                        });
                      }
                    },
              child: Text(submitting ? 'جارٍ الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      );
    },
  );
  title.dispose();
  description.dispose();
  price.dispose();
  priceUnit.dispose();
  return saved;
}

Future<bool?> showProviderPackageEditDialog(
  BuildContext context,
  ProviderPackage item,
) async {
  final title = TextEditingController(text: item.title);
  final description = TextEditingController(text: item.description);
  final price = TextEditingController(text: item.price);
  final items = TextEditingController(text: item.items);
  final formKey = GlobalKey<FormState>();
  final currency = item.currency ?? defaultCurrencyCode;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      var submitting = false;
      String? errorMessage;
      return StatefulBuilder(
        builder: (context, setDialogState) => AarastDialog(
          title: const Text('تعديل الباقة'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AarastV3FocusPrompt(
                  question: 'ما الذي تغيّر في هذه الباقة؟',
                  supportingText:
                      'راجع الاسم والسعر، وافتح المزايا فقط إذا احتاجت تعديلًا.',
                  icon: LucideIcons.package,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('provider-package-edit-title'),
                  controller: title,
                  decoration: const InputDecoration(labelText: 'اسم الباقة'),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'اكتب اسم الباقة.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'السعر (${currencyLabelAr(currency)})',
                  ),
                  validator: validateOptionalProviderListingPrice,
                ),
                const SizedBox(height: 10),
                AarastDisclosureCard(
                  title: 'محتوى الباقة',
                  subtitle: 'الوصف والمميزات',
                  icon: LucideIcons.listChecks,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: description,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'الوصف'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: items,
                        minLines: 3,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'المميزات',
                          hintText: 'كل ميزة في سطر',
                        ),
                      ),
                    ],
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              key: const Key('provider-package-edit-save'),
              onPressed: submitting
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() != true) return;
                      setDialogState(() {
                        submitting = true;
                        errorMessage = null;
                      });
                      final dashboard = context
                          .read<ProviderDashboardProvider>();
                      final success = await dashboard.updatePackage(
                        packageId: item.id,
                        title: title.text,
                        description: description.text,
                        price: price.text.replaceAll(',', ''),
                        currency: currency,
                        items: items.text
                            .split('\n')
                            .map((value) => value.trim())
                            .where((value) => value.isNotEmpty)
                            .toList(growable: false),
                      );
                      if (!dialogContext.mounted) return;
                      if (success) {
                        Navigator.pop(dialogContext, true);
                      } else {
                        setDialogState(() {
                          submitting = false;
                          errorMessage =
                              dashboard.errorMessage ?? 'تعذر تحديث الباقة.';
                        });
                      }
                    },
              child: Text(submitting ? 'جارٍ الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      );
    },
  );
  title.dispose();
  description.dispose();
  price.dispose();
  items.dispose();
  return saved;
}

String? validateOptionalProviderListingPrice(String? value) {
  final normalized = value?.trim().replaceAll(',', '') ?? '';
  if (normalized.isEmpty) return null;
  return RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(normalized)
      ? null
      : 'أدخل مبلغًا صحيحًا بحد أقصى منزلتين عشريتين.';
}
