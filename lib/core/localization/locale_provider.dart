import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const List<Locale> supportedLocales = [Locale('ar'), Locale('en')];

/// Current app locale. Arabic is the primary language, so it's the default.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('ar');

  void toggle() {
    state = state.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
  }

  void set(Locale locale) => state = locale;
}

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);
