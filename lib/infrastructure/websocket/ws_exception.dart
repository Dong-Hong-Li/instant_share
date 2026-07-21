import 'package:instant_share/infrastructure/websocket/ws_constants.dart';

/// WebSocket 业务或协议错误。
class WsException implements Exception {
  const WsException({
    required this.message,
    this.code = WsCode.internal,
    this.frameType,
    this.requestId,
  });

  /// 消息。
  final String message;

  /// 状态码。
  final int code;

  /// frameType。
  final String? frameType;

  /// 请求 ID。
  final String? requestId;

  /// 转为调试文本。
  @override
  String toString() {
    final type = frameType == null ? '' : ', type=$frameType';
    final req = requestId == null ? '' : ', requestId=$requestId';
    return 'WsException(code=$code$type$req): $message';
  }
}
