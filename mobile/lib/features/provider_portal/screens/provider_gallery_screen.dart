import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show
        PortfolioPhoto,
        ProviderPortfolio,
        portfolioSocialLabel,
        portfolioSocialNetworks;
import '../providers/provider_dashboard_provider.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _galleryThumbWidth = 92.0;

typedef ProviderGalleryImagePicker = Future<List<XFile>> Function();
typedef ProviderGalleryImageUploader =
    Future<MediaUploadTicket> Function(XFile file);

/// p37 «معرض الشغل» (B-16, D62): his photos by album, each new one marked
/// «نراجعها» until the moderation team approves it, a refused one with the
/// team's reason; the women's album «حفلات النساء» for a provider who serves
/// women, shown to brides only and without faces; his TikTok, Instagram and
/// Facebook links (the card p05 draws, kept here since p05's photo step was
/// postponed); and where he works (his city and the shop's place).
class ProviderGalleryScreen extends StatefulWidget {
  const ProviderGalleryScreen({this.pickImages, this.uploadImage, super.key});

  final ProviderGalleryImagePicker? pickImages;
  final ProviderGalleryImageUploader? uploadImage;

  @override
  State<ProviderGalleryScreen> createState() => _ProviderGalleryScreenState();
}

class _ProviderGalleryScreenState extends State<ProviderGalleryScreen> {
  static const _maximumImagesPerSelection = 10;

  String? _album;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProviderDashboardProvider>().loadPortfolio();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final portfolio = dashboard.portfolio;
    final profile = dashboard.profile;
    final city = profile?.city?.nameAr.trim() ?? '';
    final address = profile?.address?.trim() ?? '';
    final shown = portfolio?.items.where((item) => !item.isRejected).length;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: AarastV3Color.primary,
        onRefresh: dashboard.loadPortfolio,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AarastV3Density.pageInsets,
          children: [
            JourneySubHeader(
              title: 'معرض الشغل',
              subtitle: shown == null
                  ? null
                  : shown == 0
                  ? 'ما فيه صور لسا'
                  : arabicCount(
                      shown,
                      one: 'صورة وحدة',
                      two: 'صورتين',
                      few: 'صور',
                      many: 'صورة',
                    ),
            ),
            if (portfolio == null)
              JourneyListState(
                key: const Key('provider-gallery-state'),
                phase: dashboard.portfolioError == null
                    ? JourneyListPhase.loading
                    : JourneyListPhase.error,
                section: JourneySection.home,
                onRetry: dashboard.loadPortfolio,
              )
            else
              ..._gallery(context, dashboard, portfolio),
            if (city.isNotEmpty || address.isNotEmpty) ...[
              JourneySectionTitle(
                'التغطية',
                action: dashboard.canManageProviderProfile ? 'عدّل' : null,
                onAction: () => context.push(AppRouter.providerProfileEdit),
              ),
              JourneyBox(
                key: const Key('provider-gallery-coverage'),
                padding: const EdgeInsets.all(AarastV3Space.x3),
                child: Column(
                  children: [
                    if (city.isNotEmpty) _Fact(label: 'المدينة', value: city),
                    if (address.isNotEmpty)
                      _Fact(label: 'المحل', value: address),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _gallery(
    BuildContext context,
    ProviderDashboardProvider dashboard,
    ProviderPortfolio portfolio,
  ) {
    final albums = _albums(portfolio);
    final selected = albums.contains(_album)
        ? _album
        : (albums.isEmpty ? null : albums.first);
    final photos = [
      for (final item in portfolio.items)
        if (albums.isEmpty || item.album == selected) item,
    ];
    final linked = [
      for (final network in portfolioSocialNetworks)
        if (portfolio.socialLinks[network] != null)
          portfolioSocialLabel(network),
    ];
    return [
      if (albums.isNotEmpty) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final album in albums)
              JourneyChip(
                key: Key('provider-gallery-album-$album'),
                label: album,
                selected: album == selected,
                onTap: () => setState(() => _album = album),
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x3),
      ],
      if (photos.isNotEmpty) ...[
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final photo in photos)
              _Photo(
                key: Key('provider-gallery-photo-${photo.id}'),
                photo: photo,
                onTap: _busy ? null : () => _openPhoto(portfolio, photo),
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x3),
      ] else if (selected != null && selected == portfolio.womenAlbum) ...[
        JourneyNote(
          icon: LucideIcons.image,
          text: 'ما فيه صور في «${portfolio.womenAlbum}» لسا.',
        ),
        const SizedBox(height: AarastV3Space.x3),
      ],
      if (portfolio.items.length < portfolio.maxItems)
        JourneyButton(
          key: const Key('provider-gallery-add'),
          label: _busy ? 'نرفع الصور…' : 'أضف صور',
          icon: LucideIcons.imagePlus,
          background: AarastV3Color.primarySoft,
          foreground: AarastV3Color.primary,
          expand: true,
          loading: _busy,
          onPressed: () => _addImages(portfolio, selected),
        ),
      const SizedBox(height: AarastV3Space.x3),
      JourneyNote(
        key: const Key('provider-gallery-review-note'),
        icon: LucideIcons.eyeOff,
        color: AarastV3Color.danger,
        soft: AarastV3Color.dangerSoft,
        text: portfolio.servesWomen
            ? 'ألبوم «${portfolio.womenAlbum}» يظهر للعرائس بس، وبدون وجوه. '
                  'كل صورة جديدة نراجعها قبل ما تظهر.'
            : 'كل صورة جديدة نراجعها قبل ما تظهر.',
      ),
      const SizedBox(height: AarastV3Space.x3),
      JourneyBox(
        key: const Key('provider-gallery-links'),
        padding: const EdgeInsets.all(AarastV3Space.x3),
        child: Row(
          children: [
            const JourneyIconTile(
              icon: LucideIcons.music2,
              color: AarastV3Color.primary,
              soft: AarastV3Color.primarySoft,
              size: 40,
            ),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اربط تيك توك أو إنستغرام',
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  Text(
                    linked.isEmpty
                        ? 'يظهر كمعرض شغلك، بدون ما ترفع كل شيء'
                        : 'مربوط: ${linked.join('، ')}',
                    style: JourneyType.of(
                      JourneyType.detail,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            JourneyTextAction(
              key: const Key('provider-gallery-links-edit'),
              label: linked.isEmpty ? 'اربط' : 'عدّل',
              onPressed: _busy ? null : () => _editLinks(portfolio),
            ),
          ],
        ),
      ),
    ];
  }

  /// The albums he uses, then the women's album when he serves women.
  List<String> _albums(ProviderPortfolio portfolio) => {
    ...portfolio.albums,
    if (portfolio.servesWomen) portfolio.womenAlbum,
  }.toList();

  List<Map<String, Object?>> _itemsOf(Iterable<PortfolioPhoto> photos) => [
    for (final photo in photos)
      {'key': photo.key, 'album': photo.album, 'noFaces': photo.noFaces},
  ];

  Future<void> _save(
    List<Map<String, Object?>> items, {
    Map<String, String>? socialLinks,
    required String success,
  }) async {
    final dashboard = context.read<ProviderDashboardProvider>();
    final saved = await dashboard.savePortfolio(
      items: items,
      socialLinks: socialLinks,
    );
    if (!mounted) return;
    if (saved) {
      AarastToast.showSuccess(context, success);
    } else {
      AarastToast.showError(
        context,
        dashboard.portfolioError ?? 'ما انحفظ معرضك، جرب مرة ثانية.',
      );
    }
  }

  /// A photo opens large with its state and «احذف الصورة».
  Future<void> _openPhoto(
    ProviderPortfolio portfolio,
    PortfolioPhoto photo,
  ) async {
    final remove = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: photo.album ?? 'معرض الشغل',
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AarastV3Radius.card),
            child: AspectRatio(
              aspectRatio: 1,
              child: photo.imageUrl == null
                  ? const ColoredBox(color: AarastV3Color.line)
                  : Image.network(
                      photo.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AarastV3Color.line),
                    ),
            ),
          ),
          const SizedBox(height: AarastV3Space.x3),
          JourneyNote(
            key: const Key('provider-gallery-photo-state'),
            icon: photo.isRejected ? LucideIcons.xCircle : LucideIcons.eye,
            color: photo.isRejected ? AarastV3Color.danger : null,
            soft: photo.isRejected ? AarastV3Color.dangerSoft : null,
            text: photo.isRejected
                ? 'ما انقبلت: ${photo.rejectionReason ?? ''}'
                : photo.isPending
                ? 'نراجعها، وما تظهر للعرسان لين نقبلها.'
                : photo.forWomen
                ? 'تظهر للعرائس بس.'
                : 'تظهر في ملفك للعرسان.',
          ),
          const SizedBox(height: AarastV3Space.x3),
          JourneyButton(
            key: const Key('provider-gallery-photo-delete'),
            label: 'احذف الصورة',
            icon: LucideIcons.trash2,
            background: AarastV3Color.dangerSoft,
            foreground: AarastV3Color.danger,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _save(
        _itemsOf(portfolio.items.where((item) => item.id != photo.id)),
        success: 'انحذفت الصورة.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Where the new photos go: an album he uses, the women's album with his
  /// «بدون وجوه», or a new one.
  Future<({String? album, bool noFaces})?> _chooseAlbum(
    ProviderPortfolio portfolio,
    String? selected,
  ) => showJourneySheet<({String? album, bool noFaces})>(
    context: context,
    builder: (_) => _AlbumSheet(
      albums: _albums(portfolio),
      womenAlbum: portfolio.womenAlbum,
      selected: selected,
    ),
  );

  Future<void> _addImages(ProviderPortfolio portfolio, String? selected) async {
    final place = await _chooseAlbum(portfolio, selected);
    if (place == null || !mounted) return;
    late final List<XFile> files;
    try {
      files =
          await (widget.pickImages?.call() ??
              ImagePicker().pickMultiImage(
                imageQuality: 84,
                maxWidth: 2000,
                limit: _maximumImagesPerSelection,
              ));
    } catch (_) {
      if (mounted) {
        AarastToast.showError(
          context,
          'ما قدرنا نفتح الصور. تأكد من الإذن وجرب مرة ثانية.',
        );
      }
      return;
    }
    if (files.isEmpty || !mounted) return;
    final room = portfolio.maxItems - portfolio.items.length;
    final chosen = files
        .take(
          room < _maximumImagesPerSelection ? room : _maximumImagesPerSelection,
        )
        .toList();
    setState(() => _busy = true);
    final keys = <String>[];
    String? lastError;
    try {
      final upload =
          widget.uploadImage ??
          (XFile file) => context.read<MediaUploadApi>().uploadImage(
            file: file,
            purpose: 'provider-portfolio',
          );
      for (final file in chosen) {
        try {
          keys.add((await upload(file)).key);
        } on ApiException catch (error) {
          lastError = error.message;
          if (error.statusCode != null && error.statusCode! >= 500) break;
        } catch (_) {
          lastError = 'ما قدرنا نرفع صورة منها.';
        }
        if (!mounted) return;
      }
      if (keys.isEmpty) {
        AarastToast.showError(
          context,
          lastError ?? 'ما قدرنا نرفع الصور، جرب مرة ثانية.',
        );
        return;
      }
      await _save(
        [
          ..._itemsOf(portfolio.items),
          for (final key in keys)
            {'key': key, 'album': place.album, 'noFaces': place.noFaces},
        ],
        success: keys.length == chosen.length
            ? 'وصلتنا ${arabicCount(keys.length, one: 'صورة وحدة', two: 'صورتين', few: 'صور', many: 'صورة')}، نراجعها قبل ما تظهر.'
            : 'وصلتنا ${keys.length} من ${chosen.length} صور، نراجعها قبل ما تظهر.',
      );
      if (mounted) setState(() => _album = place.album);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// His TikTok, Instagram and Facebook links (empty removes one).
  Future<void> _editLinks(ProviderPortfolio portfolio) async {
    final links = await showJourneySheet<Map<String, String>>(
      context: context,
      builder: (_) => _LinksSheet(links: portfolio.socialLinks),
    );
    if (links == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _save(
        _itemsOf(portfolio.items),
        socialLinks: links,
        success: 'انحفظت روابطك.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// «وين تحط الصور؟»: an album he uses, the women's album with his
/// «بدون وجوه», or a new one. It owns its field, so the field outlives the
/// sheet's closing.
class _AlbumSheet extends StatefulWidget {
  const _AlbumSheet({
    required this.albums,
    required this.womenAlbum,
    required this.selected,
  });

  final List<String> albums;
  final String womenAlbum;
  final String? selected;

  @override
  State<_AlbumSheet> createState() => _AlbumSheetState();
}

class _AlbumSheetState extends State<_AlbumSheet> {
  final _name = TextEditingController();
  late String? _album = widget.selected;
  bool _noFaces = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final named = _name.text.trim();
    final chosen = named.isNotEmpty ? named : _album;
    final forWomen = chosen == widget.womenAlbum;
    final ready = chosen != null && (!forWomen || _noFaces);
    return JourneySheetBody(
      title: 'وين تحط الصور؟',
      children: [
        if (widget.albums.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in widget.albums)
                JourneyChip(
                  key: Key('provider-gallery-pick-$name'),
                  label: name,
                  selected: named.isEmpty && name == _album,
                  onTap: () => setState(() {
                    _album = name;
                    _name.clear();
                  }),
                ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        JourneyTextField(
          key: const Key('provider-gallery-new-album'),
          label: 'أو ألبوم جديد',
          hint: 'الزفة، الدرون…',
          controller: _name,
          maxLength: 30,
          onChanged: (_) => setState(() {}),
        ),
        if (forWomen) ...[
          const SizedBox(height: AarastV3Space.x2),
          JourneyListRow(
            key: const Key('provider-gallery-no-faces'),
            icon: LucideIcons.eyeOff,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
            title: 'أأكد إن الصور بدون وجوه',
            subtitle: 'الكوشة، والزينة، والنقش، والفستان من الخلف',
            trailing: JourneyToggle(
              value: _noFaces,
              onChanged: (value) => setState(() => _noFaces = value),
              color: AarastV3Color.danger,
              semanticLabel: 'الصور بدون وجوه',
            ),
            onTap: () => setState(() => _noFaces = !_noFaces),
          ),
        ],
        const SizedBox(height: AarastV3Space.x3),
        JourneyButton(
          key: const Key('provider-gallery-choose'),
          label: 'اختر الصور',
          icon: LucideIcons.imagePlus,
          expand: true,
          onPressed: ready
              ? () => Navigator.of(
                  context,
                ).pop((album: chosen, noFaces: forWomen && _noFaces))
              : null,
        ),
      ],
    );
  }
}

/// His TikTok, Instagram and Facebook links; an empty field removes one.
class _LinksSheet extends StatefulWidget {
  const _LinksSheet({required this.links});

  final Map<String, String> links;

  @override
  State<_LinksSheet> createState() => _LinksSheetState();
}

class _LinksSheetState extends State<_LinksSheet> {
  late final _fields = {
    for (final network in portfolioSocialNetworks)
      network: TextEditingController(text: widget.links[network] ?? ''),
  };

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return JourneySheetBody(
      title: 'روابط شغلك',
      subtitle: 'رابط حسابك، يبدأ بـ https',
      children: [
        for (final network in portfolioSocialNetworks) ...[
          JourneyTextField(
            key: Key('provider-gallery-link-$network'),
            label: portfolioSocialLabel(network),
            hint: switch (network) {
              'tiktok' => 'https://www.tiktok.com/@اسمك',
              'instagram' => 'https://www.instagram.com/اسمك',
              _ => 'https://www.facebook.com/اسمك',
            },
            controller: _fields[network]!,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: AarastV3Space.x2),
        ],
        JourneyButton(
          key: const Key('provider-gallery-links-save'),
          label: 'احفظ الروابط',
          expand: true,
          onPressed: () => Navigator.of(context).pop({
            for (final entry in _fields.entries)
              entry.key: entry.value.text.trim(),
          }),
        ),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.photo, required this.onTap, super.key});

  final PortfolioPhoto photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onTap,
      semanticLabel: photo.isRejected
          ? 'صورة ما انقبلت'
          : photo.isPending
          ? 'صورة نراجعها'
          : 'صورة',
      borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      child: ColoredBox(
        color: AarastV3Color.line,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo.imageUrl != null)
              Image.network(
                photo.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
            if (photo.isPending || photo.isRejected)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(AarastV3Space.x1),
                  child: photo.isPending
                      ? const JourneyTag(
                          label: 'نراجعها',
                          color: AarastV3Color.brandAccentStrong,
                          soft: AarastV3Color.brandAccentSoft,
                        )
                      : const JourneyTag(
                          label: 'ما انقبلت',
                          color: AarastV3Color.danger,
                          soft: AarastV3Color.dangerSoft,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «المدينة   صنعاء» (prototype `kv`).
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _galleryThumbWidth,
            child: Text(
              label,
              style: JourneyType.of(
                JourneyType.detail,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
            ),
          ),
        ],
      ),
    );
  }
}
