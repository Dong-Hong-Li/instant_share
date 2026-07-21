import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 本地 KV 存储门面（基于 [SharedPreferences]）。
///
/// **用法约定**
/// - 在 `main()` 里 `await PrefsUtil.init()` 之后再 `runApp`；
/// - 业务代码只通过本类的静态方法读写，不要直接 [SharedPreferences.getInstance]；
/// - Key 统一放在 [AppKeys]（`lib/resource/keys.dart`）。
class PrefsUtil {
  PrefsUtil._();

  static SharedPreferences? _prefs;
  static Future<void>? _initializing;

  static Future<void> init() => _initializing ??= _open();

  static Future<void> _open() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _storage {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError(
        'PrefsUtil 未初始化：请在 main() 中 await PrefsUtil.init() 后再访问。',
      );
    }
    return prefs;
  }

  /// 保存字符串。
  static Future<bool> setString(String key, String value) =>
      _storage.setString(key, value);

  static String? getString(String key) => _storage.getString(key);

  static Future<bool> remove(String key) => _storage.remove(key);

  static bool contains(String key) => _storage.containsKey(key);

  /// 保存布尔值。
  static Future<bool> setBool(String key, bool value) =>
      _storage.setBool(key, value);

  static bool? getBool(String key) => _storage.getBool(key);

  /// 保存整数。
  static Future<bool> setInt(String key, int value) =>
      _storage.setInt(key, value);

  static int? getInt(String key) => _storage.getInt(key);

  /// 保存 JSON 数据。
  static Future<bool> setJson(String key, Map<String, dynamic> jsonMap) =>
      setString(key, jsonEncode(jsonMap));

  /// 读取 JSON；[key] 不存在返回 null；JSON 非法时抛出 [FormatException]。
  static Map<String, dynamic>? getJson(String key) {
    final raw = getString(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('PrefsUtil.getJson: "$key" 不是 Map', raw);
    }
    return decoded;
  }

  static Future<bool> clear() => _storage.clear();
}
