import 'dart:io';

import 'package:instant_share/infrastructure/network/lan_ip_resolver.dart';
import 'package:instant_share/infrastructure/network/lan_ip_unavailable_exception.dart';
import 'package:instant_share/infrastructure/share_server/share_server_exception.dart';
import 'package:instant_share/infrastructure/share_server/share_server_health.dart';
import 'package:instant_share/infrastructure/websocket/ws_share_models.dart';

/// 解析后的分享地址（主地址 + 备选局域网地址）。
class ResolvedShareUrls {
  const ResolvedShareUrls({
    required this.primaryUrl,
    this.alternateUrls = const [],
  });

  /// primary地址。
  final String primaryUrl;

  /// 备用地址列表。
  final List<String> alternateUrls;
}

/// 按平台策略解析对外分享的 HTTP URL。
///
/// - **Android**：以 Kotlin [LanIpResolver] 为唯一 IP 来源；读不到则抛 [LanIpUnavailableException]。
/// - **桌面端**：以 Go 服务返回的 `share_url` / `local_ips` 为准。
class ShareUrlResolver {
  ShareUrlResolver({required LanIpResolver lanIpResolver})
    : _lanIpResolver = lanIpResolver;

  final LanIpResolver _lanIpResolver;

  /// 从健康状态解析地址。
  Future<ResolvedShareUrls> resolveFromHealth(ShareServerHealthDto health) {
    return resolve(
      port: health.port,
      goShareUrl: health.shareUrl,
      goLanIp: health.lanIp,
      goLocalIps: health.localIps,
    );
  }

  /// 从分享状态解析地址。
  Future<ResolvedShareUrls> resolveFromStatus(ShareStatusDto status) {
    final port = status.port;
    if (port == null || port <= 0) {
      throw const ShareServerException(message: 'Go 服务未返回有效端口');
    }
    return resolve(
      port: port,
      goShareUrl: status.baseUrl,
      goLanIp: status.ip,
      goLocalIps: null,
    );
  }

  /// 解析分享地址。
  Future<ResolvedShareUrls> resolve({
    required int port,
    String? goShareUrl,
    String? goLanIp,
    List<String>? goLocalIps,
  }) async {
    if (port <= 0) {
      throw const ShareServerException(message: 'Go 服务未返回有效端口');
    }

    if (Platform.isAndroid) {
      return _resolveAndroid(port: port);
    }
    return _resolveDesktop(
      port: port,
      goShareUrl: goShareUrl,
      goLanIp: goLanIp,
      goLocalIps: goLocalIps,
    );
  }

  Future<ResolvedShareUrls> _resolveAndroid({required int port}) async {
    final ips = await _lanIpResolver.getLanIps();
    if (ips.isEmpty) {
      throw const LanIpUnavailableException(message: '无法获取局域网 IP，请连接 WiFi 后重试');
    }

    final primary = ips.first;
    final alternates = ips
        .skip(1)
        .map((ip) => 'http://$ip:$port/share')
        .toList(growable: false);

    return ResolvedShareUrls(
      primaryUrl: 'http://$primary:$port/share',
      alternateUrls: alternates,
    );
  }

  ResolvedShareUrls _resolveDesktop({
    required int port,
    String? goShareUrl,
    String? goLanIp,
    List<String>? goLocalIps,
  }) {
    final trimmedUrl = goShareUrl?.trim();
    if (trimmedUrl != null &&
        trimmedUrl.isNotEmpty &&
        _isUsablePrivateEndpoint(trimmedUrl, goLanIp)) {
      return ResolvedShareUrls(
        primaryUrl: trimmedUrl,
        alternateUrls: _desktopAlternates(
          port: port,
          primaryIp: goLanIp,
          localIps: goLocalIps,
        ),
      );
    }

    final ips = _usableGoIps(goLanIp: goLanIp, goLocalIps: goLocalIps);
    if (ips.isEmpty) {
      throw const ShareServerException(message: 'Go 服务未返回可用的局域网分享地址');
    }

    final primary = ips.first;
    return ResolvedShareUrls(
      primaryUrl: 'http://$primary:$port/share',
      alternateUrls: ips
          .skip(1)
          .map((ip) => 'http://$ip:$port/share')
          .toList(growable: false),
    );
  }

  List<String> _desktopAlternates({
    required int port,
    required String? primaryIp,
    required List<String>? localIps,
  }) {
    final ips = _usableGoIps(goLanIp: primaryIp, goLocalIps: localIps);
    if (ips.length <= 1) return const [];
    return ips
        .skip(1)
        .map((ip) => 'http://$ip:$port/share')
        .toList(growable: false);
  }

  List<String> _usableGoIps({
    required String? goLanIp,
    required List<String>? goLocalIps,
  }) {
    final seen = <String>{};
    final ips = <String>[];

    void add(String? raw) {
      final ip = raw?.trim();
      if (ip == null ||
          ip.isEmpty ||
          !isPrivateLanIp(ip) ||
          seen.contains(ip)) {
        return;
      }
      seen.add(ip);
      ips.add(ip);
    }

    add(goLanIp);
    for (final ip in goLocalIps ?? const []) {
      add(ip);
    }
    return ips;
  }

  bool _isUsablePrivateEndpoint(String url, String? goLanIp) {
    final ip = goLanIp?.trim();
    if (ip != null && ip.isNotEmpty) {
      return isPrivateLanIp(ip);
    }
    final host = Uri.tryParse(url)?.host;
    return host != null && isPrivateLanIp(host);
  }
}

/// RFC1918 私网 IPv4（不含 127.0.0.1）。
bool isPrivateLanIp(String ip) {
  if (ip == '127.0.0.1' || ip.startsWith('127.')) return false;

  /// parts。
  final parts = ip.split('.');
  if (parts.length != 4) return false;

  /// a。
  final a = int.tryParse(parts[0]);

  /// b。
  final b = int.tryParse(parts[1]);
  if (a == null || b == null) return false;

  if (a == 10) return true;
  if (a == 192 && b == 168) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  return false;
}
