/// 本地分享服务运行时抽象。
///
/// 屏蔽底层「如何运行 Go 服务」的差异，上层只关心 [ensureStarted] / [stop]：
/// - 桌面/移动端：[EmbeddedServerRuntime]，c-shared 动态库进程内运行（dart:ffi）。
/// - 历史方案：[ShareServerProcessManager]，独立二进制子进程（仅桌面，已被取代）。
///
/// 无论哪种实现，服务都监听 `localhost`，上层 Discovery / WebSocket 客户端不感知差异。
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
