import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'print_utils.dart';

void main() async {
  try {
    printStep('GENERATE', '开始生成本地化文件...');

    // 1. 读取配置
    final config = await _loadConfig();
    _validateConfigLocales(config);
    final i18nDirPath = _getCustomI18nOutputDir(config);
    final featureStrings = _getFeatureStrings(config);
    final supportedLocales = _getSupportedLocales(config);
    printSuccess('输出目录: $i18nDirPath');

    // 2. 读取翻译数据
    final translations = await _loadTranslations();
    printSuccess('加载翻译数据: ${translations.length} 个翻译项');

    // 3. 创建i18n目录
    Directory(i18nDirPath).createSync(recursive: true);
    printSuccess('创建目录: $i18nDirPath');

    // 4. 生成strings文件
    await _generateStringsFiles(translations, i18nDirPath, featureStrings);
    printSuccess('生成strings文件完成');

    // 5. 生成app_localizations.dart文件
    final outputLocalizationPath = path.join(
      i18nDirPath,
      'app_localizations.dart',
    );
    const outputLocalizationFile = 'app_localizations.dart';
    await _generateLocalizationsFile(
      outputLocalizationPath,
      outputLocalizationFile,
      featureStrings,
      supportedLocales,
    );
    printSuccess('生成本地化文件: $outputLocalizationFile');

    // 6. 生成 localizations.dart 导出文件
    await _generateLocalizationsExportFile(i18nDirPath, featureStrings);
    printSuccess('生成导出文件: localizations.dart');

    // 6. 格式化生成的代码
    await _formatGeneratedCode(i18nDirPath);
    printSuccess('格式化代码完成');

    printSuccess('所有文件生成完成！');
  } catch (e) {
    printError('错误: $e');
    exit(1);
  }
}

/// 读取配置文件（与 Go 工具共用 AILOC_CONFIG 环境变量）
Future<Map<String, dynamic>> _loadConfig() async {
  final packageRoot = _getPackageRoot();
  final configFromEnv = Platform.environment['AILOC_CONFIG'];
  final configRel = (configFromEnv == null || configFromEnv.isEmpty)
      ? 'config.yaml'
      : configFromEnv;
  final configPath = path.isAbsolute(configRel)
      ? configRel
      : path.join(packageRoot.path, configRel);
  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    throw Exception('找不到配置文件: ${configFile.path}');
  }

  final content = configFile.readAsStringSync();
  final yamlMap = loadYaml(content);
  return (yamlMap as YamlMap).cast<String, dynamic>();
}

Directory _getToolsDir() {
  final currentFile = File(Platform.script.toFilePath());
  return currentFile.parent.parent;
}

Directory _getPackageRoot() {
  return _getToolsDir().parent;
}

Directory _findProjectRoot() {
  var cursor = _getToolsDir().absolute;
  while (true) {
    final pubspec = File(path.join(cursor.path, 'pubspec.yaml'));
    final packagesDir = Directory(path.join(cursor.path, 'packages'));
    if (pubspec.existsSync() && packagesDir.existsSync()) {
      return cursor;
    }

    final parent = cursor.parent;
    if (parent.path == cursor.path) {
      throw Exception('无法定位项目根目录（缺少 pubspec.yaml + packages/）');
    }
    cursor = parent;
  }
}

String _resolveProjectPath(String configuredPath) {
  if (path.isAbsolute(configuredPath)) {
    return configuredPath;
  }
  return path.join(_findProjectRoot().path, configuredPath);
}

/// 获取自定义i18n输出目录
String _getCustomI18nOutputDir(Map<String, dynamic> config) {
  final outputDir = (config['custom_i18n_output_dir'] ?? 'lib/localizations')
      .toString();
  return _resolveProjectPath(outputDir);
}

/// 加载翻译数据
Future<Map<String, String>> _loadTranslations() async {
  final config = await _loadConfig();
  final sourceJsonPath =
      (config['source_json_file'] ?? 'assets/translations/translations.json')
          .toString();
  final file = File(_resolveProjectPath(sourceJsonPath));
  if (!file.existsSync()) {
    throw Exception('找不到翻译文件: ${file.path}');
  }

  final content = file.readAsStringSync();
  final jsonData = json.decode(content) as Map<String, dynamic>;

  // 提取source_data中的翻译数据
  if (jsonData.containsKey('source_data') && jsonData['source_data'] is Map) {
    final sourceData = jsonData['source_data'] as Map<String, dynamic>;
    return sourceData.map((key, value) => MapEntry(key, value.toString()));
  }

  return {};
}

Map<String, String> _getFeatureStrings(Map<String, dynamic> config) {
  final raw = config['feature_strings'];
  if (raw is Map) {
    final normalized = <String, String>{};
    raw.forEach((key, value) {
      normalized[key.toString()] = value.toString();
    });
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return {'app': 'app_strings'};
}

List<String> _getSupportedLocales(Map<String, dynamic> config) {
  final raw = config['locales'];
  if (raw is List) {
    final locales = raw.map((item) => item.toString()).toList();
    if (locales.isNotEmpty) {
      return locales;
    }
  }
  return const ['zh', 'en'];
}

void _validateConfigLocales(Map<String, dynamic> config) {
  final sourceLocale = config['source_locale']?.toString().trim() ?? '';
  if (sourceLocale.isEmpty) {
    throw Exception('config.yaml 缺少 source_locale');
  }
  _validateBCP47Locale(sourceLocale);

  final raw = config['locales'];
  if (raw is! List || raw.isEmpty) {
    throw Exception('config.yaml 缺少 locales');
  }
  final locales = raw.map((item) => item.toString()).toList();
  for (final locale in locales) {
    _validateBCP47Locale(locale);
  }
  if (!locales.contains(sourceLocale)) {
    throw Exception('config.yaml 中 source_locale=$sourceLocale 不在 locales 列表中');
  }
}

/// 生成strings文件
Future<void> _generateStringsFiles(
  Map<String, String> translations,
  String i18nDirPath,
  Map<String, String> featureStrings,
) async {
  // 创建strings目录
  final stringsDir = path.join(i18nDirPath, 'strings');
  Directory(stringsDir).createSync(recursive: true);

  // 收集所有已声明的前缀
  final declaredPrefixes = <String>{};
  for (final entry in featureStrings.entries) {
    final fileName = entry.value;
    // 根据 yaml value 生成前缀用于匹配 json key
    final prefix = _getPrefixForMatching(fileName);
    declaredPrefixes.add(prefix);
  }

  // 为每个feature生成对应的strings文件
  for (final entry in featureStrings.entries) {
    final featureName = entry.key;
    final fileName = entry.value;

    await _generateFeatureStringsFile(
      stringsDir,
      featureName,
      fileName,
      translations,
    );
  }

  // 生成base_strings.dart文件，包含未声明的键值对
  await _generateBaseStringsFile(stringsDir, translations, declaredPrefixes);

  // 生成strings.dart导出文件
  await _generateStringsExportFile(stringsDir, featureStrings);

  // 生成strings_mixin.dart文件
  await _generateStringsMixinFile(stringsDir);
}

/// 生成特定feature的strings文件
Future<void> _generateFeatureStringsFile(
  String stringsDir,
  String featureName,
  String fileName,
  Map<String, dynamic> jsonData,
) async {
  // 1. 根据 yaml value 生成文件名和类名
  // 文件名：{value}.dart
  final fileNameWithExtension = fileName.endsWith('.dart')
      ? fileName
      : '$fileName.dart';

  // 类名：{value} 驼峰并去掉下划线
  final className = _fileNameToClassName(fileName);

  final filePath = path.join(stringsDir, fileNameWithExtension);

  // 2. 匹配 json key 前缀：{value}去掉下划线然后全小写加下划线开头
  // 例如：app_strings -> appstrings_
  final prefixForMatching = _getPrefixForMatching(fileName);

  // 过滤出以prefixForMatching开头的键值对
  final featureData = <String, String>{};
  for (final entry in jsonData.entries) {
    if (entry.key.startsWith(prefixForMatching)) {
      featureData[entry.key] = entry.value as String;
    }
  }

  if (featureData.isEmpty) {
    // 如果没有数据，创建空的类文件
    final content =
        '''import 'strings_mixin.dart';

class $className with MixinStrings {
  // 暂无数据
}
''';
    await _writeFileIfChanged(filePath, content);
    return;
  }

  // 生成类内容
  final buffer = StringBuffer();
  buffer.writeln("import 'strings_mixin.dart';");
  buffer.writeln();
  buffer.writeln('class $className with MixinStrings {');

  for (final entry in featureData.entries) {
    final key = entry.key;
    final value = entry.value;

    // 从key中提取方法名（去掉prefixForMatching）
    final methodName = key.substring(prefixForMatching.length);

    // 检查是否包含参数（通过检查值中是否有{}）
    if (value.contains('{') && value.contains('}')) {
      // 有参数的方法
      final args = _extractArgs(value);
      final argsList = args.map((arg) => 'Object $arg').join(', ');
      final argsMap = args.map((arg) => "'$arg': $arg").join(', ');

      // 将JSON格式的{xxx}转换为Dart格式的$xxx
      final dartValue = _convertToDartString(value);

      buffer.writeln('  String $methodName($argsList) {');
      buffer.writeln(
        "    return intlMessage('$dartValue', sid: '$key', args: {$argsMap});",
      );
      buffer.writeln('  }');
    } else {
      // 简单的getter
      final dartValue = _convertToDartString(value);
      buffer.writeln(
        "  String get $methodName => intlMessage('$dartValue', sid: '$key');",
      );
    }
    buffer.writeln();
  }

  buffer.writeln('}');

  await _writeFileIfChanged(filePath, buffer.toString());
}

/// 根据 yaml value 生成用于匹配 json key 的前缀
/// 例如：app_strings -> appstrings_
/// buy_crypto_strings -> buycryptostrings_
String _getPrefixForMatching(String value) {
  // 去掉 .dart 后缀（如果有）
  final nameWithoutExtension = value.replaceAll('.dart', '');

  // 去掉下划线，全小写，然后加下划线
  final prefix = '${nameWithoutExtension.replaceAll('_', '').toLowerCase()}_';

  return prefix;
}

/// 从字符串中提取参数名（去重并保持顺序）
List<String> _extractArgs(String text) {
  final regex = RegExp(r'\{([^}]+)\}');
  final matches = regex.allMatches(text);
  final args = <String>[];
  final seenArgs = <String>{};

  for (final match in matches) {
    final arg = match.group(1)!;
    if (!seenArgs.contains(arg)) {
      seenArgs.add(arg);
      args.add(arg);
    }
  }

  return args;
}

/// 生成base_strings.dart文件，包含未声明的键值对
Future<void> _generateBaseStringsFile(
  String stringsDir,
  Map<String, dynamic> jsonData,
  Set<String> declaredPrefixes,
) async {
  final filePath = path.join(stringsDir, 'base_strings.dart');

  // 过滤出未声明的键值对
  final baseData = <String, String>{};
  for (final entry in jsonData.entries) {
    final key = entry.key;
    final value = entry.value as String;

    // 检查这个key是否属于任何已声明的前缀
    bool isDeclared = false;
    for (final prefix in declaredPrefixes) {
      // declaredPrefixes 现在存储的是基于 yaml value 生成的前缀（如 appstrings_）
      if (key.startsWith(prefix)) {
        isDeclared = true;
        break;
      }
    }

    // 如果不在任何已声明的前缀中，则添加到base数据中
    if (!isDeclared) {
      baseData[key] = value;
    }
  }

  if (baseData.isEmpty) {
    // 如果没有数据，创建空的类文件
    final content = '''import 'strings_mixin.dart';

class BaseStrings with MixinStrings {
  // 暂无数据
}
''';
    await _writeFileIfChanged(filePath, content);
    return;
  }

  // 生成类内容
  final buffer = StringBuffer();
  buffer.writeln("import 'strings_mixin.dart';");
  buffer.writeln();
  buffer.writeln('class BaseStrings with MixinStrings {');

  for (final entry in baseData.entries) {
    final key = entry.key;
    final value = entry.value;

    // 检查是否包含参数（通过检查值中是否有{}）
    if (value.contains('{') && value.contains('}')) {
      // 有参数的方法
      final args = _extractArgs(value);
      final argsList = args.map((arg) => 'Object $arg').join(', ');
      final argsMap = args.map((arg) => "'$arg': $arg").join(', ');

      // 将JSON格式的{xxx}转换为Dart格式的$xxx
      final dartValue = _convertToDartString(value);

      buffer.writeln('  String $key($argsList) {');
      buffer.writeln(
        "    return intlMessage('$dartValue', sid: '$key', args: {$argsMap});",
      );
      buffer.writeln('  }');
    } else {
      // 简单的getter
      final dartValue = _convertToDartString(value);
      buffer.writeln(
        "  String get $key => intlMessage('$dartValue', sid: '$key');",
      );
    }
    buffer.writeln();
  }

  buffer.writeln('}');

  await _writeFileIfChanged(filePath, buffer.toString());
}

/// 生成strings.dart导出文件
Future<void> _generateStringsExportFile(
  String stringsDir,
  Map<String, String> featureStrings,
) async {
  final filePath = path.join(stringsDir, 'strings.dart');
  final buffer = StringBuffer();

  // 收集所有需要导出的文件名
  final exportFiles = <String>[];

  // 添加base_strings.dart
  exportFiles.add('base_strings.dart');

  // 添加其他feature strings文件
  for (final entry in featureStrings.entries) {
    final fileName = entry.value;
    // 确保文件名有 .dart 扩展名
    final fileNameWithExtension = fileName.endsWith('.dart')
        ? fileName
        : '$fileName.dart';
    exportFiles.add(fileNameWithExtension);
  }

  // 按字母顺序排序
  exportFiles.sort();

  // 生成export语句
  for (final file in exportFiles) {
    buffer.writeln("export '$file';");
  }

  await _writeFileIfChanged(filePath, buffer.toString());
}

/// 生成strings_mixin.dart文件
Future<void> _generateStringsMixinFile(String stringsDir) async {
  final filePath = path.join(stringsDir, 'strings_mixin.dart');
  final content = '''import 'package:ai_localizations/ai_localizations.dart';

mixin MixinStrings {
  String intlMessage(String messageText, {required String sid, Map<String, Object>? args}) {
    return TranslatorApiAccess.instance.translator.translate(defaultEn: messageText, sid: sid, args: args);
  }
}
''';

  await _writeFileIfChanged(filePath, content);
}

/// 生成本地化文件
Future<void> _generateLocalizationsFile(
  String filePath,
  String fileName,
  Map featureStrings,
  List<String> locales,
) async {
  final file = File(filePath);

  // 从文件名生成类名（去掉 .dart 扩展名，转换为驼峰命名）
  final className = _fileNameToClassName(fileName);

  // 生成所有getter，按字母顺序排序
  final getters = <MapEntry<String, String>>[];

  // 添加base getter
  getters.add(MapEntry('base', 'BaseStrings'));

  // 添加其他feature getters
  for (final entry in featureStrings.entries) {
    final featureName = entry.key as String;
    final fileName = entry.value as String;
    // 根据文件名生成类名，例如：buy_crypto_strings -> BuyCryptoStrings
    final className = _fileNameToClassName(fileName);
    getters.add(MapEntry(featureName, className));
  }

  // 按字母顺序排序
  getters.sort((a, b) => a.key.compareTo(b.key));

  // 生成getter字符串
  final gettersString = getters
      .map(
        (getter) => '  ${getter.value} get ${getter.key} => ${getter.value}();',
      )
      .join('\n\n');

  // 生成 supportedLocales 方法
  final supportedLocalesBuffer = StringBuffer();
  _generateSupportedLocalesMethod(supportedLocalesBuffer, locales);
  final supportedLocalesString = supportedLocalesBuffer.toString().trim();

  final buffer = StringBuffer();
  buffer.writeln("import 'package:flutter/foundation.dart';");
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln("import 'package:ai_localizations/ai_localizations.dart';");
  buffer.writeln();
  buffer.writeln("import 'strings/strings.dart';");
  buffer.writeln();

  // 生成 AppLocalizationsDelegate 类
  buffer.writeln(
    '''class ${className}Delegate extends LocalizationsDelegate<LocalizationsSdk> {
  ${className}Delegate();

  @override
  bool isSupported(Locale locale) => $className.supportedLocales().contains(locale);

  @override
  Future<LocalizationsSdk> load(Locale locale) {
    final lastLoadedLocalizationsSdk = LocalizationsSdk.lastLoadedLocalizationsSdk;
    if (lastLoadedLocalizationsSdk != null && lastLoadedLocalizationsSdk.locale == locale) {
      return SynchronousFuture<LocalizationsSdk>(lastLoadedLocalizationsSdk);
    }

    return LocalizationsSdk.load(locale);
  }

  @override
  bool shouldReload(LocalizationsDelegate<LocalizationsSdk> old) => false;
}

extension $className on LocalizationsSdk {
$supportedLocalesString

$gettersString
}''',
  );

  await _writeFileIfChanged(file.path, buffer.toString());
}

/// 将文件名转换为驼峰命名的类名
String _fileNameToClassName(String fileName) {
  // 去掉 .dart 扩展名
  final nameWithoutExtension = fileName.replaceAll('.dart', '');

  // 将下划线转换为驼峰命名
  return _toCamelCase(nameWithoutExtension);
}

/// 生成 supportedLocales 方法
void _generateSupportedLocalesMethod(
  StringBuffer buffer,
  List<String> locales,
) {
  buffer.writeln('  static List<Locale> supportedLocales() {');
  buffer.writeln('    return [');

  for (final locale in locales) {
    final localeCode = _convertLocaleStringToLocaleCode(locale);
    buffer.writeln('      $localeCode,');
  }

  buffer.writeln('    ];');
  buffer.writeln('  }');
}

/// 校验 BCP-47 locale（与 Go 工具 config.ValidateBCP47Locale 规则一致）。
void _validateBCP47Locale(String locale) {
  final trimmed = locale.trim();
  if (trimmed.isEmpty) {
    throw Exception('locale 不能为空');
  }
  if (trimmed.contains('_')) {
    throw Exception('locale "$trimmed" 使用了下划线，须改用 BCP-47 连字符格式（如 zh-Hant-HK）');
  }

  final parts = trimmed.split('-');
  if (parts.length > 3) {
    throw Exception('locale "$trimmed" 格式无效：当前仅支持 language[-script][-region]');
  }

  _validateLanguageSubtag(parts[0], trimmed);

  if (parts.length == 1) {
    return;
  }
  if (parts.length == 2) {
    _validateSecondSubtag(parts[1], trimmed);
    return;
  }

  _validateScriptSubtag(parts[1], trimmed);
  _validateRegionSubtag(parts[2], trimmed);
}

void _validateLanguageSubtag(String value, String locale) {
  if (value.length < 2 || value.length > 3) {
    throw Exception('locale "$locale" 语言代码须为 2-3 位小写字母（ISO 639）');
  }
  if (!RegExp(r'^[a-z]+$').hasMatch(value)) {
    throw Exception('locale "$locale" 语言代码须为小写（ISO 639）');
  }
}

void _validateSecondSubtag(String value, String locale) {
  if (value.length == 4) {
    _validateScriptSubtag(value, locale);
    return;
  }
  if (value.length == 2) {
    _validateRegionSubtag(value, locale);
    return;
  }
  throw Exception('locale "$locale" 第二段须为 4 位文字码（如 Hans）或 2 位地区码（如 US）');
}

void _validateScriptSubtag(String value, String locale) {
  if (!RegExp(r'^[A-Z][a-z]{3}$').hasMatch(value)) {
    throw Exception('locale "$locale" 文字代码须为 4 位 ISO 15924（如 Hans、Hant）');
  }
}

void _validateRegionSubtag(String value, String locale) {
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(value)) {
    throw Exception('locale "$locale" 地区代码须为 2 位大写字母（ISO 3166-1，如 CN、HK）');
  }
}

/// 将 BCP-47 locale 字符串转换为 Flutter Locale 代码。
String _convertLocaleStringToLocaleCode(String localeString) {
  _validateBCP47Locale(localeString);

  final parts = localeString.split('-');
  if (parts.length == 1) {
    return "Locale('$localeString')";
  }
  if (parts.length == 2) {
    final languageCode = parts[0];
    final second = parts[1];
    if (second.length == 4) {
      return "Locale.fromSubtags(languageCode: '$languageCode', scriptCode: '$second')";
    }
    return "Locale('$languageCode', '$second')";
  }

  final languageCode = parts[0];
  final scriptCode = parts[1];
  final countryCode = parts[2];
  return "Locale.fromSubtags(languageCode: '$languageCode', scriptCode: '$scriptCode', countryCode: '$countryCode')";
}

/// 将下划线命名转换为驼峰命名
String _toCamelCase(String input) {
  final parts = input.split('_');
  if (parts.isEmpty) return input;

  final result = parts
      .map((part) {
        if (part.isEmpty) return part;
        return part[0].toUpperCase() + part.substring(1).toLowerCase();
      })
      .join('');

  return result;
}

/// 将JSON格式的{xxx}转换为Dart格式的$xxx
String _convertToDartString(String jsonString) {
  // 先使用jsonEncode来正确处理所有转义字符，然后去掉首尾的引号
  final encoded = json.encode(jsonString);
  final escapedString = encoded.substring(1, encoded.length - 1);

  // 最后将剩余的$符号转义为\$，避免Dart将其解释为字符串插值
  final replaceResult = escapedString.replaceAll('\$', '\\\$');

  // 然后处理参数占位符，将{xxx}转换为$xxx
  final result = replaceResult.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (
    match,
  ) {
    final arg = match.group(1)!;
    return '\${$arg}';
  });

  return result;
}

/// 仅在文件内容有变化时才写入文件
Future<void> _writeFileIfChanged(String filePath, String newContent) async {
  final file = File(filePath);

  // 检查文件是否已存在
  if (await file.exists()) {
    final existingContent = await file.readAsString();

    // 如果内容相同，跳过写入
    if (existingContent == newContent) {
      printInfo('文件内容无变化，跳过: ${path.basename(filePath)}');
      return;
    }
  }

  // 写入新内容
  await file.writeAsString(newContent);
  printInfo('文件已更新: ${path.basename(filePath)}');
}

/// 格式化生成的代码
Future<void> _formatGeneratedCode(String dirPath) async {
  try {
    final result = await Process.run('dart', ['format', '-l', '150', dirPath]);
    if (result.exitCode != 0) {
      printError('警告: 代码格式化失败: ${result.stderr}');
    }
  } catch (e) {
    printError('警告: 无法执行dart format命令: $e');
  }
}

/// 生成 localizations.dart 导出文件
Future<void> _generateLocalizationsExportFile(
  String i18nDirPath,
  Map featureStrings,
) async {
  final filePath = path.join(i18nDirPath, 'localizations.dart');

  // 获取输出文件名并生成类名
  const outputFileName = 'app_localizations.dart';
  _fileNameToClassName(outputFileName);

  final buffer = StringBuffer();

  buffer.writeln("export '$outputFileName';");
  buffer.writeln("export 'strings/strings.dart';");

  await _writeFileIfChanged(filePath, buffer.toString());
}
