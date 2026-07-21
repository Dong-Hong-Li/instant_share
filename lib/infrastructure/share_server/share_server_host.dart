import 'dart:io';

import 'package:instant_share/infrastructure/share_server/embedded_server_runtime.dart';
import 'package:instant_share/infrastructure/share_server/process_server_runtime.dart';
import 'package:instant_share/infrastructure/share_server/share_server_runtime.dart';

/// 按平台选择分享服务运行时。
///
/// Windows 优先子进程（无需 MinGW/CGO 即可用当前 Go 源码构建）；
/// 其它桌面/Android 继续使用 c-shared 进程内库。
class ShareServerHost {
  ShareServerHost._();

  /// 单例实例。
  static ShareServerRuntime get instance {
    if (Platform.isWindows) {
      return ProcessServerRuntime.instance;
    }
    return EmbeddedServerRuntime.instance;
  }
}
