/// 本地 Go 分享服务默认地址（与 [instant_share_server] 默认端口一致）。
class ShareServerConfig {
  ShareServerConfig._();

  static const int defaultPort = 8080;

  static final Uri defaultBaseUri = Uri.parse('http://127.0.0.1:$defaultPort');
}
