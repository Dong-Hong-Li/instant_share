/// 本地分享服务运行时抽象（c-shared 动态库进程内运行，dart:ffi）。
abstract class ShareServerRuntime {
  /// 确保服务已启动（幂等）。
  Future<void> ensureStarted();

  /// 停止服务（幂等）。
  Future<void> stop();

  /// 是否已启动。
  bool get isStarted;

  /// 实际监听端口；未启动时为 null。
  int? get port;
}
