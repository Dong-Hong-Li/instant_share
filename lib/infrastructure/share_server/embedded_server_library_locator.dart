import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:instant_share/infrastructure/share_server/share_server_exception.dart';

/// 解析并加载 Go c-shared 动态库（进程内运行分享服务）。
///
/// 各平台产物与加载方式：
/// - macOS：bundle `Contents/Resources/libinstantshare.dylib`，
///   Debug 首次从 asset 写入并 ad-hoc 签名（沿用二进制定位器的做法）。
/// - Windows：`instantshare.dll`（TODO：交叉编译产物 + 打包）。
/// - Linux：`libinstantshare.so`（TODO）。
/// - Android：`libinstantshare.so`（TODO：放入 `jniLibs/<abi>/`，按 soname 加载）。
/// - iOS：静态链接进主程序，符号在进程内（TODO：改用 c-archive .a）。
class EmbeddedServerLibraryLocator {
  EmbeddedServerLibraryLocator._();

  static const macosAssetPath = 'assets/lib/libinstantshare.dylib';
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
    // 显式覆盖（开发/调试）：直接指向已编译的库文件。
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

    // TODO(windows/linux): 交叉编译产物落地并打包后，从 asset 解包到临时目录加载。
    final path = await _materializeFromAssetsToTemp();
    return DynamicLibrary.open(path);
  }

  static Future<String> _resolveMacOS() async {
    final bundleLib = _macosResourcesPath();
    if (await bundleLib.exists()) {
      debugPrint('[ShareServer] 使用 bundle 内动态库: ${bundleLib.path}');
      return bundleLib.path;
    }

    // Debug 热重载不会跑 Xcode 拷贝脚本，首次启动从 asset 写入 Resources 并签名。
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

  static File _macosResourcesPath() {
    final exe = File(Platform.resolvedExecutable);
    return File.fromUri(exe.uri.resolve('../Resources/$_macosLibName'));
  }

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

  static String _currentAssetPath() => 'assets/lib/${_currentLibName()}';
}
