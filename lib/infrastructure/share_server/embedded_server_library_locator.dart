import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:instant_share/infrastructure/share_server/share_server_exception.dart';

/// 解析并加载 Go c-shared 动态库（进程内运行分享服务）。
///
/// 各平台产物与加载方式：
/// - macOS：bundle `Contents/Resources/libinstantshare.dylib`。
/// - Windows：与 exe 同目录的 `instantshare.dll`（CMake install 拷贝）。
/// - Linux：与 exe 同目录的 `libinstantshare.so`（TODO：CMake install）。
/// - Android：`libinstantshare.so`（TODO：放入 `jniLibs/<abi>/`）。
/// - iOS：静态链接进主程序（TODO：c-archive .a）。
class EmbeddedServerLibraryLocator {
  EmbeddedServerLibraryLocator._();

  static const macosAssetPath = 'assets/lib/libinstantshare.dylib';
  static const windowsAssetPath = 'assets/lib/instantshare.dll';
  static const linuxAssetPath = 'assets/lib/libinstantshare.so';
  static const _envKey = 'INSTANT_SHARE_SERVER_LIB';

  static const _macosLibName = 'libinstantshare.dylib';
  static const _windowsLibName = 'instantshare.dll';
  static const _linuxLibName = 'libinstantshare.so';
  static const _androidLibName = 'libinstantshare.so';

  static DynamicLibrary? _cached;

  /// 加载动态库；同一进程内复用。
  static Future<DynamicLibrary> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    final lib = await _open();
    _cached = lib;
    return lib;
  }

  static Future<DynamicLibrary> _open() async {
    final envPath = Platform.environment[_envKey];
    if (envPath != null && envPath.isNotEmpty && File(envPath).existsSync()) {
      return DynamicLibrary.open(envPath);
    }

    if (Platform.isIOS) {
      // TODO(ios): 改用 c-archive (.a) 静态链接进 Runner，符号位于主程序进程内。
      return DynamicLibrary.process();
    }

    if (Platform.isAndroid) {
      // TODO(android): 将 .so 放入 jniLibs/<abi>/ 后，按 soname 加载即可。
      return DynamicLibrary.open(_androidLibName);
    }

    if (Platform.isMacOS) {
      final path = await _resolveMacOS();
      return DynamicLibrary.open(path);
    }

    if (Platform.isWindows) {
      final path = await _resolveWindows();
      return DynamicLibrary.open(path);
    }

    if (Platform.isLinux) {
      final path = await _resolveLinux();
      return DynamicLibrary.open(path);
    }

    final path = await _materializeFromAssetsToTemp();
    return DynamicLibrary.open(path);
  }

  static Future<String> _resolveMacOS() async {
    final bundleLib = _macosResourcesPath();
    if (await bundleLib.exists()) {
      debugPrint('[ShareServer] 使用 bundle 内动态库: ${bundleLib.path}');
      return bundleLib.path;
    }

    if (kDebugMode) {
      final materialized = await _materializeToMacOSBundle();
      if (materialized != null) return materialized;
      return _materializeFromAssetsToTemp();
    }

    throw ShareServerException(
      message:
          'bundle 内未找到 $_macosLibName，请执行 instant_share_server/build_lib.sh macos '
          '后重新 flutter run -d macos',
    );
  }

  static Future<String> _resolveWindows() async {
    final bundled = _exeSiblingLib(_windowsLibName);
    if (await bundled.exists()) {
      debugPrint('[ShareServer] 使用 exe 同目录动态库: ${bundled.path}');
      return bundled.path;
    }

    throw ShareServerException(
      message:
          '未找到 $_windowsLibName（应与 instant_share.exe 同目录）。'
          '请先执行 instant_share_server/build_lib.bat 生成 assets/lib/instantshare.dll，'
          '再 flutter run -d windows',
    );
  }

  static Future<String> _resolveLinux() async {
    final bundled = _exeSiblingLib(_linuxLibName);
    if (await bundled.exists()) {
      debugPrint('[ShareServer] 使用 exe 同目录动态库: ${bundled.path}');
      return bundled.path;
    }

    if (kDebugMode) {
      final materialized = await _materializeToExeDir(
        _linuxLibName,
        linuxAssetPath,
      );
      if (materialized != null) return materialized;
      return _materializeFromAssetsToTemp();
    }

    throw ShareServerException(
      message:
          '未找到 $_linuxLibName，请执行 instant_share_server/build_lib.sh linux '
          '后重新 flutter run -d linux',
    );
  }

  static File _macosResourcesPath() {
    final exe = File(Platform.resolvedExecutable);
    return File.fromUri(exe.uri.resolve('../Resources/$_macosLibName'));
  }

  static File _exeSiblingLib(String name) {
    final exeDir = File(Platform.resolvedExecutable).parent;
    return File('${exeDir.path}${Platform.pathSeparator}$name');
  }

  /// Debug 热重载时 Xcode 可能未重新 build，从 asset 写入 bundle Resources。
  static Future<String?> _materializeToMacOSBundle() async {
    final target = _macosResourcesPath();
    try {
      final bytes = await rootBundle.load(macosAssetPath);
      await target.parent.create(recursive: true);
      await target.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      final sign = await Process.run('codesign', [
        '--force',
        '--sign',
        '-',
        target.path,
      ]);
      if (sign.exitCode != 0) {
        debugPrint('[ShareServer] dylib codesign 警告: ${sign.stderr}');
      }
      debugPrint('[ShareServer] 已从 asset 写入动态库: ${target.path}');
      return target.path;
    } catch (error, stackTrace) {
      debugPrint('[ShareServer] 写入 bundle Resources 失败: $error\n$stackTrace');
      return null;
    }
  }

  /// Debug 热重载时 CMake 可能未重新 install，从 asset 写入 exe 同目录。
  static Future<String?> _materializeToExeDir(
    String libName,
    String assetPath,
  ) async {
    final target = _exeSiblingLib(libName);
    try {
      final bytes = await rootBundle.load(assetPath);
      await target.parent.create(recursive: true);
      await target.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      debugPrint('[ShareServer] 已从 asset 写入动态库: ${target.path}');
      return target.path;
    } catch (error, stackTrace) {
      debugPrint('[ShareServer] 写入 exe 目录失败: $error\n$stackTrace');
      return null;
    }
  }

  /// 从 asset 写入临时目录。
  static Future<String> _materializeFromAssetsToTemp() async {
    final assetPath = _currentAssetPath();
    final bytes = await rootBundle.load(assetPath);
    final dir = Directory.systemTemp.createTempSync('instant_share_lib_');
    final file = File('${dir.path}/${_currentLibName()}');
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    return file.path;
  }

  static String _currentLibName() {
    if (Platform.isWindows) return _windowsLibName;
    if (Platform.isLinux) return _linuxLibName;
    return _macosLibName;
  }

  static String _currentAssetPath() {
    if (Platform.isWindows) return windowsAssetPath;
    if (Platform.isLinux) return linuxAssetPath;
    return macosAssetPath;
  }
}
