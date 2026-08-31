import 'package:flutter/widgets.dart' show Locale;

/// Picks the Arabic or English variant of a piece of backend-like content
/// (e.g. a [Service] name) based on [locale]. For UI chrome strings, use
/// gen-l10n's [AppLocalizations] instead — this is only for feature models
/// that carry both language variants directly.
String pickLocalized(Locale locale, {required String ar, required String en}) {
  return locale.languageCode == 'ar' ? ar : en;
}
