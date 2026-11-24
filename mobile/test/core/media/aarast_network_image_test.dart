import 'package:aarast_mobile/core/media/aarast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-364: no image in the app set cacheWidth, so a cover of up to 2200px
// was decoded whole (some 13MB) for a card a few hundred pixels wide.

Future<Image> _pump(
  WidgetTester tester,
  Widget image, {
  double ratio = 3,
}) async {
  tester.view.devicePixelRatio = ratio;
  tester.view.physicalSize = Size(400 * ratio, 800 * ratio);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Center(child: image)));
  return tester.widget<Image>(find.byType(Image));
}

void main() {
  testWidgets('an image is decoded at its laid-out width times the ratio', (
    tester,
  ) async {
    final image = await _pump(
      tester,
      const SizedBox(
        width: 120,
        height: 80,
        child: AarastNetworkImage(
          'https://media.example/provider-cover/a.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );
    final resized = image.image as ResizeImage;
    expect(resized.width, 360);
    expect(resized.height, isNull, reason: 'the aspect is kept');
    expect(
      resized.imageProvider,
      const AarastNetworkImageProvider(
        'https://media.example/provider-cover/a.jpg',
      ),
    );
  });

  testWidgets('a given width wins over the room around it', (tester) async {
    final image = await _pump(
      tester,
      const AarastNetworkImage(
        'https://media.example/provider-logo/a.png',
        width: 40,
        height: 40,
        keepOnDisk: false,
      ),
      ratio: 2.75,
    );
    final resized = image.image as ResizeImage;
    expect(resized.width, 110);
    expect(
      (resized.imageProvider as AarastNetworkImageProvider).keepOnDisk,
      isFalse,
    );
  });

  testWidgets('an image that cannot load shows its error widget', (
    tester,
  ) async {
    await _pump(
      tester,
      SizedBox(
        width: 120,
        height: 80,
        child: AarastNetworkImage(
          'https://media.example/provider-cover/a.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Text('fallback'),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('fallback'), findsOneWidget);
  });
}
