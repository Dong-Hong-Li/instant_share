/// 本地 Go 服务探测失败。
class ShareServerException implements Exception {
  const ShareServerException({required this.message, this.statusCode});

  /// 消息。
  final String message;

  /// statusCode。
  final int? statusCode;

  /// 转为调试文本。
  @override
  String toString() {
    if (statusCode == null) return 'ShareServerException: $message';
    return 'ShareServerException($statusCode): $message';
  }
}
