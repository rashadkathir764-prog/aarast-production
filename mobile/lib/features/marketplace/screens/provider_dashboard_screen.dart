import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderDashboardProvider>().loadDashboard();
      context.read<ProviderMarketplaceProvider>().loadReferenceData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();

    return AarastPageScaffold(
      title: 'لوحة المورد',
      subtitle: 'إدارة حضورك وطلبات عروض الأسعار',
      actions: [
        IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
      child: RefreshIndicator(
        color: AppTheme.dMaroon,
        onRefresh: dashboard.loadDashboard,
        child: ListView(
          children: [
            if (dashboard.isLoading && dashboard.profile == null)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!dashboard.hasProviderProfile)
              const _ProviderApplication()
            else ...[
              _ProviderProfileCard(profile: dashboard.profile!),
              const SizedBox(height: 16),
              _ProviderStats(summary: dashboard.summary),
              const SizedBox(height: 16),
              _ProviderServices(services: dashboard.services),
              const SizedBox(height: 16),
              _ProviderQuotes(quotes: dashboard.quoteRequests),
            ],
            if (dashboard.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                dashboard.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _ProviderApplication extends StatefulWidget {
  const _ProviderApplication();

  @override
  State<_ProviderApplication> createState() => _ProviderApplicationState();
}

class _ProviderApplicationState extends State<_ProviderApplication> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _cityId;
  final Set<String> _categoryIds = {};

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final dashboard = context.watch<ProviderDashboardProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastCard(
          color: AppTheme.dCard,
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppTheme.dCreamBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.dGoldDeep,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ليس لديك حساب مورد حتى الآن. أرسلي طلب الانضمام، وبعد الموافقة ستظهر خدماتك وطلبات العملاء هنا.',
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
        ),
        const SizedBox(height: 16),
        AarastCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AarastSectionHeader(
                  title: 'طلب الانضمام كمورد',
                  icon: Icons.assignment_ind_outlined,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم النشاط',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'اكتبي اسم النشاط'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم التواصل',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) => value == null || value.trim().length < 6
                      ? 'اكتبي رقم تواصل صحيح'
                      : null,
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
                  onChanged: (value) => setState(() => _cityId = value),
                  validator: (value) => value == null ? 'اختاري المدينة' : null,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in marketplace.categories)
                      FilterChip(
                        label: Text(category.nameAr),
                        selected: _categoryIds.contains(category.id),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _categoryIds.add(category.id);
                            } else {
                              _categoryIds.remove(category.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'نبذة مختصرة',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: dashboard.isSubmitting ? null : _submit,
                  icon: dashboard.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('إرسال طلب الانضمام'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _cityId == null) return;
    final ok = await context.read<ProviderDashboardProvider>().applyProvider(
      businessName: _businessNameController.text,
      phone: _phoneController.text,
      cityId: _cityId!,
      categoryIds: _categoryIds.toList(),
      description: _descriptionController.text,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الانضمام كمورد')),
        );
    }
  }
}

class _ProviderProfileCard extends StatelessWidget {
  const _ProviderProfileCard({required this.profile});

  final ProviderDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dCard,
      child: Row(
        children: [
          _Logo(url: profile.logoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AarastStatusPill(
                  label: _statusLabel(profile.status),
                  icon: Icons.verified_user_outlined,
                  color: _statusColor(profile.status),
                  backgroundColor: _statusColor(profile.status).withAlpha(24),
                ),
                const SizedBox(height: 10),
                Text(
                  profile.businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.dMaroonDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  profile.city?.nameAr ?? profile.phone ?? 'حساب مورد اعّرست',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderStats extends StatelessWidget {
  const _ProviderStats({required this.summary});

  final ProviderDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.32,
      children: [
        _StatBox(
          icon: Icons.shopping_bag_outlined,
          label: 'الطلبات الجديدة',
          value: '${summary.newQuoteRequestsCount}',
          color: AppTheme.dMaroon,
          bg: AppTheme.dPinkBg,
        ),
        _StatBox(
          icon: Icons.calendar_month_outlined,
          label: 'إجمالي الطلبات',
          value: '${summary.quoteRequestsCount}',
          color: AppTheme.dGoldDeep,
          bg: AppTheme.dCreamBg,
        ),
        _StatBox(
          icon: Icons.star_border_rounded,
          label: 'التقييم',
          value: summary.averageRating.toStringAsFixed(1),
          color: AppTheme.dGreen,
          bg: AppTheme.dGreenBg,
        ),
        _StatBox(
          icon: Icons.design_services_outlined,
          label: 'الخدمات النشطة',
          value: '${summary.activeServicesCount}/${summary.servicesCount}',
          color: AppTheme.dBlue,
          bg: AppTheme.dBlueBg,
        ),
      ],
    );
  }
}

class _ProviderServices extends StatelessWidget {
  const _ProviderServices({required this.services});

  final List<MarketplaceService> services;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'الخدمات',
            icon: Icons.design_services_outlined,
          ),
          const SizedBox(height: 12),
          if (services.isEmpty)
            const AarastEmptyState(
              icon: Icons.design_services_outlined,
              title: 'لا توجد خدمات بعد',
              message: 'عند إضافة الخدمات من لوحة المورد ستظهر هنا للعملاء.',
            )
          else
            SizedBox(
              height: 156,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: services.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return _ServiceMiniCard(service: services[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ProviderQuotes extends StatelessWidget {
  const _ProviderQuotes({required this.quotes});

  final List<QuoteRequest> quotes;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'طلبات عروض الأسعار',
            icon: Icons.chat_bubble_outline_rounded,
          ),
          const SizedBox(height: 12),
          if (quotes.isEmpty)
            const AarastEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'لا توجد طلبات حالية',
              message: 'ستظهر طلبات العملاء هنا عند إرسال عروض سعر لك.',
            )
          else
            for (final quote in quotes.take(5)) ...[
              _QuoteTile(quote: quote),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.dCard2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceMiniCard extends StatelessWidget {
  const _ServiceMiniCard({required this.service});

  final MarketplaceService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.dCreamBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(
                Icons.local_florist_rounded,
                color: AppTheme.dGoldDeep,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            service.basePrice?.trim().isNotEmpty == true
                ? '${service.basePrice} ${service.currency ?? ''}'
                : 'حسب الطلب',
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.dMaroon,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.quote});

  final QuoteRequest quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.dPinkBg,
            child: Text(
              _statusInitial(quote.status),
              style: const TextStyle(
                color: AppTheme.dMaroon,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.service?.title ?? 'طلب عرض سعر',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (quote.message?.trim().isNotEmpty == true)
                  Text(
                    quote.message!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.dInkSoft),
                  ),
              ],
            ),
          ),
          AarastStatusPill(label: _quoteStatus(quote.status)),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    return ClipOval(
      child: Container(
        width: 78,
        height: 78,
        color: AppTheme.dCreamBg,
        child: imageUrl == null || imageUrl.isEmpty
            ? const Icon(
                Icons.storefront_rounded,
                color: AppTheme.dGoldDeep,
                size: 36,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.dGoldDeep,
                  size: 36,
                ),
              ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'APPROVED' => 'معتمد',
    'REJECTED' => 'مرفوض',
    'SUSPENDED' => 'موقوف',
    _ => 'قيد المراجعة',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'APPROVED' => AppTheme.dGreen,
    'REJECTED' => AppTheme.danger,
    'SUSPENDED' => AppTheme.dOrange,
    _ => AppTheme.dGoldDeep,
  };
}

String _quoteStatus(String status) {
  return switch (status) {
    'ACCEPTED' => 'مقبول',
    'REJECTED' => 'مرفوض',
    'RESPONDED' => 'تم الرد',
    _ => 'جديد',
  };
}

String _statusInitial(String status) {
  return switch (status) {
    'ACCEPTED' => 'ق',
    'REJECTED' => 'ر',
    'RESPONDED' => 'ت',
    _ => 'ج',
  };
}
