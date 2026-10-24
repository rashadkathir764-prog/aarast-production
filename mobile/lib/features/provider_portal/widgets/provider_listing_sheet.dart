import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/currency_label.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceService, ProviderPackage;
import '../providers/provider_dashboard_provider.dart';

/// p36's edit of one service or package, in a journey sheet: its name, its
/// price in the currency it was priced in, what it includes, and whether
/// customers see it. Showing or hiding applies at once; the rest is saved
/// with «احفظ». Returns true when anything was saved.
Future<bool?> showProviderListingSheet(
  BuildContext context, {
  MarketplaceService? service,
  ProviderPackage? package,
}) {
  assert((service == null) != (package == null));
  return showJourneySheet<bool>(
    context: context,
    builder: (_) => _ListingSheet(service: service, package: package),
  );
}

/// A price as the server takes it: digits with up to two decimals, or empty.
String? providerListingPriceError(String value) {
  final normalized = value.trim().replaceAll(',', '');
  if (normalized.isEmpty) return null;
  return RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(normalized)
      ? null
      : 'اكتب المبلغ أرقام بس.';
}

class _ListingSheet extends StatefulWidget {
  const _ListingSheet({this.service, this.package});

  final MarketplaceService? service;
  final ProviderPackage? package;

  @override
  State<_ListingSheet> createState() => _ListingSheetState();
}

class _ListingSheetState extends State<_ListingSheet> {
  late final _title = TextEditingController(
    text: widget.service?.title ?? widget.package!.title,
  );
  late final _price = TextEditingController(
    text: widget.service?.basePrice ?? widget.package!.price ?? '',
  );
  late final _includes = TextEditingController(
    text: widget.service?.description ?? widget.package!.description ?? '',
  );
  late final _extra = TextEditingController(
    text: widget.service?.priceUnit ?? widget.package!.items ?? '',
  );
  late bool _active = widget.service?.isActive ?? widget.package!.isActive;
  bool _saving = false;
  bool _switching = false;
  String? _titleError;
  String? _priceError;
  String? _error;

  bool get _isService => widget.service != null;

  String get _currency =>
      (_isService ? widget.service!.currency : widget.package!.currency) ??
      defaultCurrencyCode;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _includes.dispose();
    _extra.dispose();
    super.dispose();
  }

  Future<void> _setActive(bool value) async {
    setState(() {
      _switching = true;
      _error = null;
    });
    final dashboard = context.read<ProviderDashboardProvider>();
    final ok = _isService
        ? await dashboard.setServiceActive(
            serviceId: widget.service!.id,
            isActive: value,
          )
        : await dashboard.setPackageActive(
            packageId: widget.package!.id,
            isActive: value,
          );
    if (!mounted) return;
    setState(() {
      _switching = false;
      if (ok) {
        _active = value;
      } else {
        _error = dashboard.errorMessage ?? 'ما قدرنا نغيّرها، جرب مرة ثانية.';
      }
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    setState(() {
      _titleError = title.length < 2 ? 'اكتب الاسم.' : null;
      _priceError = providerListingPriceError(_price.text);
      _error = null;
    });
    if (_titleError != null || _priceError != null) return;
    setState(() => _saving = true);
    final dashboard = context.read<ProviderDashboardProvider>();
    final price = _price.text.trim().replaceAll(',', '');
    final ok = _isService
        ? await dashboard.updateService(
            serviceId: widget.service!.id,
            title: title,
            description: _includes.text,
            basePrice: price,
            priceUnit: _extra.text,
            currency: _currency,
          )
        : await dashboard.updatePackage(
            packageId: widget.package!.id,
            title: title,
            description: _includes.text,
            price: price,
            currency: _currency,
            items: _extra.text
                .split('\n')
                .map((line) => line.trim())
                .where((line) => line.isNotEmpty)
                .toList(growable: false),
          );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = dashboard.errorMessage ?? 'ما قدرنا نحفظ، جرب مرة ثانية.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: JourneySheetBody(
        title: _isService ? 'عدّل الخدمة' : 'عدّل الباقة',
        bottom: JourneyButton(
          key: const Key('provider-listing-save'),
          label: 'احفظ',
          large: true,
          expand: true,
          loading: _saving,
          onPressed: _switching ? null : _save,
        ),
        children: [
          JourneyTextField(
            key: const Key('provider-listing-title'),
            label: _isService ? 'اسم الخدمة' : 'اسم الباقة',
            controller: _title,
            errorText: _titleError,
          ),
          const SizedBox(height: 10),
          JourneyTextField(
            key: const Key('provider-listing-price'),
            label: _isService ? 'السعر من' : 'السعر',
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: currencyLabelAr(_currency),
            errorText: _priceError,
          ),
          const SizedBox(height: 10),
          JourneyTextField(
            key: const Key('provider-listing-includes'),
            label: 'وش تشمل',
            controller: _includes,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 10),
          JourneyTextField(
            key: const Key('provider-listing-extra'),
            label: _isService ? 'ملاحظة السعر' : 'المميزات · كل وحدة في سطر',
            controller: _extra,
            minLines: _isService ? 1 : 2,
            maxLines: _isService ? 1 : 5,
          ),
          const SizedBox(height: 12),
          JourneyList(
            children: [
              JourneyListRow(
                key: const Key('provider-listing-active'),
                icon: _active ? LucideIcons.eye : LucideIcons.eyeOff,
                color: _active
                    ? AarastV3Color.primary
                    : AarastV3Color.textMuted,
                soft: _active ? AarastV3Color.primarySoft : AarastV3Color.line,
                title: 'تظهر للعرسان',
                subtitle: _active
                    ? 'لو وقفتها ما تنحذف، وترجعها متى ما تشتي'
                    : 'موقوفة، ما يشوفها أحد لين ترجعها',
                onTap: _switching || _saving
                    ? null
                    : () => _setActive(!_active),
                trailing: JourneyToggle(
                  value: _active,
                  onChanged: _switching || _saving ? null : _setActive,
                ),
              ),
            ],
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 10),
            JourneyNote(
              text: error,
              icon: LucideIcons.alertCircle,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
          ],
        ],
      ),
    );
  }
}
