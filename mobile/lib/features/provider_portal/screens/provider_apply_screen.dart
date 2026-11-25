import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/diagnostics/app_logger.dart' show appDebugNote;
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/media/aarast_network_image.dart';
import '../../../core/media/media_upload_api.dart' show MediaUploadTicket;
import '../../../core/push/push_notifications_controller.dart'
    show PushPermissionReason;
import '../../../core/push/push_permission_moment.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthActionGuard, AuthController;
import '../../marketplace/marketplace_api.dart'
    show ProviderMarketplaceProvider;
import '../data/provider_approval_ledger.dart';
import '../data/provider_text_limits.dart';
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_join_parts.dart';
import '../widgets/provider_photo_upload.dart';
import '../widgets/provider_request_parts.dart' show providerMoneyLabel;
import 'provider_claim_screen.dart';
import '../../../core/forms/latin_digits_formatter.dart';

part 'provider_apply_screen.steps.dart';

/// The joining, after the account (p01): a listing under this phone is
/// claimed through the review team (p02, then its waiting state, B-12);
/// otherwise five steps, p03 «نشاطك», p04 «وين تشتغل؟», p05 «صور من
/// شغلك», p06 «خدمتك وسعرها» and p07 «كذا بيشوفك العرسان».
///
/// Apply creates the provider as PENDING at once (F1), so the steps are kept
/// on the phone and sent together from p07 with the one priced service the
/// review needs (B-10, D41) and at least three work photos (Q-59, D127),
/// uploaded as they are picked and sent by their keys; the photos are not
/// kept in the draft, since an upload not sent is cleared. The way of
/// working (p05b) comes after V1, and the other services after approval, so
/// they are not asked.
class ProviderApplyScreen extends StatefulWidget {
  const ProviderApplyScreen({this.pickImages, this.uploadImage, super.key});

  /// p05's photos: the phone's own picker and upload unless a test passes
  /// its own.
  final ProviderPhotoPicker? pickImages;
  final ProviderPhotoUploader? uploadImage;

  @override
  State<ProviderApplyScreen> createState() => _ProviderApplyScreenState();
}

class _ProviderApplyScreenState extends State<ProviderApplyScreen> {
  static const _steps = ['نشاطك', 'فين', 'صورك', 'خدمتك', 'أرسل'];

  /// The photos one application takes; more go to «معرض الشغل» after
  /// approval.
  static const _photosMax = providerPhotosPerPick;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _serviceController = TextEditingController();
  final _priceController = TextEditingController();
  final _serviceAboutController = TextEditingController();
  String? _cityId;
  String? _categoryId;

  /// p05: the photos uploaded so far, in his order.
  final _photos = <MediaUploadTicket>[];
  bool _uploading = false;
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
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
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
      2 => _photosStep(marketplace),
      3 => _serviceStep(),
      _ => _sendStep(marketplace, dashboard),
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previous();
      },
      child: AarastScreenFrame(
        backgroundColor: AarastV3Color.canvas,
        resizeToAvoidBottomInset: true,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: AarastV3Density.pageInsets,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  JourneySubHeader(
                    title: 'طلب الانضمام',
                    onBack: _step == 0 ? _leave : _previous,
                  ),
                  // D75: the code was for a number that already had an
                  // account; the joining goes on from that same account.
                  if (_step == 0 &&
                      context.watch<AuthController>().signUpFoundAccount) ...[
                    const JourneyNote(
                      key: ValueKey('provider-apply-existing-account'),
                      text:
                          'هذا الرقم عليه حساب في اعّرست. الدخول تم بنفس الحساب، وطلب الانضمام كمزود يكمل منه.',
                      icon: LucideIcons.info,
                      tone: JourneyNoteTone.paper,
                    ),
                    const SizedBox(height: AarastV3Space.x3),
                  ],
                  _JoinSteps(labels: _steps, current: _step),
                  const SizedBox(height: AarastV3Space.x4),
                  ...children,
                ],
              ),
            ),
            Padding(
              padding: AarastV3Density.actionInsets,
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
                      label: 'إرسال للمراجعة',
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
      const SizedBox(height: AarastV3Space.x3),
      JourneyTextField(
        key: const Key('provider-apply-name'),
        label: 'اسم النشاط كما يعرفه الناس',
        controller: _nameController,
        textInputAction: TextInputAction.done,
        maxLength: providerTitleMax,
        errorText: _attempted && name.length < 2 ? 'اكتب اسم نشاطك' : null,
        onChanged: (_) {
          if (_attempted) setState(() {});
        },
      ),
      const SizedBox(height: AarastV3Space.x2),
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
      const _StepTitle('فين تشتغل؟'),
      const SizedBox(height: AarastV3Space.x3),
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
      const SizedBox(height: AarastV3Space.x2),
      JourneyTextField(
        key: const Key('provider-apply-address'),
        label: 'مكان المحل (اختياري)',
        controller: _addressController,
        icon: LucideIcons.navigation,
        textInputAction: TextInputAction.done,
        maxLength: providerAddressMax,
      ),
    ];
  }

  // ------------------------------------------------------------ p05

  /// «صور من شغلك» (p05, Q-59): at least three photos go to review with the
  /// application, each uploaded as it is picked. The team reviews them, and
  /// no customer sees one before the profile is approved. A women's party
  /// photo shows no face (D62): said to a provider whose section brides see.
  List<Widget> _photosStep(ProviderMarketplaceProvider marketplace) {
    final count = _photos.length;
    final missing = providerApplicationMinPhotos - count;
    final servesWomen = marketplace.categories
        .where((category) => category.id == _categoryId)
        .any((category) => category.showForBride);
    return [
      const _StepTitle(
        'صور من شغلك',
        sub:
            'ثلاث صور على الأقل من أعراس اشتغلتها. نراجعها مع طلبك، وما يشوفها العرسان قبل ما نوافق.',
      ),
      const SizedBox(height: AarastV3Space.x3),
      Text(
        count <= providerApplicationMinPhotos
            ? '$count من $providerApplicationMinPhotos'
            : _photoCount(count),
        key: const Key('provider-apply-photos-count'),
        style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
      ),
      if (count > 0) ...[
        const SizedBox(height: AarastV3Space.x2),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AarastV3Space.x2,
          crossAxisSpacing: AarastV3Space.x2,
          children: [
            for (final photo in _photos)
              _ApplyPhoto(
                key: Key('provider-apply-photo-${photo.key}'),
                photo: photo,
                onRemove: _uploading ? null : () => _removePhoto(photo),
              ),
          ],
        ),
      ],
      const SizedBox(height: AarastV3Space.x3),
      if (count < _photosMax)
        JourneyButton(
          key: const Key('provider-apply-photos-add'),
          label: _uploading ? 'نرفع الصور…' : 'أضف صور',
          icon: LucideIcons.imagePlus,
          background: AarastV3Color.primarySoft,
          foreground: AarastV3Color.primary,
          expand: true,
          loading: _uploading,
          onPressed: _addPhotos,
        ),
      if (_attempted && missing > 0)
        _FieldError('باقي ${_photoCount(missing)}'),
      if (servesWomen) ...[
        const SizedBox(height: AarastV3Space.x3),
        const JourneyNote(
          icon: LucideIcons.eyeOff,
          text: 'صور حفلات النساء تكون بدون وجوه.',
        ),
      ],
    ];
  }

  static String _photoCount(int count) => arabicCount(
    count,
    one: 'صورة وحدة',
    two: 'صورتين',
    few: 'صور',
    many: 'صورة',
  );

  Future<void> _addPhotos() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final uploads = await pickAndUploadProviderPhotos(
        context,
        room: _photosMax - _photos.length,
        pick: widget.pickImages,
        upload: widget.uploadImage,
      );
      if (uploads == null || !mounted) return;
      setState(() => _photos.addAll(uploads.tickets));
      if (!uploads.complete) {
        AarastToast.showInfo(
          context,
          'رفعنا ${uploads.tickets.length} من ${uploads.asked} صور، وتقدر تضيف الباقي.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removePhoto(MediaUploadTicket photo) {
    setState(() => _photos.remove(photo));
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
        sub:
            'خدمة وحدة بسعرها تكفي للمراجعة. الخدمات الثانية تضيفها بعد الموافقة.',
      ),
      const SizedBox(height: AarastV3Space.x3),
      JourneyTextField(
        key: const Key('provider-apply-service'),
        label: 'اسم الخدمة',
        hint: 'مثلًا: صور وفيديو للزفاف',
        controller: _serviceController,
        icon: LucideIcons.package,
        textInputAction: TextInputAction.next,
        maxLength: providerTitleMax,
        errorText: _attempted && title.length < 2 ? 'اكتب اسم خدمتك' : null,
        onChanged: (_) {
          if (_attempted) setState(() {});
        },
      ),
      const SizedBox(height: AarastV3Space.x2),
      JourneyTextField(
        key: const Key('provider-apply-price'),
        label: 'السعر',
        controller: _priceController,
        suffix: 'ر.ي',
        keyboardType: TextInputType.number,
        inputFormatters: [LatinDigitsFormatter()],
        textInputAction: TextInputAction.next,
        errorText: _attempted && price <= 0 ? 'اكتب سعر خدمتك' : null,
        onChanged: (_) {
          if (_attempted) setState(() {});
        },
      ),
      const SizedBox(height: AarastV3Space.x2),
      JourneyTextField(
        key: const Key('provider-apply-service-about'),
        label: 'ايش تشمل (اختياري)',
        hint: 'مثلًا: 300 صورة معدّلة وفيلم 10 دقايق',
        controller: _serviceAboutController,
        textInputAction: TextInputAction.done,
        minLines: 2,
        maxLines: 4,
        maxLength: providerDescriptionMax,
      ),
      const SizedBox(height: AarastV3Space.x2),
      Text(
        'الأسعار بالريال اليمني.',
        style: JourneyType.of(
          JourneyType.small,
          color: AarastV3Color.textMuted,
        ),
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
      const SizedBox(height: AarastV3Space.x3),
      ProviderPreviewCard(
        name: _nameController.text.trim(),
        kind: providerKindLine(
          category: _categoryName(marketplace),
          city: _cityName(marketplace),
        ),
        priceTag: 'من ${providerMoneyLabel(_priceController.text, 'YER')}',
      ),
      const SizedBox(height: AarastV3Space.x3),
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
              text: '${_photoCount(_photos.length)} من شغلك',
              color: AarastV3Color.mint,
            ),
            ProviderFactRow(
              icon: LucideIcons.checkCircle2,
              text: _serviceController.text.trim(),
              color: AarastV3Color.mint,
            ),
            const ProviderFactRow(
              icon: LucideIcons.circle,
              text: 'الخدمات الثانية تضيفها بعد الموافقة',
              color: AarastV3Color.textFaint,
            ),
          ],
        ),
      ),
      const SizedBox(height: AarastV3Space.x2),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.half),
        child: Text(
          'نراجع طلبك، و$providerDecisionNoticeLine',
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: AarastV3Space.x3),
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
      const SizedBox(height: AarastV3Space.x2),
      const JourneyNote(
        text: 'ما قدرنا نجيب المدن والأقسام. يمكن النت مقطوع.',
        icon: LucideIcons.wifiOff,
        color: AarastV3Color.danger,
        soft: AarastV3Color.dangerSoft,
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: JourneyTextAction(
          key: const Key('provider-apply-retry'),
          label: 'جرّب مرة ثانية',
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
    2 => !_uploading && _photos.length >= providerApplicationMinPhotos,
    3 =>
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
    // The existing-account note was read on the first step: said once.
    context.read<AuthController>().acknowledgeSignUpFoundAccount();
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
    context.read<AuthController>().acknowledgeSignUpFoundAccount();
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
      setState(() => _sendError = 'ما لقينا رقم حسابك. الدخول من جديد يحلّها.');
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
      photoKeys: [for (final photo in _photos) photo.key],
      serviceDescription: _serviceAboutController.text,
      address: _addressController.text,
    );
    if (!mounted) return;
    switch (result) {
      case ProviderJoinResult.failed:
        setState(() {
          _joining = false;
          _sendError =
              dashboard.errorMessage ??
              'ما قدرنا نرسل طلبك. مرة ثانية غالبًا تمشي.';
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
            // The button's own words (critique ب3 made them «تعديل طلبك»).
            'انرسل طلبك، بس مكان المحل ما انحفظ. تضيفه من «تعديل طلبك».',
          );
        }
        await _enterPortal(explainAlerts: true);
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
            dashboard.errorMessage ??
            'ما قدرنا نرسل طلب الاستلام. مرة ثانية غالبًا تمشي.';
      });
      return;
    }
    // A claim waits on the team's decision as an application does; the
    // page stays on its waiting state, where the sheet opens.
    context.reachPushPermissionMoment(reason: PushPermissionReason.provider);
    final providerId = dashboard.claim?.providerId;
    if (providerId != null && providerId.isNotEmpty) {
      try {
        final ledger = ProviderApprovalLedger(
          await SharedPreferences.getInstance(),
        );
        await ledger.markClaimed(providerId);
      } on Object catch (error) {
        appDebugNote('Provider claim not remembered: $error');
      }
    }
  }

  /// The account now has a provider profile: its user and its paths are
  /// read again, the provider path is opened, then its portal. An
  /// application just sent is the provider's reason to say what the alerts
  /// are for (RA-MO-360: the team's decision, the new requests); it is
  /// reached with the move, so the sheet opens on the portal.
  Future<void> _enterPortal({bool explainAlerts = false}) async {
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
    if (explainAlerts) {
      context.reachPushPermissionMoment(
        reason: PushPermissionReason.provider,
      );
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
