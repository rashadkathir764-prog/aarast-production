part of 'provider_marketplace_screen.dart';

/// A participant who works on the plan's providers (a helper) sees only the
/// requests they made on «طلباتي». Reading is separate from editing (D52,
/// D80, Q-51): the plan's bookings, whoever made them, are read from the
/// plan's view, without amounts, in the card and in the tab's line; only
/// the side of a request acts on its booking.
extension _ParticipantPlan on _ProviderMarketplaceScreenState {
  /// The plan's id when the reader is its participant, otherwise null.
  String? get _participantPlanId {
    final planId = _weddingLocationPlanId;
    final selected = context.read<AccountContextController?>()?.selectedContext;
    if (planId == null ||
        selected == null ||
        selected.role != AccountContextRole.contributor ||
        selected.weddingPlanId != planId) {
      return null;
    }
    return planId;
  }

  void _loadParticipantPlan() {
    final planId = _participantPlanId;
    if (planId == null) return;
    context.read<PlanReadViewProvider?>()?.load(planId);
  }

  /// The plan's bookings a participant reads; null for the owner, or while
  /// the plan's view is not loaded.
  List<PlanReadBooking>? _participantBookings({bool watch = false}) {
    final planId = _participantPlanId;
    if (planId == null) return null;
    final provider = watch
        ? context.watch<PlanReadViewProvider?>()
        : context.read<PlanReadViewProvider?>();
    return provider?.viewOf(planId)?.bookings;
  }

  /// Whether the plan's view still has to say if the plan has bookings.
  bool get _participantPlanPending =>
      _participantPlanId != null &&
      _participantBookings() == null &&
      context.read<PlanReadViewProvider?>()?.errorMessage == null;

  /// RA-MO-338 (Q-51 (أ)): «محجوز 3 · ينتظر 1» are the plan's bookings,
  /// whoever asked, as the card under it lists them; the offers waiting
  /// are his own requests'.
  String _boardStatus(List<ProviderBoardRow> board) {
    final bookings = _participantBookings(watch: true) ?? const [];
    final booked = bookings.where((booking) => booking.confirmed).length;
    return participantBoardStatus(
      board,
      planBooked: booked,
      planWaiting: bookings.length - booked,
      reader: context.journeyProfile,
    );
  }

  /// q16's card at the top of «طلباتي» for a participant: what the plan has
  /// booked, read only.
  List<Widget> _participantBookingsSection() {
    final bookings = _participantBookings(watch: true);
    if (bookings == null || bookings.isEmpty) return const [];
    return [
      const JourneySectionTitle('في الخطة'),
      PlanReadBookingsCard(bookings: bookings),
      const SizedBox(height: AarastV3Space.x3),
    ];
  }
}
