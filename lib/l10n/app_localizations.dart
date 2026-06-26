import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ai_localizations/ai_localizations.dart';

import 'strings/strings.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<LocalizationsSdk> {
  AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales().contains(locale);

  @override
  Future<LocalizationsSdk> load(Locale locale) {
    final lastLoadedLocalizationsSdk =
        LocalizationsSdk.lastLoadedLocalizationsSdk;
    if (lastLoadedLocalizationsSdk != null &&
        lastLoadedLocalizationsSdk.locale == locale) {
      return SynchronousFuture<LocalizationsSdk>(lastLoadedLocalizationsSdk);
    }

    return LocalizationsSdk.load(locale);
  }

  @override
  bool shouldReload(LocalizationsDelegate<LocalizationsSdk> old) => false;
}

extension AppLocalizations on LocalizationsSdk {
  static List<Locale> supportedLocales() {
    return [
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
        countryCode: 'CN',
      ),
      Locale('en', 'US'),
      Locale('en', 'GB'),
      Locale('en', 'IN'),
      Locale('zh', 'TW'),
      Locale('zh', 'HK'),
      Locale('ja'),
      Locale('ko'),
    ];
  }

  AppStrings get app => AppStrings();

  BaseStrings get base => BaseStrings();
}
