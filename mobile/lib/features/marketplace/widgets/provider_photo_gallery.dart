import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

void showProviderPhotoGallery(
  BuildContext context, {
  required List<String> images,
  required int initialIndex,
}) {
  if (images.isEmpty) return;
  showDialog<void>(
    context: context,
    barrierColor: AppTheme.ink.withValues(alpha: 0.92),
    builder: (_) =>
        _ProviderPhotoGallery(images: images, initialIndex: initialIndex),
  );
}

class _ProviderPhotoGallery extends StatefulWidget {
  const _ProviderPhotoGallery({
    required this.images,
    required this.initialIndex,
  });

  final List<String> images;
  final int initialIndex;

  @override
  State<_ProviderPhotoGallery> createState() => _ProviderPhotoGalleryState();
}

class _ProviderPhotoGalleryState extends State<_ProviderPhotoGallery> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleryHeight = (MediaQuery.sizeOf(context).height * 0.76)
        .clamp(300.0, 720.0)
        .toDouble();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: galleryHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        child: Image.network(
                          widget.images[index],
                          key: ValueKey('provider-gallery-photo-$index'),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) =>
                              const SizedBox(
                                height: 200,
                                child: Center(
                                  child: Icon(
                                    LucideIcons.image,
                                    color: AppTheme.gold,
                                    size: 44,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 8,
              start: 8,
              child: Material(
                color: AppTheme.ink.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 8,
              end: 8,
              child: Material(
                color: AppTheme.surface,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'إغلاق معرض الصور',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, color: AppTheme.burgundy),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
