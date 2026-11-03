/// D85: a screen shows the phone's copy at once and asks the server at the
/// same time.
///
/// [remote] starts first (the request leaves the phone right away);
/// [cached] is the phone's copy (null when there is none), applied while
/// the server has not answered yet. [apply] takes whichever arrives;
/// [state] tells the provider what to show: a loading state only while
/// nothing is on the phone, a stale mark when the copy stays because the
/// server did not answer, and an error only when there is no copy at all.
Future<void> readCachedFirst<T>({
  required Future<T?> Function() cached,
  required Future<T> Function() remote,
  required void Function(T value) apply,
  required void Function({
    required bool loading,
    required bool stale,
    String? error,
  })
  state,
  required String Function(Object error) describe,
  bool Function(T value)? isEmpty,
}) async {
  var remoteDone = false;
  late final Future<T> answer;
  try {
    answer = remote().whenComplete(() => remoteDone = true);
  } on Object catch (error) {
    // A remote that fails before it is even asynchronous.
    answer = Future<T>.error(error);
    remoteDone = true;
  }
  // The copy never surfaces as an unhandled error while it is awaited.
  answer.ignore();

  T? copy;
  try {
    copy = await cached();
  } on Object {
    copy = null;
  }
  final hasCopy = copy != null && !(isEmpty?.call(copy) ?? false);
  if (!remoteDone) {
    if (hasCopy) {
      apply(copy as T);
      state(loading: false, stale: false);
    } else {
      state(loading: true, stale: false);
    }
  }
  try {
    final fresh = await answer;
    apply(fresh);
    state(loading: false, stale: false);
  } on Object catch (error) {
    if (hasCopy) {
      // The server failed before the copy was read: the copy shows now.
      if (remoteDone) apply(copy as T);
      state(loading: false, stale: true);
    } else {
      state(loading: false, stale: false, error: describe(error));
    }
  }
}
