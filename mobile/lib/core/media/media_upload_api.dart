import 'package:dio/dio.dart';
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

class MediaUploadApi {
  MediaUploadApi(this._apiClient, {Dio? uploadClient})
    : _uploadClient = uploadClient ?? Dio();

  final ApiClient _apiClient;
  final Dio _uploadClient;

  Future<MediaUploadTicket> uploadImage({
    required XFile file,
    required String purpose,
  }) async {
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
    await _uploadClient.put<void>(
      ticket.uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          Headers.contentTypeHeader: ticket.contentType,
          Headers.contentLengthHeader: ticket.byteSize,
          'If-None-Match': '*',
        },
      ),
    );
    final verifiedJson = await _apiClient.postJson(
      '/api/v1/media/uploads/verify',
      {'key': ticket.key, 'purpose': purpose},
    );
    final verifiedTicket = MediaUploadTicket.fromJson({
      ...ticketJson,
      ...verifiedJson,
    });
    final hasVerifiedReference = purpose == 'chat-image'
        ? verifiedTicket.attachmentRef.isNotEmpty
        : verifiedTicket.publicUrl.isNotEmpty;
    if (!hasVerifiedReference) {
      throw const ApiException('تعذر التحقق من الصورة المرفوعة.');
    }
    return verifiedTicket;
  }

  String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
