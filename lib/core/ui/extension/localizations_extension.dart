import 'package:flutter/material.dart';
import 'package:ai_localizations/ai_localizations.dart';

/// 本地化扩展。
extension LocalizationsExtension on BuildContext {
  /// l10n。
  LocalizationsSdk get l10n => LocalizationsSdk.of(this);
}
