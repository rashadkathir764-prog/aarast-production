/// RA-MO-101: the writes that wait on the phone outside the sync queue
/// (chat messages, a provider's offers). The composition root registers how
/// to count them, so «الخروج» names them with the rest of what was not sent.
class SideOutboxes {
  SideOutboxes._();

  static final List<int Function()> _counters = [];

  static void register(int Function() counter) => _counters.add(counter);

  /// For tests: forget what was registered.
  static void reset() => _counters.clear();

  /// Every write waiting in them; a counter that fails counts nothing.
  static int count() {
    var total = 0;
    for (final counter in _counters) {
      try {
        total += counter();
      } on Object {
        // A store that cannot be read has nothing to name.
      }
    }
    return total;
  }
}
