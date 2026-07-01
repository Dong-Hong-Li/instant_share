/// Android 策略：Kotlin 无法读取局域网 IP 时抛出（非兜底，必须显式失败）。
class LanIpUnavailableException implements Exception {
  const LanIpUnavailableException({required this.message});

  final String message;

  @override
  String toString() => 'LanIpUnavailableException: $message';
}
