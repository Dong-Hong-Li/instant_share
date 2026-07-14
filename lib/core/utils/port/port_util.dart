import 'dart:io';

/// 自定义分享端口常量与空闲检测。
class PortUtil {
  PortUtil._();

  static const int kMinCustomSharePort = 11285;
  static const int kMaxCustomSharePort = 65535;

  /// 是否为合法自定义端口（闭区间）。
  static bool isValidCustomPort(int port) =>
      port >= kMinCustomSharePort && port <= kMaxCustomSharePort;

  /// 检测端口是否空闲。
  ///
  /// [ownedByCurrentServer] 为本进程分享服务已监听端口时，视为可用（避免自占用误判）。
  /// 覆盖 Android / macOS / Windows / Linux（依赖 `dart:io`）。
  static Future<bool> isPortFree(
    int port, {
    int? ownedByCurrentServer,
  }) async {
    if (ownedByCurrentServer != null && ownedByCurrentServer == port) {
      return true;
    }

    try {
      final socket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        shared: false,
      );
      await socket.close();
      return true;
    } on SocketException {
      return false;
    }
  }
}
