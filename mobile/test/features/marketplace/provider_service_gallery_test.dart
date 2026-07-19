import 'dart:typed_data';

import 'package:aarast_mobile/core/media/media_upload_api.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_services_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'provider can select and publish several service photos at once',
    (tester) async {
      final dashboard = _GalleryDashboardProvider();
      final selectedFiles = [
        _imageFile('hall-1.jpg'),
        _imageFile('hall-2.jpg'),
        _imageFile('hall-3.jpg'),
      ];
      var uploadCalls = 0;
      var pickerCalls = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<ProviderDashboardProvider>.value(
          value: dashboard,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: ProviderServicesTab(
                  pickImages: () async {
                    pickerCalls++;
                    return selectedFiles;
                  },
                  uploadImage: (file) async {
                    uploadCalls++;
                    return _ticket('hall-$uploadCalls.jpg');
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('إضافة صور للأعمال'));
      await tester.pumpAndSettle();

      expect(pickerCalls, 1);
      expect(uploadCalls, 3);
      expect(dashboard.savedUrls, [
        'https://media.example.test/hall-1.jpg',
        'https://media.example.test/hall-2.jpg',
        'https://media.example.test/hall-3.jpg',
      ]);
      expect(find.text('تمت إضافة 3 صور إلى الخدمة.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

XFile _imageFile(String name) => XFile.fromData(
  Uint8List.fromList([0xff, 0xd8, 0xff]),
  name: name,
  mimeType: 'image/jpeg',
);

MediaUploadTicket _ticket(String name) => MediaUploadTicket(
  key: 'service-image/user-1/$name',
  attachmentRef: '',
  uploadUrl: 'https://upload.example.test/$name',
  publicUrl: 'https://media.example.test/$name',
  contentType: 'image/jpeg',
  byteSize: 3,
);

class _GalleryDashboardProvider extends ProviderDashboardProvider {
  _GalleryDashboardProvider()
    : super(ProviderDashboardApi(ApiClient(tokenProvider: () async => null)));

  final List<String> savedUrls = [];

  @override
  List<MarketplaceService> get services => const [_service];

  @override
  List<ProviderPackage> get packages => const [];

  @override
  Future<void> loadDashboard() async {}

  @override
  Future<bool> addServiceImage({
    required String serviceId,
    required String imageUrl,
    String? altText,
  }) async {
    expect(serviceId, _service.id);
    expect(altText, _service.title);
    savedUrls.add(imageUrl);
    return true;
  }
}

const _service = MarketplaceService(
  id: 'service-hall',
  providerId: 'provider-1',
  title: 'قاعة اللؤلؤة',
  isFeatured: false,
  isActive: true,
);
