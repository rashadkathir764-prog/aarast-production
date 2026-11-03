import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/utils/plan_day.dart';

/// One booking a plan holds with a provider, as the wedding-day move check
/// needs it (V1 checklist 4.13).
class PlanBookingDay {
  const PlanBookingDay({
    required this.providerName,
    required this.eventDate,
    required this.confirmed,
  });

  factory PlanBookingDay.fromJson(Map<String, dynamic> json) {
    return PlanBookingDay(
      providerName: json['providerName']?.toString().trim().isNotEmpty == true
          ? json['providerName'].toString().trim()
          : 'مزوّد',
      // The day in Sana'a, as the plan's wedding date is read (D11).
      eventDate:
          planDayFromJson(json['eventDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      confirmed: json['status'] == 'CONFIRMED',
    );
  }

  final String providerName;

  /// A calendar day.
  final DateTime eventDate;

  /// Confirmed by the provider; otherwise still a request.
  final bool confirmed;
}

/// The plan's open booking requests and upcoming confirmed bookings.
///
/// D85: the phone's copy when the server is out of reach.
class PlanBookingsLookup {
  PlanBookingsLookup(ApiClient apiClient, {OfflineSyncService? offline})
    : _reads = OfflineReads(apiClient, offline);

  final OfflineReads _reads;

  Future<List<PlanBookingDay>> list(String weddingPlanId) async {
    final json = await _reads.blobList(
      '/api/v1/me/wedding-plans/$weddingPlanId/bookings',
      metaKey: 'plan-booking-days:$weddingPlanId',
    );
    return json.map(PlanBookingDay.fromJson).toList();
  }
}

/// The bookings made for [day] (compared as calendar days).
List<PlanBookingDay> bookingsOnDay(
  List<PlanBookingDay> bookings,
  DateTime day,
) {
  return bookings
      .where(
        (booking) =>
            booking.eventDate.year == day.year &&
            booking.eventDate.month == day.month &&
            booking.eventDate.day == day.day,
      )
      .toList();
}
