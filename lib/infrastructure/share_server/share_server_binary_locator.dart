import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 解析 Go 服务可执行文件。
///
/// macOS 沙盒仅允许执行 .app bundle 内的二进制（Resources/MacOS），
/// 不可从 tmp 解包执行。
class ShareServerBinaryLocator {
  ShareServerBinaryLocator._();

  static const assetPath = 'assets/bin/instant-share-server';

  static File? _cachedExecutable;

  /// 返回可执行文件；优先 [INSTANT_SHARE_SERVER_BIN]。
  static Future<File?> resolve() async {
    final envPath = Platform.environment['INSTANT_SHARE_SERVER_BIN'];
    if (envPath != null && envPath.isNotEmpty) {
      final file = File(envPath);
      if (await file.exists()) return file;
    }

    if (Platform.isMacOS) {
      return _resolveMacOS();
    }

    if (_cachedExecutable != null && await _cachedExecutable!.exists()) {
      return _cachedExecutable;
    }

    return _materializeFromAssetsToTemp();
  }

  static Future<File?> _resolveMacOS() async {
    for (final candidate in _macosCandidatePaths()) {
      if (await candidate.exists()) {
        debugPrint('[ShareServer] 使用 bundle 内二进制: ${candidate.path}');
        return candidate;
      }
    }

    // Debug 热重载不会跑 Xcode 拷贝脚本，首次启动时从 asset 写入 Resources 并签名
    if (kDebugMode) {
      final materialized = await _materializeToMacOSBundle();
      if (materialized != null) return materialized;

      // Debug 且未打包进 Resources 时，从 asset 解到临时目录（需 Debug 关闭沙盒）
      return _materializeFromAssetsToTemp();
    }

    debugPrint(
      '[ShareServer] bundle 内未找到 instant-share-server\n'
      '  executable: ${Platform.resolvedExecutable}\n'
      '  期望: ${_macosResourcesPath().path}\n'
      '  请执行 flutter run -d macos 完整构建，或保持 assets/bin 后重启 App',
    );
    return null;
  }

  static List<File> _macosCandidatePaths() {
    final exe = File(Platform.resolvedExecutable);
    return [
      _macosResourcesPath(),
      File.fromUri(exe.uri.resolve('instant-share-server')),
    ];
  }

  static File _macosResourcesPath() {
    final exe = File(Platform.resolvedExecutable);
    return File.fromUri(exe.uri.resolve('../Resources/instant-share-server'));
  }

  static Future<File?> _materializeToMacOSBundle() async {
    final target = _macosResourcesPath();
    try {
      final bytes = await rootBundle.load(assetPath);
      await target.parent.create(recursive: true);
      await target.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      await Process.run('chmod', ['+x', target.path]);
      final sign = await Process.run('codesign', [
        '--force',
        '--sign',
        '-',
        target.path,
      ]);
      if (sign.exitCode != 0) {
        debugPrint('[ShareServer] codesign 警告: ${sign.stderr}');
      }
      debugPrint('[ShareServer] 已从 asset 写入: ${target.path}');
      return target;
    } catch (error, stackTrace) {
      debugPrint('[ShareServer] 写入 bundle Resources 失败: $error\n$stackTrace');
      return null;
    }
  }

  static Future<File?> _materializeFromAssetsToTemp() async {
    try {
      final bytes = await rootBundle.load(assetPath);
      final dir = Directory.systemTemp.createTempSync('instant_share_bin_');
      final file = File('${dir.path}/instant-share-server');
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', file.path]);
      }
      _cachedExecutable = file;
      return file;
    } catch (error, stackTrace) {
      debugPrint('[ShareServer] 未找到 $assetPath\n$error\n$stackTrace');
      return null;
    }
  }
}
