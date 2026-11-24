import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/media/aarast_image_disk_cache.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-364: Image.network kept images in memory only, so every start
// downloaded every cover and logo again.

class _Server {
  final requests = <String>[];
  String? cacheControl;

  Future<AarastFetchedImage> fetch(Uri url) async {
    requests.add(url.toString());
    return (
      bytes: Uint8List.fromList(
        List.generate(1000, (i) => (url.path.length + i) % 256),
      ),
      cacheControl: cacheControl,
    );
  }
}

void main() {
  late Directory root;
  late _Server server;

  setUp(() {
    root = Directory.systemTemp.createTempSync('aarast_images_test');
    server = _Server();
  });
  tearDown(() => root.deleteSync(recursive: true));

  AarastImageDiskCache run({int maxBytes = 1 << 20}) => AarastImageDiskCache(
    directory: () async => root,
    fetch: server.fetch,
    maxBytes: maxBytes,
  );

  test('an image kept on one run is read from the phone on the next', () async {
    const url = 'https://media.example/provider-cover/u/a-480.webp';
    final first = run();
    await first.open();
    final downloaded = await first.load(url, keep: true);
    expect(server.requests, [url]);

    final next = run();
    await next.open();
    expect(await next.load(url, keep: true), downloaded);
    expect(server.requests, [url], reason: 'no second download');
  });

  test('what the server marks no-store is never written', () async {
    server.cacheControl = 'private, no-store';
    final cache = run();
    await cache.open();
    await cache.load('https://signed.example/chat-image/x.jpg', keep: true);
    expect(root.listSync(), isEmpty);
  });

  test('what the caller asks not to keep is never written', () async {
    final cache = run();
    await cache.open();
    await cache.load('https://signed.example/cost-receipt/r.jpg', keep: false);
    expect(root.listSync(), isEmpty);
  });

  test('nothing is written before the kept images were listed', () async {
    final cache = run();
    await cache.load('https://media.example/a.jpg', keep: true);
    expect(root.listSync(), isEmpty);
  });

  test('past the limit, the least recently read are dropped', () async {
    final earlier = run();
    await earlier.open();
    for (final name in ['a', 'b', 'c']) {
      await earlier.load('https://media.example/$name.jpg', keep: true);
      // Distinct read times, oldest first.
      for (final file in root.listSync().whereType<File>()) {
        file.setLastModifiedSync(
          file.lastModifiedSync().subtract(const Duration(minutes: 1)),
        );
      }
    }
    expect(root.listSync(), hasLength(3));

    // A run with room for two drops the oldest when it opens.
    final cache = run(maxBytes: 2500);
    await cache.open();
    final kept = root.listSync().whereType<File>().toList();
    expect(kept, hasLength(2));
    // «a», the oldest, went; reading it downloads it again.
    server.requests.clear();
    await cache.load('https://media.example/c.jpg', keep: true);
    await cache.load('https://media.example/a.jpg', keep: true);
    expect(server.requests, ['https://media.example/a.jpg']);
  });

  test('a half-written image from a cut run is dropped on open', () async {
    File('${root.path}/abc.part').writeAsBytesSync([1, 2, 3]);
    await run().open();
    expect(root.listSync(), isEmpty);
  });
}
