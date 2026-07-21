import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:instant_share/infrastructure/share_server/share_server_exception.dart';
import 'package:instant_share/infrastructure/share_server/share_server_health.dart';

/// 通过 HTTP 探测本地 Go 服务并获取 WebSocket 地址。
class ShareServerDiscovery {
  ShareServerDiscovery({required this.serverBaseUri});

  static const _healthPath = '/api/v1/server/health';

  /// serverBase链接。
  final Uri serverBaseUri;

  /// 拉取服务健康信息；失败立即抛出。
  Future<ShareServerHealthDto> fetchHealth({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final data = await _fetchHealthData(timeout: timeout);
    if (data == null) {
      throw const ShareServerException(
        message: '本地 Go 服务不可用，请确认已执行 build_lib 并重新运行 App',
      );
    }
    return ShareServerHealthDto.fromJson(data);
  }

  Future<Map<String, dynamic>?> _fetchHealthData({
    required Duration timeout,
  }) async {
    try {
      final uri = serverBaseUri.replace(path: _healthPath);
      final response = await _get(uri, timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);

      if (response.statusCode != HttpStatus.ok) {
        throw ShareServerException(
          message: _errorMessageFromBody(body, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
        throw ShareServerException(
          message: decoded is Map
              ? '${decoded['message']}'
              : 'invalid response',
        );
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return null;
      if (!_isInstantShareService(data)) return null;

      return data;
    } on SocketException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ShareServerException(message: error.toString()),
        stackTrace,
      );
    } on TimeoutException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ShareServerException(message: error.toString()),
        stackTrace,
      );
    }
  }

  Future<HttpClientResponse> _get(Uri uri, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      return await request.close().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }

  bool _isInstantShareService(Map<String, dynamic> data) {
    return data['service'] == 'instant-share-server' &&
        data.containsKey('ws_url');
  }

  String _errorMessageFromBody(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    if (body.trim().isEmpty) return 'HTTP $statusCode';
    return body.trim();
  }
}
