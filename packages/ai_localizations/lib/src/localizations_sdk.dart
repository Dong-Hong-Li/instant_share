import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 本地化SDK的主要类
class LocalizationsSdk {
  final Locale locale;
  final Map<String, String> _translations;

  LocalizationsSdk._(this.locale, this._translations);

  static final Map<String, LocalizationsSdk> _cacheByLocale = {};
  static LocalizationsSdk? _lastLoaded;

  /// 获取最后加载的本地化实例
  static LocalizationsSdk? get lastLoadedLocalizationsSdk => _lastLoaded;

  /// 加载指定语言的本地化数据
  static Future<LocalizationsSdk> load(Locale locale) async {
    final localeKey = _localeCacheKey(locale);
    final cached = _cacheByLocale[localeKey];
    if (cached != null) {
      _lastLoaded = cached;
      return cached;
    }

    try {
      final translations = await _loadTranslations(locale);
      final sdk = LocalizationsSdk._(locale, translations);
      _cacheByLocale[localeKey] = sdk;
      _lastLoaded = sdk;
      return sdk;
    } catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
          context: ErrorDescription('while loading localization for $locale'),
          library: 'ai_localizations',
        ),
      );
      final sdk = LocalizationsSdk._(locale, {});
      _cacheByLocale[localeKey] = sdk;
      _lastLoaded = sdk;
      return sdk;
    }
  }

  /// 从assets/translations/加载指定语言的翻译数据
  static Future<Map<String, String>> _loadTranslations(Locale locale) async {
    final candidates = _arbAssetCandidates(locale);
    for (final assetKey in candidates) {
      try {
        final content = await rootBundle.loadString(assetKey);
        return _parseArbContent(content);
      } catch (_) {
        // 尝试下一个候选文件
      }
    }

    if (!kReleaseMode) {
      try {
        final fallbackContent = await rootBundle.loadString(
          'assets/translations/translations.json',
        );
        return _parseSourceDataFallback(fallbackContent);
      } catch (fallbackError) {
        throw FlutterError(
          '无法加载本地化资源（候选 ARB: ${candidates.join(', ')}，且 translations.json 回退失败）: $fallbackError',
        );
      }
    }

    throw FlutterError(
      'Release 模式未找到可用 ARB 资源（候选: ${candidates.join(', ')}）。',
    );
  }

  static String _localeCacheKey(Locale locale) => locale.toLanguageTag();

  static List<String> _arbAssetCandidates(Locale locale) {
    final languageCode = locale.languageCode;
    final scriptCode = locale.scriptCode;
    final countryCode = locale.countryCode;

    final variants = <String>[];
    if (languageCode.isEmpty) {
      return const [];
    }
    if (scriptCode != null &&
        scriptCode.isNotEmpty &&
        countryCode != null &&
        countryCode.isNotEmpty) {
      variants.add('${languageCode}_${scriptCode}_$countryCode');
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      variants.add('${languageCode}_$countryCode');
    }
    if (scriptCode != null && scriptCode.isNotEmpty) {
      variants.add('${languageCode}_$scriptCode');
    }
    variants.add(languageCode);

    final deduped = <String>{...variants}.toList();
    return deduped
        .map((variant) => 'assets/translations/app_$variant.arb')
        .toList();
  }

  static Map<String, String> _parseArbContent(String content) {
    final jsonData = json.decode(content) as Map<String, dynamic>;
    final translations = <String, String>{};
    jsonData.forEach((key, value) {
      if (!key.startsWith('@')) {
        translations[key] = value.toString();
      }
    });
    return translations;
  }

  static Map<String, String> _parseSourceDataFallback(String content) {
    final jsonData = json.decode(content) as Map<String, dynamic>;
    if (jsonData['source_data'] is! Map) {
      throw FlutterError('translations.json 缺少合法 source_data 字段');
    }
    final sourceData = jsonData['source_data'] as Map<String, dynamic>;
    return sourceData.map((key, value) => MapEntry(key, value.toString()));
  }

  /// 翻译方法
  String translate({
    required String defaultEn,
    required String sid,
    Map<String, Object>? args,
  }) {
    String text = _translations[sid] ?? defaultEn;

    // 处理参数替换
    if (args != null) {
      args.forEach((key, value) {
        text = text.replaceAll('{$key}', value.toString());
      });
    }

    return text;
  }

  /// 在Widget树中查找LocalizationsSdk实例
  static LocalizationsSdk of(BuildContext context) {
    final localizations = Localizations.of<LocalizationsSdk>(
      context,
      LocalizationsSdk,
    );
    if (localizations == null) {
      throw FlutterError(
        'LocalizationsSdk not found in widget tree. '
        'Make sure to wrap your app with Localizations widgets.',
      );
    }
    return localizations;
  }
}

/// 翻译器访问接口
class TranslatorApiAccess {
  static final TranslatorApiAccess _instance = TranslatorApiAccess._internal();

  factory TranslatorApiAccess() => _instance;

  TranslatorApiAccess._internal();

  static TranslatorApiAccess get instance => _instance;

  late final Translator translator = Translator();
}

/// 翻译器类
class Translator {
  String translate({
    required String defaultEn,
    required String sid,
    Map<String, Object>? args,
  }) {
    // 获取当前LocalizationsSdk实例
    final sdk = LocalizationsSdk.lastLoadedLocalizationsSdk;
    if (sdk == null) {
      // 如果没有加载，返回默认英文
      String text = defaultEn;
      if (args != null) {
        args.forEach((key, value) {
          text = text.replaceAll('{$key}', value.toString());
        });
      }
      return text;
    }

    return sdk.translate(defaultEn: defaultEn, sid: sid, args: args);
  }
}

/// 字符串混入
mixin MixinStrings {
  String intlMessage(
    String messageText, {
    required String sid,
    Map<String, Object>? args,
  }) {
    return TranslatorApiAccess.instance.translator.translate(
      defaultEn: messageText,
      sid: sid,
      args: args,
    );
  }
}
