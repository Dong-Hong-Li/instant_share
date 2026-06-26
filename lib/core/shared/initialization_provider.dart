import 'dart:async';
import 'package:flutter/material.dart';

class InitializationProvider {
  final List<AsyncInitTask> _criticalTasks = [];
  final List<AsyncInitTask> _bestEffortTasks = [];
  final Map<String, InitResult> _results = {};

  /// 添加任务
  ///
  /// `name` 任务名称
  ///
  /// `task` 任务执行函数
  ///
  /// `critical` 是否关键任务 默认 false
  ///
  /// `priority` 任务优先级 默认 0
  ///
  /// `retryCount` 任务重试次数 默认 0
  ///
  /// `timeout` 任务超时时间 默认 10秒
  ///
  ///
  /// ```dart
  /// addTask(
  ///   name: 'router_init',
  ///   task: () async {
  ///     final router = RouteConfig.instance;
  ///     router.initAllHandlers();
  ///     FluroConfig.addGuard(RouteGuards.instance.authGuard);
  ///   },
  /// );
  void addTask({
    required String name,
    required Future Function() task,
    bool critical = false,
    int priority = 0,
    int? retryCount,
    Duration? timeout,
  }) {
    final asyncTask = AsyncInitTask(
      name: name,
      task: task,
      critical: critical,
      priority: priority,
      // 关键任务快速失败，避免拖慢冷启动；非关键任务后台重试补偿。
      retryCount: retryCount ?? (critical ? 0 : 2),
      timeout:
          timeout ??
          (critical ? const Duration(seconds: 3) : const Duration(seconds: 10)),
    );
    if (critical) {
      _criticalTasks.add(asyncTask);
      return;
    }
    _bestEffortTasks.add(asyncTask);
  }

  // 执行关键任务
  Future<Map<String, InitResult>> executeCritical() async {
    await _executeByPriority(_criticalTasks);
    return _results;
  }

  // 后台执行非关键任务
  void executeBestEffortInBackground() {
    if (_bestEffortTasks.isEmpty) return;
    unawaited(_executeByPriority(_bestEffortTasks));
  }

  // 按优先级执行任务
  Future<void> _executeByPriority(List<AsyncInitTask> tasks) async {
    if (tasks.isEmpty) return;
    final grouped = <int, List<AsyncInitTask>>{};
    for (final t in tasks) {
      grouped.putIfAbsent(t.priority, () => []).add(t);
    }
    final sorted = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final p in sorted) {
      final list = grouped[p]!;
      await Future.wait(list.map((t) => _runWithRetry(t)));
    }
  }

  Future<void> _runWithRetry(AsyncInitTask task) async {
    for (int attempts = 0; attempts <= task.retryCount; attempts++) {
      try {
        debugPrint(
          'Init [${task.name}]${task.critical ? " (critical)" : " (best-effort)"}',
        );
        await task.task().timeout(
          task.timeout,
          onTimeout: () => throw TimeoutException(''),
        );
        _results[task.name] = InitResult.success(null);
        return;
      } catch (e, st) {
        if (attempts == task.retryCount) {
          _results[task.name] = InitResult.failure(e, st);
          debugPrint('Init failed [${task.name}]: $e\n$st');
          return;
        }
        await Future.delayed(Duration(seconds: attempts + 1));
      }
    }
  }
}

class AsyncInitTask {
  final String name;
  final Future Function() task;
  final bool critical;
  final int priority;
  final int retryCount;
  final Duration timeout;
  AsyncInitTask({
    required this.name,
    required this.task,
    required this.critical,
    required this.priority,
    required this.retryCount,
    required this.timeout,
  });
}

class InitResult {
  final dynamic data;
  final Object? error;
  final StackTrace? stack;
  InitResult.success(this.data) : error = null, stack = null;
  InitResult.failure(this.error, this.stack) : data = null;
  bool get isSuccess => error == null;
}
