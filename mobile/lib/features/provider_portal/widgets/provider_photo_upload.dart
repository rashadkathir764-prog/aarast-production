import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/aarast_toast.dart';

/// Opens the phone's photos; tests pass their own.
typedef ProviderPhotoPicker = Future<List<XFile>> Function();

/// Uploads one photo as his `provider-portfolio`; tests pass their own.
typedef ProviderPhotoUploader = Future<MediaUploadTicket> Function(XFile file);

/// The work photos his application goes to review with (Q-59, D127): the
/// server refuses fewer with `PROVIDER_PHOTOS_REQUIRED`.
const providerApplicationMinPhotos = 3;

/// The most photos one pick takes.
const providerPhotosPerPick = 10;

/// What one pick came to: the uploads that went through, out of [asked].
class ProviderPhotoUploads {
  const ProviderPhotoUploads(this.tickets, this.asked);

  final List<MediaUploadTicket> tickets;
  final int asked;

  bool get complete => tickets.length == asked;
}

/// Opens the phone's photos and uploads up to [room] of those chosen as
/// his portfolio photos («معرض الشغل», the application's photos, B-16,
/// Q-59). Null when nothing was chosen or nothing went up; a toast says why.
/// The upload alone keeps nothing: the caller sends the keys.
Future<ProviderPhotoUploads?> pickAndUploadProviderPhotos(
  BuildContext context, {
  required int room,
  ProviderPhotoPicker? pick,
  ProviderPhotoUploader? upload,
}) async {
  late final List<XFile> files;
  try {
    files =
        await (pick?.call() ??
            ImagePicker().pickMultiImage(
              imageQuality: 84,
              maxWidth: 2000,
              limit: providerPhotosPerPick,
            ));
  } catch (_) {
    if (context.mounted) {
      AarastToast.showError(
        context,
        'ما قدرنا نفتح الصور. يمكن إذن الصور مقفول في الجوال.',
      );
    }
    return null;
  }
  if (files.isEmpty || !context.mounted) return null;
  final take = room < providerPhotosPerPick ? room : providerPhotosPerPick;
  final chosen = files.take(take < 0 ? 0 : take).toList();
  if (chosen.isEmpty) return null;
  final send =
      upload ??
      (XFile file) => context.read<MediaUploadApi>().uploadImage(
        file: file,
        purpose: 'provider-portfolio',
      );
  final tickets = <MediaUploadTicket>[];
  String? lastError;
  for (final file in chosen) {
    try {
      tickets.add(await send(file));
    } on ApiException catch (error) {
      lastError = error.message;
      if (error.statusCode != null && error.statusCode! >= 500) break;
    } catch (_) {
      lastError = 'ما قدرنا نرفع صورة منها.';
    }
    if (!context.mounted) return null;
  }
  if (tickets.isEmpty) {
    AarastToast.showError(
      context,
      lastError ?? 'ما قدرنا نرفع الصور، ومرة ثانية غالبًا تمشي.',
    );
    return null;
  }
  return ProviderPhotoUploads(tickets, chosen.length);
}
