import 'package:instant_share/core/controller/share_port_controller.dart';
import 'package:instant_share/core/utils/port/port_util.dart';
import 'package:instant_share/infrastructure/share_server/share_server_config.dart';
import 'package:state_scope/state_scope.dart';

/// 解析冷启动应传给 Go 服务的监听端口。
int resolveShareServerListenPort() {
  try {
    final listen = DI.find<SharePortController>().listenPortOrNull;
    if (listen != null && PortUtil.isValidCustomPort(listen)) {
      return listen;
    }
  } catch (_) {}
  return ShareServerConfig.systemAllocatedPort;
}
