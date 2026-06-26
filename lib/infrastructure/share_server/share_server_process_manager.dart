import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:instant_share/infrastructure/share_server/share_server_binary_locator.dart';
import 'package:instant_share/infrastructure/share_server/share_server_config.dart';
import 'package:instant_share/infrastructure/share_server/share_server_discovery.dart';
import 'package:instant_share/infrastructure/share_server/share_server_exception.dart';

/// 由 Flutter 托管 Go 子进程：App 启动时拉起，退出时关闭。
class ShareServerProcessManager {
  ShareServerProcessManager._();

  static final ShareServerProcessManager instance =
      ShareServerProcessManager._();

  Process? _process;
  bool _managedByApp = false;
  bool _started = false;
  Future<void>? _startFuture;

  bool get isManagedByApp => _managedByApp;

  bool get isStarted => _started;

  /// 确保本地 Go 服务可用：已健康则复用；否则拉起内嵌二进制。
  Future<void> ensureStarted() {
    if (_started) return Future.value();
    if (_startFuture != null) return _startFuture!;
    _startFuture = _ensureStartedImpl();
    return _startFuture!.whenComplete(() => _startFuture = null);
  }

  Future<void> _ensureStartedImpl() async {
    if (_started) return;

    if (await _tryReuseExisting()) return;

    await _terminateStaleShareServers();
    await _freePortIfForeignService();

    if (await _tryReuseExisting()) return;

    final binary = await ShareServerBinaryLocator.resolve();
    if (binary == null) {
      throw ShareServerException(
        message: '未找到 Go 服务二进制，请将 instant-share-server 放入 assets/bin/',
      );
    }

    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', binary.path]);
    }

    debugPrint('[ShareServer] 启动子进程: ${binary.path}');
    _process = await Process.start(
      binary.path,
      ['-port', '${ShareServerConfig.defaultPort}', '-parent-pid', '$pid'],
      environment: {
        ...Platform.environment,
        'INSTANT_SHARE_PORT': '${ShareServerConfig.defaultPort}',
        'INSTANT_SHARE_PARENT_PID': '$pid',
      },
      mode: ProcessStartMode.normal,
    );
    _managedByApp = true;

    _process!.stdout
        .transform(utf8.decoder)
        .listen((line) => debugPrint('[ShareServer:stdout] $line'));
    _process!.stderr
        .transform(utf8.decoder)
        .listen((line) => debugPrint('[ShareServer:stderr] $line'));
    unawaited(
      _process!.exitCode.then((code) {
        if (_process != null) {
          debugPrint('[ShareServer] 子进程退出 code=$code');
        }
        _process = null;
        _managedByApp = false;
        if (code != 0) {
          _started = false;
        }
      }),
    );

    await _waitForHealthy(
      timeout: const Duration(seconds: 15),
      interval: const Duration(milliseconds: 500),
    );
    _started = true;
  }

  /// 停止 Go 服务（含本 App 拉起的子进程与残留 instant-share-server）。
  Future<void> stop() async {
    await _stopManagedProcess();
    await _terminateStaleShareServers();
    _started = false;
  }

  Future<void> _stopManagedProcess() async {
    final process = _process;
    if (!_managedByApp || process == null) return;

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
    _managedByApp = false;
  }

  Future<bool> _tryReuseExisting() async {
    if (!await _probe()) return false;
    _started = true;
    _managedByApp = false;
    debugPrint('[ShareServer] 复用已运行的 Go 服务');
    return true;
  }

  Future<bool> _probe() async {
    try {
      return await ShareServerDiscovery(
        serverBaseUri: ShareServerConfig.defaultBaseUri,
      ).probe(timeout: const Duration(seconds: 2));
    } catch (_) {
      return false;
    }
  }

  Future<void> _terminateStaleShareServers() async {
    if (Platform.isWindows) return;

    final result = await Process.run('pgrep', ['-f', 'instant-share-server']);
    if (result.exitCode != 0) return;

    for (final line in result.stdout.toString().trim().split('\n')) {
      final pid = int.tryParse(line.trim());
      if (pid == null || pid == _process?.pid) continue;
      debugPrint('[ShareServer] 终止残留进程 pid=$pid');
      try {
        Process.killPid(pid, ProcessSignal.sigterm);
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 400));
  }

  /// 8080 被非 Instant Share 占用时释放（仅 Debug）。
  Future<void> _freePortIfForeignService() async {
    if (!kDebugMode || Platform.isWindows) return;
    if (await _probe()) return;

    final result = await Process.run('lsof', [
      '-ti',
      'tcp:${ShareServerConfig.defaultPort}',
    ]);
    if (result.exitCode != 0) return;

    debugPrint(
      '[ShareServer] 端口 ${ShareServerConfig.defaultPort} 被占用且探活失败，尝试释放',
    );
    for (final line in result.stdout.toString().trim().split('\n')) {
      final pid = int.tryParse(line.trim());
      if (pid == null || pid == _process?.pid) continue;
      try {
        Process.killPid(pid, ProcessSignal.sigterm);
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _waitForHealthy({
    required Duration timeout,
    required Duration interval,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _probe()) return;
      if (_process == null) break;
      await Future.delayed(interval);
    }

    if (await _probe()) return;

    await _stopManagedProcess();
    throw ShareServerException(
      message:
          'Go 服务启动失败，请重新编译 assets/bin/instant-share-server（需含 /api/v1/server/health）',
    );
  }
}
