import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../network/api_client.dart';

class MediaUploadTicket {
  const MediaUploadTicket({
    required this.key,
    required this.uploadUrl,
    required this.publicUrl,
    required this.contentType,
    required this.byteSize,
  });

  factory MediaUploadTicket.fromJson(Map<String, dynamic> json) {
    return MediaUploadTicket(
      key: json['key']?.toString() ?? '',
      uploadUrl: json['uploadUrl']?.toString() ?? '',
      publicUrl: json['publicUrl']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      byteSize: json['byteSize'] is int
          ? json['byteSize'] as int
          : int.tryParse('${json['byteSize']}') ?? 0,
    );
  }

  final String key;
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
    final ticket = MediaUploadTicket.fromJson(
      await _apiClient.postJson('/media/uploads/presign', {
        'purpose': purpose,
        'fileName': file.name,
        'contentType': contentType,
        'byteSize': byteSize,
      }),
    );
    final bytes = await file.readAsBytes();
    await _uploadClient.put<void>(
      ticket.uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          Headers.contentTypeHeader: ticket.contentType,
          Headers.contentLengthHeader: ticket.byteSize,
        },
      ),
    );
    return ticket;
  }

  String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
