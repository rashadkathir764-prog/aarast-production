import 'package:image_picker/image_picker.dart';

import '../network/api_client.dart';

class MediaUploadTicket {
  const MediaUploadTicket({
    required this.key,
    required this.attachmentRef,
    required this.uploadUrl,
    required this.publicUrl,
    required this.contentType,
    required this.byteSize,
  });

  factory MediaUploadTicket.fromJson(Map<String, dynamic> json) {
    return MediaUploadTicket(
      key: json['key']?.toString() ?? '',
      attachmentRef: json['attachmentRef']?.toString() ?? '',
      uploadUrl: json['uploadUrl']?.toString() ?? '',
      publicUrl: json['publicUrl']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      byteSize: json['byteSize'] is int
          ? json['byteSize'] as int
          : int.tryParse('${json['byteSize']}') ?? 0,
    );
  }

  final String key;
  final String attachmentRef;
  final String uploadUrl;
  final String publicUrl;
  final String contentType;
  final int byteSize;
}

/// Uploads kept off the public CDN (V1 checklist 4.4 adds cost receipts).
const privateMediaPurposes = {'chat-image', 'cost-receipt'};

class MediaUploadApi {
  const MediaUploadApi(this._apiClient);

  final ApiClient _apiClient;

  Future<MediaUploadTicket> uploadImage({
    required XFile file,
    required String purpose,
  }) async {
    try {
      final byteSize = await file.length();
      final contentType = file.mimeType ?? _contentType(file.name);
      final ticketJson = await _apiClient
          .postJson('/api/v1/media/uploads/presign', {
            'purpose': purpose,
            'fileName': file.name,
            'contentType': contentType,
            'byteSize': byteSize,
          });
      final ticket = MediaUploadTicket.fromJson(ticketJson);
      if (ticket.key.isEmpty || ticket.uploadUrl.isEmpty) {
        throw const ApiException('تعذر تجهيز رفع الصورة.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length != ticket.byteSize) {
        throw const ApiException(
          'تغيّر حجم الصورة أثناء تجهيزها. اختر الصورة مرة أخرى.',
        );
      }
      await _apiClient.putBytes(
        ticket.uploadUrl,
        bytes,
        contentType: ticket.contentType,
      );
      final verifiedJson = await _apiClient.postJson(
        '/api/v1/media/uploads/verify',
        {'key': ticket.key, 'purpose': purpose},
      );
      final verifiedTicket = MediaUploadTicket.fromJson({
        ...ticketJson,
        ...verifiedJson,
      });
      // Private purposes (chat images, cost receipts) return a reference
      // read through signed URLs, never a public URL.
      final hasVerifiedReference = privateMediaPurposes.contains(purpose)
          ? verifiedTicket.attachmentRef.isNotEmpty
          : verifiedTicket.publicUrl.isNotEmpty;
      if (!hasVerifiedReference) {
        throw const ApiException('تعذر التحقق من الصورة المرفوعة.');
      }
      return verifiedTicket;
    } on ApiException catch (error) {
      if (error.statusCode == 503 ||
          error.message.toLowerCase().contains('media storage')) {
        throw const ApiException(
          'خدمة رفع الصور غير متاحة الآن. يرجى المحاولة مرة أخرى لاحقًا.',
          statusCode: 503,
        );
      }
      rethrow;
    }
  }

  String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
