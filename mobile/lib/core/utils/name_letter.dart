import 'package:flutter/widgets.dart' show StringCharacters;

/// The avatar's letter for a name: the first letter of its first word
/// without the article («الوالد» و، «العروسة» ع، «خالي أحمد» خ).
String nameLetter(String name, {String empty = '؟'}) {
  final word = name.trim();
  final bare = word.startsWith('ال') && word.length > 2
      ? word.substring(2)
      : word;
  return bare.isEmpty ? empty : bare.characters.first;
}
