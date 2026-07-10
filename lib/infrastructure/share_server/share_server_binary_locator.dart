import 'dart:io';

import 'package:flutter/foundation.dart';

/// 解析独立 Go 服务可执行文件（Windows 子进程回退用）。
class ShareServerBinaryLocator {
  ShareServerBinaryLocator._();

  static const _envKey = 'INSTANT_SHARE_SERVER_BIN';
  static const _windowsExeName = 'instant-share-server.exe';

  /// 返回可执行文件；找不到时返回 null。
  static Future<File?> resolve() async {
    final envPath = Platform.environment[_envKey];
    if (envPath != null && envPath.isNotEmpty) {
      final file = File(envPath);
      if (await file.exists()) return file;
    }

    for (final candidate in _candidatePaths()) {
      if (await candidate.exists()) {
        debugPrint('[ShareServer] 使用独立服务二进制: ${candidate.path}');
        return candidate;
      }
    }

    debugPrint(
      '[ShareServer] 未找到 $_windowsExeName。'
      '请执行: cd instant_share_server && go build -o ../assets/bin/instant-share-server.exe ./cmd/server',
    );
    return null;
  }

  static List<File> _candidatePaths() {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final projectRoot = _guessProjectRoot(exeDir);
    return [
      File('${exeDir.path}${Platform.pathSeparator}$_windowsExeName'),
      if (projectRoot != null)
        File(
          '${projectRoot.path}${Platform.pathSeparator}assets'
          '${Platform.pathSeparator}bin${Platform.pathSeparator}$_windowsExeName',
        ),
      if (projectRoot != null)
        File(
          '${projectRoot.path}${Platform.pathSeparator}assets'
          '${Platform.pathSeparator}lib${Platform.pathSeparator}instantshare-server.exe',
        ),
    ];
  }

  /// Debug 构建路径形如 `.../build/windows/x64/runner/Debug`，向上找到含 pubspec 的根。
  static Directory? _guessProjectRoot(Directory exeDir) {
    var current = exeDir;
    for (var i = 0; i < 8; i++) {
      final pubspec = File('${current.path}${Platform.pathSeparator}pubspec.yaml');
      if (pubspec.existsSync()) return current;
      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }
    return null;
  }
}
