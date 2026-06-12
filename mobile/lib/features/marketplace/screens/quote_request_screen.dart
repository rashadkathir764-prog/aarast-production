import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';

class QuoteRequestScreen extends StatefulWidget {
  const QuoteRequestScreen({
    required this.providerId,
    this.initialServiceId,
    super.key,
  });

  final String providerId;
  final String? initialServiceId;

  @override
  State<QuoteRequestScreen> createState() => _QuoteRequestScreenState();
}

class _QuoteRequestScreenState extends State<QuoteRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _guestCountController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _messageController = TextEditingController();

  String? _weddingPlanId;
  String? _serviceId;
  String? _cityId;
  DateTime? _eventDate;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.initialServiceId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderMarketplaceProvider>().loadProviderDetails(
        widget.providerId,
      );
      context.read<ProviderMarketplaceProvider>().loadReferenceData();
      context.read<WeddingPlansProvider>().loadMyWeddingPlans();
    });
  }

  @override
  void dispose() {
    _guestCountController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final plans = context.watch<WeddingPlansProvider>();
    final provider = marketplace.providerDetails(widget.providerId);
    final services = marketplace.servicesFor(widget.providerId);

    return AarastPageScaffold(
      title: 'طلب عرض سعر',
      subtitle: provider == null
          ? 'حددي احتياجك للمورد'
          : 'إلى ${provider.businessName}',
      actions: [
        IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
      resizeToAvoidBottomInset: true,
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _QuoteIntro(provider: provider),
            const SizedBox(height: 18),
            AarastCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _weddingPlanId,
                    decoration: const InputDecoration(
                      labelText: 'خطة الزفاف',
                      prefixIcon: Icon(Icons.event_note_outlined),
                    ),
                    items: plans.plans
                        .map(
                          (plan) => DropdownMenuItem(
                            value: plan.id,
                            child: Text(plan.title),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _weddingPlanId = value;
                    }),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _safeSelectedService(services),
                    decoration: const InputDecoration(
                      labelText: 'الخدمة',
                      prefixIcon: Icon(Icons.design_services_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('حسب اقتراح المورد'),
                      ),
                      for (final service in services)
                        DropdownMenuItem(
                          value: service.id,
                          child: Text(service.title),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _serviceId = value;
                    }),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _cityId,
                    decoration: const InputDecoration(
                      labelText: 'المدينة',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    items: marketplace.cities
                        .map(
                          (city) => DropdownMenuItem(
                            value: city.id,
                            child: Text(city.nameAr),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _cityId = value;
                    }),
                  ),
                  const SizedBox(height: 14),
                  _DateField(value: _eventDate, onTap: _pickDate),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _guestCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد الضيوف المتوقع',
                      prefixIcon: Icon(Icons.people_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _budgetMinController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'أقل ميزانية',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _budgetMaxController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'أعلى ميزانية',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 4,
                    maxLength: 250,
                    decoration: const InputDecoration(
                      labelText: 'رسالة للمورد',
                      hintText: 'اكتبي تفاصيل التاريخ، المكان، والاحتياج...',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 8) {
                        return 'اكتبي تفاصيل قصيرة ليفهم المورد طلبك';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (marketplace.errorMessage != null) ...[
              Text(
                marketplace.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: marketplace.isSubmitting ? null : _submit,
              icon: marketplace.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('إرسال الطلب'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String? _safeSelectedService(List<MarketplaceService> services) {
    if (_serviceId == null) return null;
    return services.any((service) => service.id == _serviceId)
        ? _serviceId
        : null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _eventDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final guestCount = int.tryParse(_guestCountController.text.trim());
    final success = await context
        .read<ProviderMarketplaceProvider>()
        .createQuoteRequest(
          providerId: widget.providerId,
          weddingPlanId: _weddingPlanId,
          serviceId: _serviceId,
          eventDate: _eventDate,
          cityId: _cityId,
          guestCount: guestCount,
          budgetMin: _budgetMinController.text,
          budgetMax: _budgetMaxController.text,
          message: _messageController.text,
        );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب عرض السعر بنجاح')),
        );
      if (context.canPop()) context.pop();
    }
  }
}

class _QuoteIntro extends StatelessWidget {
  const _QuoteIntro({required this.provider});

  final MarketplaceProvider? provider;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dCard,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.dPinkBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppTheme.dMaroon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              provider == null
                  ? 'ارسلي طلبًا واضحًا وسيصل للمورد عبر النظام عند توفر البيانات.'
                  : 'اكتبي تفاصيلك وسيتم إرسالها إلى ${provider!.businessName} ضمن طلبات عروض الأسعار.',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'تاريخ المناسبة',
          prefixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          value == null
              ? 'اختاري التاريخ'
              : '${value!.day}/${value!.month}/${value!.year}',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: value == null ? AppTheme.dMuted : AppTheme.dInk,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
