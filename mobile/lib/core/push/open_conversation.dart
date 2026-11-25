/// The conversation the reader has in front of them now, so a push about
/// a message in it is not also shown as a phone notification: the message
/// is already on the screen. The chat says when one opens and closes.
class OpenConversationRegistry {
  String? _current;

  /// The conversation on the screen; null when none is.
  String? get current => _current;

  bool isOpen(String conversationId) =>
      _current != null && _current == conversationId.trim();

  void opened(String conversationId) {
    final id = conversationId.trim();
    _current = id.isEmpty ? null : id;
  }

  /// Only the conversation that was open closes it: a second chat opened
  /// on top of the first keeps its own.
  void closed(String conversationId) {
    if (_current == conversationId.trim()) _current = null;
  }
}
