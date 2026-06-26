import 'package:flutter/material.dart';

class LoggerManager {
  static final LoggerManager instance = LoggerManager._();
  LoggerManager._();

  static void logd(String message, {LogLevel level = LogLevel.debug}) {
    debugPrint('[$level] $message');
  }

  static void handleError(dynamic error, StackTrace? stackTrace) {
    debugPrint('全局异常: $error');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}

enum LogLevel { debug, info, warning, error, fatal }
