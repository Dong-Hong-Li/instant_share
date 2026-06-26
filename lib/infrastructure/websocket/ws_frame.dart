import 'package:instant_share/infrastructure/websocket/ws_constants.dart';
import 'package:instant_share/infrastructure/websocket/ws_exception.dart';

/// WS 鉴权首帧（仅 admin）。
class WsAuthRequest {
  const WsAuthRequest({required this.role, required this.deviceId});

  const WsAuthRequest.admin({required this.deviceId}) : role = WsRole.admin;

  final String role;
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

  final String type;
  final String? requestId;
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

  final String type;
  final String? requestId;
  final int code;
  final String message;
  final dynamic data;

  bool get isSuccess => code == WsCode.success;

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

class WsJsonMessage extends WsIncomingMessage {
  WsJsonMessage(this.response);

  final WsResponse response;
}

class WsBinaryMessage extends WsIncomingMessage {
  WsBinaryMessage(this.bytes);

  final List<int> bytes;
}
