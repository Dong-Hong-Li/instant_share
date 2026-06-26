import 'package:flutter/material.dart';
import 'package:instant_share/l10n/strings/app_strings.dart';

extension AppStringsLocaleLabel on AppStrings {
  /// 将 [Locale] 映射为当前界面语言下的展示名称。
  String localeLabel(Locale locale) {
    return switch (locale.toLanguageTag()) {
      'zh-Hans-CN' => langZhHansCN,
      'en-US' => langEnUS,
      'en-GB' => langEnGB,
      'en-IN' => langEnIN,
      'zh-TW' => langZhTW,
      'zh-HK' => langZhHK,
      'ja' => langJa,
      'ko' => langKo,
      _ => locale.toLanguageTag(),
    };
  }
}
