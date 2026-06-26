import 'dart:async';
import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:instant_share/infrastructure/share_server/embedded_server_library_locator.dart';
import 'package:instant_share/infrastructure/share_server/share_server_config.dart';
import 'package:instant_share/infrastructure/share_server/share_server_exception.dart';
import 'package:instant_share/infrastructure/share_server/share_server_runtime.dart';

typedef _StartServerC = Int32 Function(Int32 port);
typedef _StartServerDart = int Function(int port);
typedef _StopServerC = Void Function();
typedef _StopServerDart = void Function();

/// 通过 dart:ffi 在 App 进程内运行 Go 分享服务（c-shared 动态库）。
///
/// 取代独立子进程方案：无残留进程、无端口清理、跟随 App 进程生死。
/// 服务仍监听 `localhost`，上层 Discovery / WebSocket 客户端零改动。
class EmbeddedServerRuntime implements ShareServerRuntime {
  EmbeddedServerRuntime._();

  static final EmbeddedServerRuntime instance = EmbeddedServerRuntime._();

  _StartServerDart? _start;
  _StopServerDart? _stop;

  bool _started = false;
  int? _port;
  Future<void>? _startFuture;

  @override
  bool get isStarted => _started;

  @override
  int? get port => _port;

  @override
  Future<void> ensureStarted() {
    if (_started) return Future.value();
    if (_startFuture != null) return _startFuture!;
    _startFuture = _ensureStartedImpl();
    return _startFuture!.whenComplete(() => _startFuture = null);
  }

  Future<void> _ensureStartedImpl() async {
    if (_started) return;

    await _bind();

    // 桌面端沿用固定端口（与 Discovery 的 defaultBaseUri 对齐）。
    // 移动端为避免端口冲突，可改传 0 由系统分配，并用返回值更新 Discovery 地址。
    final requested = ShareServerConfig.defaultPort;
    final port = _start!(requested);
    if (port <= 0) {
      throw const ShareServerException(
        message: '进程内 Go 服务启动失败（StartServer 返回错误）',
      );
    }

    _port = port;
    _started = true;
    debugPrint('[ShareServer] 进程内服务已启动 port=$port');
  }

  Future<void> _bind() async {
    if (_start != null && _stop != null) return;

    final lib = await EmbeddedServerLibraryLocator.load();
    _start = lib.lookupFunction<_StartServerC, _StartServerDart>('StartServer');
    _stop = lib.lookupFunction<_StopServerC, _StopServerDart>('StopServer');
  }

  @override
  Future<void> stop() async {
    final stop = _stop;
    if (stop != null) {
      // 同步 FFI 调用：内部做优雅关闭（最多约 5s）。App 退出场景可接受。
      stop();
    }
    _started = false;
    _port = null;
    debugPrint('[ShareServer] 进程内服务已停止');
  }
}
