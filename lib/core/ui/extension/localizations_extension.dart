import 'package:flutter/material.dart';
import 'package:ai_localizations/ai_localizations.dart';

extension LocalizationsExtension on BuildContext {
  LocalizationsSdk get l10n => LocalizationsSdk.of(this);
}
