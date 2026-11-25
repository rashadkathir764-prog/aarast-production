import 'dart:async';

/// Every way the phone learns that the account has a new notice while the
/// app is open: a push that arrives in front, the live socket's
/// `notification:available`, and the server answering again after a gap.
/// The inbox and the bell read their count again on each; none of them
/// carries the notice itself.
class NoticeArrivals {
  final _arrivals = StreamController<void>.broadcast();

  Stream<void> get stream => _arrivals.stream;

  void announce() {
    if (!_arrivals.isClosed) _arrivals.add(null);
  }

  Future<void> close() => _arrivals.close();
}
