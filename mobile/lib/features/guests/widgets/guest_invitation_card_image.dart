import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../models/guest_invitations.dart';

/// D116: the invitation card Aarast lays out, as it is sent to a guest as a
/// picture and as the card screen shows it: the photo when there is one
/// (the groom's, the couple's) on top, whose invitation it is, the wedding's
/// name, the guest's name, and each of the guest's occasions with its day,
/// time and place, in the plan's own colour. A card designed elsewhere is
/// not drawn here: it is sent as it is.
///
/// Fixed at [width] logical pixels so every phone sends the same picture;
/// [captureCard] draws it at three times that.
class GuestInvitationCardImage extends StatelessWidget {
  const GuestInvitationCardImage({
    required this.planTitle,
    required this.occasions,
    this.hostPhrase,
    this.freeText,
    this.guestName,
    this.photo,
    this.width = 360,
    super.key,
  });

  final String planTitle;
  final List<InvitationOccasionText> occasions;

  /// «يتشرف فلان بدعوتكم لحضور»; null without a host.
  final String? hostPhrase;
  final String? freeText;

  /// «أهلًا ياسر» on a guest's own card; null on the card screen's.
  final String? guestName;
  final ImageProvider? photo;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final onColour = AarastV3Color.onPrimary;
    final soft = accent.onPrimaryMuted;
    final words = freeText?.trim() ?? '';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: accent.primaryDark,
          borderRadius: BorderRadius.circular(AarastV3Radius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photo case final image?)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Image(
                  image: image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AarastV3Space.x5,
                AarastV3Space.x5,
                AarastV3Space.x5,
                AarastV3Space.x5,
              ),
              child: DefaultTextStyle(
                style: JourneyType.of(JourneyType.body, color: onColour),
                textAlign: TextAlign.center,
                child: Column(
                  children: [
                    if (guestName case final name?
                        when name.trim().isNotEmpty) ...[
                      Text('أهلًا ${name.trim()}'),
                      const SizedBox(height: AarastV3Space.x1),
                    ],
                    Text(
                      hostPhrase ?? 'يسعدنا دعوتك لحضور',
                      style: JourneyType.of(JourneyType.body, color: soft),
                    ),
                    const SizedBox(height: AarastV3Space.x2),
                    Text(
                      planTitle,
                      style: JourneyType.of(
                        JourneyType.pageTitle + 6,
                        weight: JourneyType.bold,
                        color: onColour,
                      ),
                    ),
                    if (words.isNotEmpty) ...[
                      const SizedBox(height: AarastV3Space.x2),
                      Text(
                        words,
                        style: JourneyType.of(JourneyType.body, color: soft),
                      ),
                    ],
                    for (final occasion in occasions) ...[
                      const SizedBox(height: AarastV3Space.x4),
                      if (occasions.length > 1)
                        Text(
                          occasion.label,
                          style: JourneyType.of(
                            JourneyType.lead,
                            weight: JourneyType.bold,
                            color: onColour,
                          ),
                        ),
                      if (_when(occasion) case final day?)
                        Text(
                          day,
                          style: JourneyType.of(
                            occasions.length > 1
                                ? JourneyType.small
                                : JourneyType.lead,
                            weight: occasions.length > 1
                                ? FontWeight.w400
                                : JourneyType.bold,
                            color: occasions.length > 1 ? soft : onColour,
                          ),
                        ),
                      if (occasion.placeLabel?.trim() case final place?
                          when place.isNotEmpty)
                        Text(
                          place,
                          style: JourneyType.of(JourneyType.small, color: soft),
                        ),
                    ],
                    const SizedBox(height: AarastV3Space.x4),
                    Text(
                      'الرد بضغطة من الرابط في الرسالة',
                      style: JourneyType.of(JourneyType.small, color: soft),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «الاثنين 30 نوفمبر · بعد العشاء».
  static String? _when(InvitationOccasionText occasion) {
    final time = invitationTimeLabel(occasion.timeSlot, occasion.exactTime);
    final parts = [
      if (occasion.date case final date?) formatArabicWeekdayDayMonth(date),
      ?time,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// D116: the card under [key] (a [RepaintBoundary]) as a PNG, three times
/// its size; null when it is not drawn yet.
Future<Uint8List?> captureCard(GlobalKey key) async {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return null;
  if (boundary.debugNeedsPaint) {
    await WidgetsBinding.instance.endOfFrame;
  }
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}
