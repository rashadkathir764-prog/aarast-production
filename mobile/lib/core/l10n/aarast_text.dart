// D129 (docs/project/LANGUAGE.md): the one source of the app's words.
// The app speaks Arabic only, so the words are one instance read anywhere,
// in a screen or in a layer with no screen (an API error, a provider), never
// waiting on a Localizations scope. The reader's form (masculine/feminine)
// and the plan's (groom/bride) are passed to a word that needs them, as the
// ICU `select` its .arb entry declares.

import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_text.dart';
import '../experience_v3/aarast_journey_profile.dart';

export '../../l10n/generated/app_text.dart' show AppText;

/// The app's words (lib/l10n/parts/*.arb, joined by tool/merge_arb.dart).
final AppText aarastText = lookupAppText(const Locale('ar'));

/// The `gender` value an entry's `select` takes: `female` or `male`.
String readerGender({required bool feminine}) => feminine ? 'female' : 'male';

extension AarastTextContext on BuildContext {
  /// The app's words, as [aarastText].
  AppText get text => aarastText;

  /// This screen's reader's form for an entry's `gender` select.
  String get gender => readerGender(feminine: journeyProfile.feminine);
}

/// For a layer with no screen: the reader's form the app root set
/// ([ReaderVoice]), as `ReaderVoice.say` reads it.
String get voiceGender => readerGender(feminine: ReaderVoice.feminine);
