import 'package:flutter/widgets.dart' show StringCharacters;

/// RA-BE-15/16: text cut to what the server takes, counted as both count (a
/// character as the reader sees it; the server's `MaxCharacters`). A field's
/// `maxLength` stops typing only; a name picked from the contacts or read
/// from a pasted list is set from code and could pass it, and the server then
/// refused the queued change («السيرفر رفضه»).
String clipToCharacters(String value, int maximum) {
  final characters = value.characters;
  return characters.length <= maximum
      ? value
      : characters.take(maximum).toString().trimRight();
}
