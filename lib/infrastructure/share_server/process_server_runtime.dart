import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:instant_share/infrastructure/share_server/share_server_binary_locator.dart';
import 'package:instant_share/infrastructure/share_server/share_server_config.dart';
import 'package:instant_share/infrastructure/share_server/share_server_discovery.dart';
import 'package:instant_share/infrastructure/share_server/share_server_exception.dart';
import 'package:instant_share/infrastructure/share_server/share_server_listen_port.dart';
import 'package:instant_share/infrastructure/share_server/share_server_runtime.dart';

/// 通过独立 Go 子进程运行分享服务（Windows 无需 CGO/MinGW）。
class ProcessServerRuntime implements ShareServerRuntime {
  ProcessServerRuntime._();

  /// 单例实例。
  static final ProcessServerRuntime instance = ProcessServerRuntime._();

  static final RegExp _portMarker = RegExp(r'INSTANT_SHARE_READY port=(\d+)');

  Process? _process;
  bool _started = false;
  int? _port;
  Future<void>? _startFuture;

  /// isStarted。
  @override
  /// 是否已启动。
  bool get isStarted => _started;

  /// 端口。
  @override
  /// 端口。
  int? get port => _port;

  /// ensureStarted。
  @override
  Future<void> ensureStarted() {
    if (_started) return Future.value();
    if (_startFuture != null) return _startFuture!;
    _startFuture = _ensureStartedImpl();
    return _startFuture!.whenComplete(() => _startFuture = null);
  }

  Future<void> _ensureStartedImpl() async {
    if (_started) return;

    final binary = await ShareServerBinaryLocator.resolve();
    if (binary == null) {
      throw const ShareServerException(
        message:
            '未找到 instant-share-server.exe。'
            '请执行: cd instant_share_server && '
            'go build -o ../assets/bin/instant-share-server.exe ./cmd/server',
      );
    }

    final portCompleter = Completer<int>();
    void onLine(String line) {
      debugPrint('[ShareServer:proc] $line');
      final match = _portMarker.firstMatch(line);
      if (match != null && !portCompleter.isCompleted) {
        portCompleter.complete(int.parse(match.group(1)!));
      }
    }

    debugPrint('[ShareServer] 启动子进程: ${binary.path}');
    final process = await Process.start(
      binary.path,
      ['-port', '${resolveShareServerListenPort()}', '-parent-pid', '$pid'],
      environment: {
        ...Platform.environment,
        'INSTANT_SHARE_PARENT_PID': '$pid',
      },
      mode: ProcessStartMode.normal,
    );
    _process = process;

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine);
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine);

    unawaited(
      process.exitCode.then((code) {
        debugPrint('[ShareServer] 子进程退出 code=$code');
        if (identical(_process, process)) {
          _process = null;
          _started = false;
          _port = null;
        }
      }),
    );

    final allocatedPort = await portCompleter.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        unawaited(_stopManagedProcess());
        throw const ShareServerException(
          message: 'Go 子进程启动超时（未收到 INSTANT_SHARE_READY）',
        );
      },
    );

    await _waitHealthy(allocatedPort);
    _port = allocatedPort;
    _started = true;
    debugPrint('[ShareServer] 子进程服务已启动 port=$allocatedPort');
  }

  Future<void> _waitHealthy(int port) async {
    final discovery = ShareServerDiscovery(
      serverBaseUri: ShareServerConfig.baseUriForPort(port),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      try {
        await discovery.fetchHealth(timeout: const Duration(seconds: 2));
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    await _stopManagedProcess();
    throw ShareServerException(message: 'Go 子进程已启动但健康检查失败（port=$port）');
  }

  /// stop。
  @override
  Future<void> stop() async {
    await _stopManagedProcess();
    _started = false;
    _port = null;
    debugPrint('[ShareServer] 子进程服务已停止');
  }

  /// restartListening。
  @override
  Future<void> restartListening() async {
    await stop();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await ensureStarted();
  }

  Future<void> _stopManagedProcess() async {
    final process = _process;
    if (process == null) return;

    debugPrint('[ShareServer] 停止子进程 pid=${process.pid}');
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    _process = null;
  }
}
