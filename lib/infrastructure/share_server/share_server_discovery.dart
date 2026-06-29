import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:instant_share/infrastructure/share_server/share_server_exception.dart';
import 'package:instant_share/infrastructure/share_server/share_server_health.dart';
import 'package:instant_share/infrastructure/websocket/ws_share_models.dart';

/// 通过 HTTP 探测本地 Go 服务并获取 WebSocket 地址。
class ShareServerDiscovery {
  ShareServerDiscovery({required this.serverBaseUri});

  static const _healthPaths = ['/api/v1/server/health', '/health'];

  final Uri serverBaseUri;

  /// 是否为 Instant Share Go 服务（轻量探活，供启动轮询使用）。
  Future<bool> probe({Duration timeout = const Duration(seconds: 2)}) async {
    final data = await _fetchHealthData(timeout: timeout);
    return data != null;
  }

  /// 拉取服务健康信息；失败立即抛出
  Future<ShareServerHealthDto> fetchHealth({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final data = await _fetchHealthData(timeout: timeout);
    if (data == null) {
      throw const ShareServerException(
        message: '本地 Go 服务不可用，请确认 instant-share-server 已更新并重新打包',
      );
    }
    return _parseHealthData(data);
  }

  Future<Map<String, dynamic>?> _fetchHealthData({
    required Duration timeout,
  }) async {
    ShareServerException? lastError;

    for (final path in _healthPaths) {
      try {
        final uri = serverBaseUri.replace(path: path);
        final response = await _get(uri, timeout);
        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(timeout);

        if (response.statusCode != HttpStatus.ok) {
          lastError = ShareServerException(
            message: _errorMessageFromBody(body, response.statusCode),
            statusCode: response.statusCode,
          );
          continue;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
          lastError = ShareServerException(
            message: decoded is Map
                ? '${decoded['message']}'
                : 'invalid response',
          );
          continue;
        }

        final data = decoded['data'];
        if (data is! Map<String, dynamic>) continue;
        if (!_isInstantShareService(data)) continue;

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
      } catch (error) {
        lastError = ShareServerException(message: error.toString());
      }
    }

    if (lastError != null) throw lastError;
    return null;
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
    if (data['service'] == 'instant-share-server') return true;
    if (data['healthy'] == true && data.containsKey('ws_url')) return true;
    return false;
  }

  ShareServerHealthDto _parseHealthData(Map<String, dynamic> data) {
    if (data.containsKey('ws_url')) {
      return ShareServerHealthDto.fromJson(data);
    }

    final port = serverBaseUri.port;
    return ShareServerHealthDto(
      service: 'instant-share-server',
      healthy: true,
      port: port,
      lanIp: '127.0.0.1',
      httpBase: 'http://127.0.0.1:$port',
      wsUrl: 'ws://127.0.0.1:$port/ws',
      shareUrl: data['share_url'] as String? ?? 'http://127.0.0.1:$port/share',
      share: const ShareStatusDto(active: false, files: []),
    );
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
