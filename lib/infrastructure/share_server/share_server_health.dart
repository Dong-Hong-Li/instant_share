import 'package:instant_share/infrastructure/websocket/ws_share_models.dart';

/// Go 服务健康探测结果，对应 `/api/v1/server/health`。
class ShareServerHealthDto {
  const ShareServerHealthDto({
    required this.service,
    required this.healthy,
    required this.port,
    required this.lanIp,
    required this.localIps,
    required this.httpBase,
    required this.wsUrl,
    required this.shareUrl,
    required this.share,
  });

  final String service;
  final bool healthy;
  final int port;
  final String lanIp;
  final List<String> localIps;
  final String httpBase;
  final String wsUrl;
  final String shareUrl;
  final ShareStatusDto share;

  /// 除主分享地址外的备选局域网地址（2 个及以上 IP 时才有值）。
  List<String> get alternateShareUrls {
    if (localIps.length <= 1) return const [];

    return localIps
        .where((ip) => ip != lanIp)
        .map((ip) => 'http://$ip:$port/share')
        .toList(growable: false);
  }

  factory ShareServerHealthDto.fromJson(Map<String, dynamic> json) {
    final shareJson = json['share'];
    final share = shareJson is Map<String, dynamic>
        ? ShareStatusDto.fromJson(shareJson)
        : const ShareStatusDto(active: false, files: []);

    final lanIp = json['lan_ip'] as String;
    final localIpsRaw = json['local_ips'];
    final localIps = localIpsRaw is List
        ? localIpsRaw.map((item) => '$item').toList(growable: false)
        : <String>[lanIp];

    return ShareServerHealthDto(
      service: json['service'] as String,
      healthy: json['healthy'] as bool,
      port: (json['port'] as num).toInt(),
      lanIp: lanIp,
      localIps: localIps,
      httpBase: json['http_base'] as String,
      wsUrl: json['ws_url'] as String,
      shareUrl: json['share_url'] as String,
      share: share,
    );
  }
}
