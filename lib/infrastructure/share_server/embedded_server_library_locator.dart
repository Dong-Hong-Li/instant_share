import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:instant_share/infrastructure/share_server/share_server_exception.dart';

/// 解析并加载 Go c-shared 动态库（进程内运行分享服务）。
///
/// 各平台产物与加载方式：
/// - macOS：bundle `Contents/Resources/libinstantshare.dylib`（`copy_share_server.sh` 拷贝）。
/// - Windows：与 exe 同目录的 `instantshare.dll`（CMake install 拷贝）。
/// - Linux：与 exe 同目录的 `libinstantshare.so`。
/// - Android：`jniLibs/<abi>/libinstantshare.so`（`build_lib.sh android`），按 soname 加载。
///
/// 调试时可设置环境变量 `INSTANT_SHARE_SERVER_LIB` 指向库文件绝对路径。
class EmbeddedServerLibraryLocator {
  EmbeddedServerLibraryLocator._();

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
      return DynamicLibrary.open(_androidLibName);
    }

    if (Platform.isMacOS) {
      return DynamicLibrary.open(await _resolveMacOS());
    }

    if (Platform.isWindows) {
      return DynamicLibrary.open(await _resolveWindows());
    }

    if (Platform.isLinux) {
      return DynamicLibrary.open(await _resolveLinux());
    }

    throw ShareServerException(message: '当前平台不支持进程内 Go 分享服务');
  }

  static Future<String> _resolveMacOS() async {
    final bundleLib = _macosResourcesPath();
    if (await bundleLib.exists()) {
      debugPrint('[ShareServer] 使用 bundle 内动态库: ${bundleLib.path}');
      return bundleLib.path;
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
}
