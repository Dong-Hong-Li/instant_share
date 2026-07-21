/// 本地 Go 分享服务地址配置。
class ShareServerConfig {
  ShareServerConfig._();

  /// 传给 Go 服务表示由操作系统分配空闲端口。
  static const int systemAllocatedPort = 0;

  /// base链接ForPort。
  static Uri baseUriForPort(int port) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: port);
}
