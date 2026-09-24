import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show MarketplaceService;
import '../providers/provider_dashboard_provider.dart';

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
  AarastFormDraftBinding? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProviderDashboardProvider>().loadDashboard();
      _configureDraft();
    });
  }

  @override
  void dispose() {
    _draft?.dispose();
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
    final canManageListing = _canManageProviderListing(
      dashboard.profile?.status,
    );

    return AarastPageScaffold(
      title: 'إضافة باقة',
      subtitle: 'اجمعي أكثر عرض يطلبه العملاء في باقة واضحة.',
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: canManageListing
          ? AarastV3FormActionBar(
              label: 'إضافة الباقة',
              icon: LucideIcons.plus,
              loading: dashboard.isSubmitting,
              onPressed: dashboard.isSubmitting ? null : _submit,
            )
          : null,
      actions: [
        IconButton(
          tooltip: 'رجوع',
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(LucideIcons.chevronRight),
        ),
      ],
      child: !canManageListing
          ? ListView(
              children: [
                if (dashboard.isLoading && dashboard.profile == null)
                  AarastSkeleton.form(fields: 4, inline: true)
                else
                  AarastEmptyState(
                    icon: LucideIcons.fileClock,
                    title: 'إضافة الباقات بعد الاعتماد',
                    message:
                        'الإدارة تراجع حساب المزود أولاً. يمكنك إضافة الباقات بعد أن تصبح الحالة نشطة.',
                    action: FilledButton.icon(
                      onPressed: () => context.go(AppRouter.providerDashboard),
                      icon: const Icon(LucideIcons.layoutDashboard),
                      label: const Text('فتح لوحة المزود'),
                    ),
                  ),
              ],
            )
          : Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  const AarastV3FocusPrompt(
                    question: 'ما العرض الذي تريد جمعه في باقة واحدة؟',
                    supportingText:
                        'ابدأ باسم واضح وسعر حقيقي؛ وأضف المزايا والخدمة المرتبطة عند الحاجة.',
                    icon: LucideIcons.package,
                  ),
                  if (_draft != null) ...[
                    const SizedBox(height: 8),
                    AarastV3DraftStatusLine(status: _draft!.status),
                  ],
                  const SizedBox(height: 10),
                  AarastV3FormSurface(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'اسم الباقة',
                          prefixIcon: Icon(LucideIcons.package),
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                            ? 'اكتب اسم الباقة'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'السعر',
                          suffixText: currencyLabelAr(defaultCurrencyCode),
                          prefixIcon: Icon(LucideIcons.wallet),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AarastDisclosureCard(
                    title: 'محتوى الباقة',
                    subtitle: 'الخدمة المرتبطة والوصف والمميزات',
                    icon: LucideIcons.listChecks,
                    initiallyExpanded:
                        _serviceId != null ||
                        _descriptionController.text.isNotEmpty ||
                        _itemsController.text.isNotEmpty,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _safeServiceId(services),
                          decoration: const InputDecoration(
                            labelText: 'الخدمة المرتبطة',
                            prefixIcon: Icon(LucideIcons.wand),
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
                          onChanged: (value) {
                            setState(() => _serviceId = value);
                            _draft?.changed();
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 3,
                          maxLength: 220,
                          decoration: const InputDecoration(
                            labelText: 'وصف مختصر',
                            prefixIcon: Icon(LucideIcons.fileText),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _itemsController,
                          minLines: 3,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'المميزات',
                            hintText: 'كل ميزة في سطر',
                            prefixIcon: Icon(LucideIcons.listChecks),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dashboard.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    _InlineError(message: dashboard.errorMessage!),
                  ],
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

  void _configureDraft() {
    if (_draft != null) return;
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope: 'provider:package:new',
      fields: {
        'title': _titleController,
        'description': _descriptionController,
        'price': _priceController,
        'items': _itemsController,
      },
      readExtras: () => {'serviceId': _serviceId},
      restoreExtras: (data) {
        if (!mounted) return;
        setState(() => _serviceId = data['serviceId']?.toString());
      },
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_draft!.restore());
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
      currency: defaultCurrencyCode,
      items: items,
    );

    if (!mounted) return;
    if (ok) {
      await _draft?.clear();
      if (!mounted) return;
      final router = GoRouter.of(context);
      AarastFormSuccess.show(
        context,
        message: 'تمت إضافة الباقة.',
        nextLabel: 'إضافة أخرى',
        onNext: () => router.push(AppRouter.providerPackageNew),
      );
      context.go(AppRouter.providerDashboard);
    }
  }
}

bool _canManageProviderListing(String? status) {
  return status == 'ACTIVE' || status == 'APPROVED';
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.brandMuted,
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
