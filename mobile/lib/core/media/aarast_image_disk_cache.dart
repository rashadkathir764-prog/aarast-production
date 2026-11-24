import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../diagnostics/app_logger.dart';

/// An image's bytes and its server's `Cache-Control`.
typedef AarastFetchedImage = ({Uint8List bytes, String? cacheControl});

/// How an image is downloaded; [fetchImageOverHttp], tests pass their own.
typedef AarastImageFetch = Future<AarastFetchedImage> Function(Uri url);

final _httpClient = HttpClient()..autoUncompress = false;

/// Downloads [url] as `Image.network` did: one shared client, the body
/// whole, anything but 200 a failure.
Future<AarastFetchedImage> fetchImageOverHttp(Uri url) async {
  final request = await _httpClient.getUrl(url);
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    await response.drain<List<int>>(<int>[]);
    throw HttpException('The image answered ${response.statusCode}', uri: url);
  }
  final bytes = await consolidateHttpClientResponseBytes(response);
  return (
    bytes: bytes,
    cacheControl: response.headers.value(HttpHeaders.cacheControlHeader),
  );
}

/// The images the app has drawn, kept on the phone between runs
/// (RA-MO-364): `Image.network` kept them in memory only, so every start
/// downloaded every cover and logo again, on a connection that costs.
///
/// An image is fetched with the platform's HTTP client, the one under the
/// app's Dio and the one `Image.network` used (with no account header: a
/// public address needs none and a signed one carries its own), and kept
/// under the hash of its address. What its server marks `no-store` (a
/// signed read of a chat photo or a receipt) is never kept, and neither is
/// what the caller asks not to keep. The least recently read are dropped
/// once the whole passes [maxBytes].
///
/// Nothing is read from or written to the phone before [open] has listed
/// what is kept; until then every image comes from the network.
class AarastImageDiskCache {
  AarastImageDiskCache({
    required Future<Directory> Function() directory,
    AarastImageFetch? fetch,
    this.maxBytes = 100 * 1024 * 1024,
  }) : _directory = directory,
       _fetch = fetch ?? fetchImageOverHttp;

  /// The app's: under the temporary directory the platform gives the app
  /// (its cache directory on Android and iOS), which the system may empty
  /// when it needs the space.
  static final instance = AarastImageDiskCache(
    directory: () async =>
        Directory('${Directory.systemTemp.path}/aarast_images'),
  );

  final Future<Directory> Function() _directory;
  final AarastImageFetch _fetch;
  final int maxBytes;
  Directory? _root;
  Future<void>? _opening;
  Future<void>? _trimming;

  /// The names of the images kept, once [open] listed them.
  Set<String>? _kept;

  /// Lists what is kept, and drops the oldest past [maxBytes]. The app
  /// calls it once at its start, without waiting for it.
  Future<void> open() => _opening ??= () async {
    try {
      final root = await _directory();
      await root.create(recursive: true);
      final kept = <String>{};
      await for (final entity in root.list()) {
        if (entity is! File) continue;
        if (entity.path.endsWith('.part')) {
          // A write cut off on an earlier run.
          await entity.delete();
          continue;
        }
        kept.add(entity.uri.pathSegments.last);
      }
      _root = root;
      _kept = kept;
    } on FileSystemException catch (error, stackTrace) {
      // No place on the phone: every image comes from the network, as it
      // did before the cache.
      appLogEvent(
        'IMAGE_DISK_CACHE_OPEN_FAILED',
        category: AppLogCategory.cache,
        level: AppLogLevel.warning,
        source: 'AarastImageDiskCache',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    await trim();
  }();

  /// The image at [url]: from the phone when it was kept, otherwise
  /// downloaded, and kept when [keep] and its server allows it.
  Future<Uint8List> load(String url, {required bool keep}) async {
    final name = _nameOf(url);
    final root = _root;
    if (keep && root != null && (_kept?.contains(name) ?? false)) {
      final file = File('${root.path}/$name');
      try {
        final bytes = await file.readAsBytes();
        // Read most recently: the last to be dropped.
        unawaited(_touch(file));
        return bytes;
      } on FileSystemException {
        // The system emptied the cache since it was listed: fetched again.
        _kept?.remove(name);
      }
    }
    final fetched = await _fetch(Uri.parse(url));
    if (fetched.bytes.isEmpty) {
      throw StateError('The image at $url came back empty');
    }
    final mayStore = !(fetched.cacheControl ?? '').toLowerCase().contains(
      'no-store',
    );
    if (keep && root != null && mayStore) {
      await _keep(root, name, fetched.bytes);
    }
    return fetched.bytes;
  }

  /// Drops what is kept for [url] (it did not decode).
  Future<void> evict(String url) async {
    final name = _nameOf(url);
    final root = _root;
    if (root == null || !(_kept?.remove(name) ?? false)) return;
    final file = File('${root.path}/$name');
    if (await file.exists()) await file.delete();
  }

  /// Drops the least recently read images until the whole fits [maxBytes].
  Future<void> trim() => _trimming ??= _trim()
      .catchError((Object error, StackTrace stackTrace) {
        // The system may empty the cache directory while it is read; what
        // is gone needs no dropping, and the next trim lists it again.
        appLogEvent(
          'IMAGE_DISK_CACHE_TRIM_FAILED',
          category: AppLogCategory.cache,
          level: AppLogLevel.warning,
          source: 'AarastImageDiskCache',
          error: error,
          stackTrace: stackTrace,
        );
      }, test: (error) => error is FileSystemException)
      .whenComplete(() => _trimming = null);

  Future<void> _trim() async {
    final root = _root;
    if (root == null) return;
    final files = <({File file, int size, DateTime read})>[];
    await for (final entity in root.list()) {
      if (entity is! File || entity.path.endsWith('.part')) continue;
      final stat = await entity.stat();
      files.add((file: entity, size: stat.size, read: stat.modified));
    }
    var total = files.fold<int>(0, (sum, entry) => sum + entry.size);
    if (total <= maxBytes) return;
    files.sort((a, b) => a.read.compareTo(b.read));
    for (final entry in files) {
      if (total <= maxBytes) break;
      _kept?.remove(entry.file.uri.pathSegments.last);
      await entry.file.delete();
      total -= entry.size;
    }
  }

  static String _nameOf(String url) =>
      sha256.convert(utf8.encode(url)).toString();

  Future<void> _keep(Directory root, String name, Uint8List bytes) async {
    try {
      final file = File('${root.path}/$name');
      // Written beside and moved in whole, so a cut never leaves half an
      // image to be read next time.
      final part = File('${file.path}.part');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(file.path);
      _kept?.add(name);
      unawaited(trim());
    } on FileSystemException catch (error, stackTrace) {
      // The image is shown all the same; only the next run downloads it.
      appLogEvent(
        'IMAGE_DISK_CACHE_WRITE_FAILED',
        category: AppLogCategory.cache,
        level: AppLogLevel.warning,
        source: 'AarastImageDiskCache',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } on FileSystemException catch (error, stackTrace) {
      appLogEvent(
        'IMAGE_DISK_CACHE_TOUCH_FAILED',
        category: AppLogCategory.cache,
        level: AppLogLevel.warning,
        source: 'AarastImageDiskCache',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
