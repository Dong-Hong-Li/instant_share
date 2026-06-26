/// 本地 Go 服务探测失败。
class ShareServerException implements Exception {
  const ShareServerException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) return 'ShareServerException: $message';
    return 'ShareServerException($statusCode): $message';
  }
}
