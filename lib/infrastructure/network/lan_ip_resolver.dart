import 'dart:io';

import 'package:flutter/services.dart';
import 'package:instant_share/infrastructure/network/lan_ip_unavailable_exception.dart';

/// 读取本机可用于局域网分享的 IPv4 列表。
abstract class LanIpResolver {
  const LanIpResolver();

  /// 按优先级排序的私网 IPv4；无可用地址时返回空列表。
  Future<List<String>> getLanIps();
}

/// 非 Android 平台：不由原生层提供 IP。
class NoOpLanIpResolver extends LanIpResolver {
  const NoOpLanIpResolver();

  @override
  Future<List<String>> getLanIps() async => const [];
}

/// Android：通过 MethodChannel 由 Kotlin 读取 WiFi / 网卡 IP。
class AndroidLanIpResolver extends LanIpResolver {
  AndroidLanIpResolver();

  static const _channel = MethodChannel('com.example.instant_share/network');

  @override
  Future<List<String>> getLanIps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getLanIps');
      if (result == null || result.isEmpty) return const [];
      return result
          .map((ip) => '$ip'.trim())
          .where((ip) => ip.isNotEmpty)
          .toList(growable: false);
    } on PlatformException catch (error) {
      throw LanIpUnavailableException(message: error.message ?? '无法读取局域网 IP');
    }
  }
}

LanIpResolver createLanIpResolver() {
  if (!Platform.isAndroid) return const NoOpLanIpResolver();
  return AndroidLanIpResolver();
}
