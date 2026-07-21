import 'package:flutter/material.dart';
import 'package:instant_share/core/config/common.dart';
import 'package:instant_share/infrastructure/share_server/share_server_host.dart';

/// 监听 App 生命周期，退出时关闭进程内 Go 分享服务。
class ShareServerLifecycle extends StatefulWidget {
  const ShareServerLifecycle({super.key, required this.child});

  /// 子组件。
  final Widget child;

  /// 创建状态对象。
  @override
  State<ShareServerLifecycle> createState() => _ShareServerLifecycleState();
}

class _ShareServerLifecycleState extends State<ShareServerLifecycle>
    with WidgetsBindingObserver {
  /// 初始化状态。
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// 释放资源。
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// didChange应用Lifecycle状态。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached &&
        (CommonContext.isDesktop || CommonContext.isAndroid)) {
      ShareServerHost.instance.stop();
    }
  }

  /// 构建界面。
  @override
  Widget build(BuildContext context) => widget.child;
}
