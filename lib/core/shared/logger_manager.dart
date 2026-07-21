import 'package:flutter/material.dart';

/// Logger管理器。
class LoggerManager {
  /// 单例实例。
  static final LoggerManager instance = LoggerManager._();
  LoggerManager._();

  /// logd。
  static void logd(String message, {LogLevel level = LogLevel.debug}) {
    debugPrint('[$level] $message');
  }

  /// handleError。
  static void handleError(dynamic error, StackTrace? stackTrace) {
    debugPrint('全局异常: $error');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}

/// LogLevel枚举。
enum LogLevel { debug, info, warning, error, fatal }
