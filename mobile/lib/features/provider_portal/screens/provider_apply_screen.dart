import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthActionGuard, AuthController;
import '../../marketplace/marketplace_api.dart'
    show ProviderMarketplaceProvider;
import '../data/provider_approval_ledger.dart';
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_join_parts.dart';
import '../widgets/provider_request_parts.dart' show providerMoneyLabel;
import 'provider_claim_screen.dart';

part 'provider_apply_screen.steps.dart';

/// The joining, after the account (p01): a listing under this phone is
/// claimed through the review team (p02, then its waiting state, B-12);
/// otherwise four steps, p03 «نشاطك», p04 «وين تشتغل؟», p06 «خدمتك
/// وسعرها» and p07 «كذا بيشوفك العرسان».
///
/// Apply creates the provider as PENDING at once (F1), so the steps are kept
/// on the phone and sent together from p07 with the one priced service the
/// review needs (B-10, D41). Photos and the way of working (p05, p05b) come
/// after V1, and the other services after approval, so they are not asked.
class ProviderApplyScreen extends StatefulWidget {
  const ProviderApplyScreen({super.key});

  @override
  State<ProviderApplyScreen> createState() => _ProviderApplyScreenState();
}

class _ProviderApplyScreenState extends State<ProviderApplyScreen> {
  static const _steps = ['نشاطك', 'وين', 'خدمتك', 'أرسل'];

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _serviceController = TextEditingController();
  final _priceController = TextEditingController();
  final _serviceAboutController = TextEditingController();
  String? _cityId;
  String? _categoryId;
  int _step = 0;
  bool _attempted = false;
  bool _ready = false;
  bool _leaving = false;

  /// A send is running; it opens the portal itself once the account's paths
  /// are read again.
  bool _joining = false;
  String? _sendError;
  String? _claimError;
  AarastFormDraftBinding? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProviderMarketplaceProvider>().loadReferenceData();
      _configureDraft();
      _lookup();
    });
  }

  /// Whether this account already has a profile, a claim waiting for the
  /// team, or a listing to claim.
  Future<void> _lookup() async {
    final dashboard = context.read<ProviderDashboardProvider>();
    await Future.wait([
      dashboard.loadDashboard(),
      dashboard.loadClaimableListing(),
      dashboard.loadClaim(),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _draft?.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _serviceController.dispose();
    _priceController.dispose();
    _serviceAboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    if (!_ready || _leaving) return _loading();
    if (dashboard.hasProviderProfile && !_joining) {
      // This account already applied, or the team handed it the listing it
      // claimed: its portal shows where it stands (p08 to p12).
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _enterPortal();
      });
      return _loading();
    }
    final claim = dashboard.claim;
    if (claim != null && claim.isPending) {
      return ProviderClaimPendingScreen(
        businessName: claim.businessName,
        sentAt: claim.createdAt,
        onRefresh: _lookup,
        onBack: _leave,
        onSupport: () => context.push(AppRouter.support),
      );
    }
    final listing = dashboard.claimableListing;
    if (listing != null) {
      return ProviderClaimScreen(
        businessName: listing.businessName,
        kind: providerKindLine(
          category: listing.categoryName,
          city: listing.cityName,
        ),
        submitting: dashboard.isSubmitting,
        errorMessage: _claimError,
        refusal: claim != null && claim.isRejected ? claim.note ?? '' : null,
        onBack: _leave,
        onClaim: _claim,
        onSupport: () => context.push(AppRouter.support),
      );
    }
    return _wizard(dashboard);
  }

  Widget _loading() {
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          JourneySubHeader(title: 'طلب الانضمام', onBack: _leave),
          const JourneyListState(
            phase: JourneyListPhase.loading,
            section: JourneySection.home,
          ),
        ],
      ),
    );
  }

  Widget _wizard(ProviderDashboardProvider dashboard) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final children = switch (_step) {
      0 => _businessStep(marketplace),
      1 => _whereStep(marketplace),
      2 => _serviceStep(),
      _ => _sendStep(marketplace, dashboard),
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previous();
      },
      child: AarastScreenFrame(
        maxWidth: 520,
        backgroundColor: AarastV3Color.canvas,
        resizeToAvoidBottomInset: true,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  JourneySubHeader(
                    title: 'طلب الانضمام',
                    onBack: _step == 0 ? _leave : _previous,
                  ),
                  _JoinSteps(labels: _steps, current: _step),
                  const SizedBox(height: 18),
                  ...children,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _step < _steps.length - 1
                  ? JourneyButton(
                      key: const ValueKey('provider-apply-next'),
                      label: 'التالي',
                      expand: true,
                      large: true,
                      onPressed: _next,
                    )
                  : JourneyButton(
                      key: const ValueKey('provider-apply-send'),
                      label: 'أرسل للمراجعة',
                      icon: LucideIcons.send,
                      expand: true,
                      large: true,
                      loading: dashboard.isSubmitting,
                      onPressed: _send,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ p03

  List<Widget> _businessStep(ProviderMarketplaceProvider marketplace) {
    final name = _nameController.text.trim();
    return [
      const _StepTitle('نشاطك'),
      const SizedBox(height: 12),
      JourneyTextField(
        key: const Key('provider-apply-name'),
        label: 'اسم النشاط كما يعرفه الناس',
        controller: _nameController,
        textInputAction: TextInputAction.done,
        errorText: _attempted && name.length < 2 ? 'اكتب اسم نشاطك' : null,
        onChanged: (_) {
          if (_attempted) setState(() {});
        },
      ),
      const SizedBox(height: 10),
      JourneyPickerField(
        key: const Key('provider-apply-category'),
        label: 'القسم',
        value: _categoryName(marketplace),
        icon: LucideIcons.shapes,
        onTap: () => _pickCategory(marketplace),
      ),
      if (_attempted && _categoryName(marketplace) == null)
        const _FieldError('اختر قسمك'),
      ..._referenceTrouble(marketplace, marketplace.categories.isEmpty),
    ];
  }

  // ------------------------------------------------------------ p04

  List<Widget> _whereStep(ProviderMarketplaceProvider marketplace) {
    return [
      const _StepTitle('وين تشتغل؟'),
      const SizedBox(height: 12),
      JourneyPickerField(
        key: const Key('provider-apply-city'),
        label: 'المدينة',
        value: _cityName(marketplace),
        icon: LucideIcons.mapPin,
        onTap: () => _pickCity(marketplace),
      ),
      if (_attempted && _cityName(marketplace) == null)
        const _FieldError('اختر مدينتك'),
      ..._referenceTrouble(marketplace, marketplace.cities.isEmpty),
      const SizedBox(height: 10),
      JourneyTextField(
        key: const Key('provider-apply-address'),
        label: 'مكان المحل (اختياري)',
        controller: _addressController,
        icon: LucideIcons.navigation,
        textInputAction: TextInputAction.done,
      ),
    ];
  }

  // ------------------------------------------------------------ p06

  /// «خدمتك وسعرها» (p06 as D41 keeps it): the one service the review needs,
  /// with its price. Teams are not asked (D41), and packages come after
  /// approval (p36).
  List<Widget> _serviceStep() {
    final title = _serviceController.text.trim();
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    return [
      const _StepTitle(
        'خدمتك وسعرها',
        sub: 'خدمة وحدة بسعرها تكفي للمراجعة. الخدمات الثانية والصور تضيفها بعد الموافقة.',
      ),
      const SizedBox(height: 12),
      JourneyTextField(
        key: const Key('provider-apply-service'),
        label: 'اسم الخدمة',
        hint: 'مثلًا: صور وفيديو للزفاف',
        controller: _serviceController,
        icon: LucideIcons.package,
        textInputAction: TextInputAction.next,
        errorText: _attempted && title.length < 2 ? 'اكتب اسم خدمتك' : null,
        onChanged: (_) {
          if (_attempted) setState(() {});
        },
      ),
      const SizedBox(height: 10),
      JourneyTextField(
        key: const Key('provider-apply-price'),
        label: 'السعر',
        controller: _priceController,
        suffix: 'ر.ي',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.next,
        errorText: _attempted && price <= 0 ? 'اكتب سعر خدمتك' : null,
        onChanged: (_) {
          if (_attempted) setState(() {});
        },
      ),
      const SizedBox(height: 10),
      JourneyTextField(
        key: const Key('provider-apply-service-about'),
        label: 'ايش تشمل (اختياري)',
        hint: 'مثلًا: 300 صورة معدّلة وفيلم 10 دقايق',
        controller: _serviceAboutController,
        textInputAction: TextInputAction.done,
        minLines: 2,
        maxLines: 4,
      ),
      const SizedBox(height: 8),
      Text(
        'الأسعار بالريال اليمني.',
        style: JourneyType.of(JourneyType.small, color: AarastV3Color.textMuted),
      ),
    ];
  }

  // ------------------------------------------------------------ p07

  List<Widget> _sendStep(
    ProviderMarketplaceProvider marketplace,
    ProviderDashboardProvider dashboard,
  ) {
    final hasAddress = _addressController.text.trim().isNotEmpty;
    final error = _sendError;
    return [
      const _StepTitle('كذا بيشوفك العرسان'),
      const SizedBox(height: 12),
      ProviderPreviewCard(
        name: _nameController.text.trim(),
        kind: providerKindLine(
          category: _categoryName(marketplace),
          city: _cityName(marketplace),
        ),
        priceTag: 'من ${providerMoneyLabel(_priceController.text, 'YER')}',
      ),
      const SizedBox(height: 12),
      JourneyBox(
        child: Column(
          children: [
            const ProviderFactRow(
              icon: LucideIcons.checkCircle2,
              text: 'نشاطك ومدينتك',
              color: AarastV3Color.mint,
            ),
            if (hasAddress)
              const ProviderFactRow(
                icon: LucideIcons.checkCircle2,
                text: 'مكان المحل',
                color: AarastV3Color.mint,
              ),
            ProviderFactRow(
              icon: LucideIcons.checkCircle2,
              text: _serviceController.text.trim(),
              color: AarastV3Color.mint,
            ),
            const ProviderFactRow(
              icon: LucideIcons.circle,
              text: 'الصور والخدمات الثانية تضيفها بعد الموافقة',
              color: AarastV3Color.textFaint,
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          'نراجع طلبك ونبلغك هنا.',
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 12),
        JourneyNote(
          key: const Key('provider-apply-error'),
          text: error,
          icon: LucideIcons.alertCircle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
        ),
      ],
    ];
  }

  /// The cities or categories did not load: say so and offer a retry.
  List<Widget> _referenceTrouble(
    ProviderMarketplaceProvider marketplace,
    bool missing,
  ) {
    if (!missing || marketplace.isReferenceDataLoading) return const [];
    if (marketplace.referenceDataErrorMessage == null) return const [];
    return [
      const SizedBox(height: 10),
      const JourneyNote(
        text: 'ما قدرنا نجيب المدن والأقسام. تأكد من النت.',
        icon: LucideIcons.wifiOff,
        color: AarastV3Color.danger,
        soft: AarastV3Color.dangerSoft,
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: JourneyTextAction(
          key: const Key('provider-apply-retry'),
          label: 'حاول مرة ثانية',
          color: AarastV3Color.primary,
          onPressed: marketplace.loadReferenceData,
        ),
      ),
    ];
  }

  String? _categoryName(ProviderMarketplaceProvider marketplace) {
    for (final category in marketplace.categories) {
      if (category.id == _categoryId) return category.nameAr;
    }
    return null;
  }

  String? _cityName(ProviderMarketplaceProvider marketplace) {
    for (final city in marketplace.cities) {
      if (city.id == _cityId) return city.nameAr;
    }
    return null;
  }

  Future<void> _pickCategory(ProviderMarketplaceProvider marketplace) async {
    final picked = await providerPickOption(
      context,
      title: 'القسم',
      keyPrefix: 'provider-apply-option',
      options: [
        for (final category in marketplace.categories)
          (category.id, category.nameAr),
      ],
      current: _categoryId,
    );
    if (picked == null || !mounted) return;
    setState(() => _categoryId = picked);
    _draft?.changed();
  }

  Future<void> _pickCity(ProviderMarketplaceProvider marketplace) async {
    final picked = await providerPickOption(
      context,
      title: 'المدينة',
      keyPrefix: 'provider-apply-option',
      options: [for (final city in marketplace.cities) (city.id, city.nameAr)],
      current: _cityId,
    );
    if (picked == null || !mounted) return;
    setState(() => _cityId = picked);
    _draft?.changed();
  }

  bool _stepValid(ProviderMarketplaceProvider marketplace) => switch (_step) {
    0 =>
      _nameController.text.trim().length >= 2 &&
          _categoryName(marketplace) != null,
    1 => _cityName(marketplace) != null,
    2 =>
      _serviceController.text.trim().length >= 2 &&
          (int.tryParse(_priceController.text.trim()) ?? 0) > 0,
    _ => true,
  };

  void _next() {
    final marketplace = context.read<ProviderMarketplaceProvider>();
    if (!_stepValid(marketplace)) {
      setState(() => _attempted = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _attempted = false;
      _step += 1;
    });
  }

  void _previous() {
    if (_step == 0) return;
    setState(() {
      _attempted = false;
      _sendError = null;
      _step -= 1;
    });
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.home);
    }
  }

  Future<void> _send() async {
    final dashboard = context.read<ProviderDashboardProvider>();
    if (_categoryId == null || _cityId == null) return;
    setState(() => _sendError = null);
    if (await AuthActionGuard.blockProtectedSubmitWithoutAccount(context)) {
      return;
    }
    if (!mounted) return;
    final phone = context.read<AuthController>().user?.phone?.trim() ?? '';
    if (phone.isEmpty) {
      setState(() => _sendError = 'ما لقينا رقم حسابك. سجّل دخولك من جديد.');
      return;
    }
    _joining = true;
    final result = await dashboard.applyProvider(
      businessName: _nameController.text.trim(),
      phone: phone,
      cityId: _cityId!,
      categoryId: _categoryId!,
      serviceTitle: _serviceController.text.trim(),
      servicePrice: _priceController.text.trim(),
      serviceDescription: _serviceAboutController.text,
      address: _addressController.text,
    );
    if (!mounted) return;
    switch (result) {
      case ProviderJoinResult.failed:
        setState(() {
          _joining = false;
          _sendError =
              dashboard.errorMessage ?? 'ما قدرنا نرسل طلبك. جرّب مرة ثانية.';
        });
      case ProviderJoinResult.listingClaimable:
        setState(() => _joining = false);
      case ProviderJoinResult.alreadyApplied:
        await _enterPortal();
      case ProviderJoinResult.sent:
      case ProviderJoinResult.sentWithoutAddress:
        await _draft?.clear();
        if (!mounted) return;
        if (result == ProviderJoinResult.sentWithoutAddress) {
          AarastToast.showInfo(
            context,
            'انرسل طلبك، بس مكان المحل ما انحفظ. تضيفه من «عدّل طلبك».',
          );
        }
        await _enterPortal();
    }
  }

  /// p02: the claim goes to the review team (B-12) and waits there. This
  /// phone remembers it, so the approval is welcomed (p10).
  Future<void> _claim() async {
    final dashboard = context.read<ProviderDashboardProvider>();
    setState(() => _claimError = null);
    final sent = await dashboard.claimListing();
    if (!mounted) return;
    if (!sent) {
      setState(() {
        _claimError =
            dashboard.errorMessage ?? 'ما قدرنا نرسل طلب الاستلام. جرّب مرة ثانية.';
      });
      return;
    }
    final providerId = dashboard.claim?.providerId;
    if (providerId != null && providerId.isNotEmpty) {
      try {
        final ledger = ProviderApprovalLedger(
          await SharedPreferences.getInstance(),
        );
        await ledger.markClaimed(providerId);
      } on Object catch (error) {
        debugPrint('Provider claim not remembered: $error');
      }
    }
  }

  /// The account now has a provider profile: its user and its paths are
  /// read again, the provider path is opened, then its portal.
  Future<void> _enterPortal() async {
    if (mounted) setState(() => _leaving = true);
    final auth = context.read<AuthController>();
    final accountContexts = context.read<AccountContextController>();
    await auth.refreshCurrentUser();
    if (!mounted) return;
    await accountContexts.refresh();
    if (!mounted) return;
    final providerPath = accountContexts.availableContexts
        .where((path) => path.isProvider)
        .firstOrNull;
    if (providerPath != null &&
        accountContexts.selectedContext?.contextKey !=
            providerPath.contextKey) {
      await accountContexts.select(providerPath.contextKey);
      if (!mounted) return;
    }
    context.go(AppRouter.providerDashboard);
  }

  void _configureDraft() {
    if (_draft != null) return;
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope: 'provider:application:new',
      fields: {
        'businessName': _nameController,
        'address': _addressController,
        'serviceTitle': _serviceController,
        'servicePrice': _priceController,
        'serviceAbout': _serviceAboutController,
      },
      readExtras: () => {'cityId': _cityId, 'categoryId': _categoryId},
      restoreExtras: (data) {
        if (!mounted) return;
        setState(() {
          _cityId = data['cityId']?.toString();
          _categoryId = data['categoryId']?.toString();
        });
      },
    );
    unawaited(_draft!.restore());
  }
}
