import 'package:instant_share/infrastructure/websocket/ws_constants.dart';
import 'package:instant_share/infrastructure/websocket/ws_exception.dart';

/// WS 鉴权首帧（仅 admin）。
class WsAuthRequest {
  const WsAuthRequest({required this.role, required this.deviceId});

  /// WSAuth请求。
  const WsAuthRequest.admin({required this.deviceId}) : role = WsRole.admin;

  /// WSAuth请求。
  const WsAuthRequest.peer({required this.deviceId}) : role = WsRole.peer;

  /// 角色。
  final String role;

  /// 设备 ID。
  final String deviceId;

  Map<String, dynamic> toJson() => {
    'type': WsFrameType.auth,
    'role': role,
    'device_id': deviceId,
  };
}

/// 出站 JSON 帧。
class WsPacket {
  const WsPacket({required this.type, this.requestId, this.data});

  /// 类型。
  final String type;

  /// 请求 ID。
  final String? requestId;

  /// 数据。
  final Object? data;

  Map<String, dynamic> toJson() => {
    'type': type,
    if (requestId != null && requestId!.isNotEmpty) 'request_id': requestId,
    if (data != null) 'data': data,
  };
}

/// 入站 JSON 响应帧。
class WsResponse {
  const WsResponse({
    required this.type,
    required this.code,
    required this.message,
    this.requestId,
    this.data,
  });

  factory WsResponse.fromJson(Map<String, dynamic> json) {
    return WsResponse(
      type: json['type'] as String? ?? '',
      requestId: json['request_id'] as String?,
      code: json['code'] as int? ?? WsCode.internal,
      message: json['message'] as String? ?? '',
      data: json['data'],
    );
  }

  /// 类型。
  final String type;

  /// 请求 ID。
  final String? requestId;

  /// 状态码。
  final int code;

  /// 消息。
  final String message;

  /// 数据。
  final dynamic data;

  /// 是否成功。
  bool get isSuccess => code == WsCode.success;

  /// 确保响应成功。
  void ensureSuccess() {
    if (isSuccess) return;
    throw WsException(
      message: message.isEmpty ? 'request failed' : message,
      code: code,
      frameType: type,
      requestId: requestId,
    );
  }
}

/// 入站消息：JSON 响应或二进制分片。
sealed class WsIncomingMessage {}

/// WS JSON 消息。
class WsJsonMessage extends WsIncomingMessage {
  WsJsonMessage(this.response);

  /// 响应数据。
  final WsResponse response;
}

/// WS 二进制消息。
class WsBinaryMessage extends WsIncomingMessage {
  WsBinaryMessage(this.bytes);

  /// 字节数据。
  final List<int> bytes;
}
