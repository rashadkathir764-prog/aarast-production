// Shared font loader for golden/preview tests.
//
// The per-file loaders historically registered only the Arabic text fonts and
// the Lucide icon font, so every Material `Icons.*` glyph rendered as an empty
// tofu box in the golden PNGs (favorite hearts, add buttons, chevrons...).
// That made the previews look broken even though the running app is fine.
//
// This loads *every* family declared in the app's FontManifest.json — which,
// because `uses-material-design: true`, includes the Flutter-bundled
// MaterialIcons font as well as the app + package fonts — so previews render
// exactly what a device shows.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _loaded = false;

/// Registers all app + Material + package fonts for faithful golden rendering.
/// Safe to call from multiple `setUpAll`s; the work runs at most once.
Future<void> loadPreviewAppFonts() async {
  if (_loaded) return;

  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }

  _loaded = true;
}
