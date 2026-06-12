import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';

class AddProviderPackageScreen extends StatefulWidget {
  const AddProviderPackageScreen({super.key});

  @override
  State<AddProviderPackageScreen> createState() =>
      _AddProviderPackageScreenState();
}

class _AddProviderPackageScreenState extends State<AddProviderPackageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _itemsController = TextEditingController();
  String? _serviceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderDashboardProvider>().loadDashboard();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _itemsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final services = dashboard.services;

    return AarastPageScaffold(
      title: 'إضافة باقة',
      subtitle: 'اجمعي أكثر عرض يطلبه العملاء في باقة واضحة.',
      resizeToAvoidBottomInset: true,
      actions: [
        IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
      child: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const _PackageIntro(),
            const SizedBox(height: 16),
            AarastCard(
              color: AppTheme.dCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم الباقة',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                        ? 'اكتبي اسم الباقة'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _safeServiceId(services),
                    decoration: const InputDecoration(
                      labelText: 'خدمة مرتبطة اختياري',
                      prefixIcon: Icon(Icons.design_services_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('باقة عامة'),
                      ),
                      for (final service in services)
                        DropdownMenuItem(
                          value: service.id,
                          child: Text(service.title),
                        ),
                    ],
                    onChanged: (value) => setState(() => _serviceId = value),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'السعر',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    maxLength: 220,
                    decoration: const InputDecoration(
                      labelText: 'الوصف',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _itemsController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'المميزات',
                      hintText: 'اكتبي كل ميزة في سطر مستقل',
                      prefixIcon: Icon(Icons.checklist_rtl_rounded),
                    ),
                  ),
                  if (dashboard.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _InlineError(message: dashboard.errorMessage!),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: dashboard.isSubmitting ? null : _submit,
                    icon: dashboard.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: const Text('إضافة الباقة'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String? _safeServiceId(List<MarketplaceService> services) {
    if (_serviceId == null) return null;
    return services.any((service) => service.id == _serviceId)
        ? _serviceId
        : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final items = _itemsController.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final ok = await context.read<ProviderDashboardProvider>().createPackage(
      title: _titleController.text,
      serviceId: _serviceId,
      description: _descriptionController.text,
      price: _priceController.text,
      currency: 'YER',
      items: items,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تمت إضافة الباقة')));
      context.go(AppRouter.providerDashboard);
    }
  }
}

class _PackageIntro extends StatelessWidget {
  const _PackageIntro();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      color: AppTheme.dCreamBg,
      child: Row(
        children: [
          Icon(Icons.card_giftcard_rounded, color: AppTheme.dGoldDeep),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'الباقات تساعد العملاء على مقارنة العروض بسرعة. لا تضيفي وعود دفع أو حجز مؤكد هنا.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dPinkBg,
      border: Border.all(color: AppTheme.danger.withAlpha(55)),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
