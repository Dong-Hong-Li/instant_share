/// Android 策略：Kotlin 无法读取局域网 IP 时抛出（非兜底，必须显式失败）。
class LanIpUnavailableException implements Exception {
  const LanIpUnavailableException({required this.message});

  /// 消息。
  final String message;

  /// 转为调试文本。
  @override
  String toString() => 'LanIpUnavailableException: $message';
}
