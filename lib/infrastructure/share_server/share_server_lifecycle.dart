import 'package:flutter/material.dart';
import 'package:instant_share/core/config/common.dart';
import 'package:instant_share/infrastructure/share_server/embedded_server_runtime.dart';

/// 监听 App 生命周期，退出时关闭由 App 托管的 Go 子进程。
class ShareServerLifecycle extends StatefulWidget {
  const ShareServerLifecycle({super.key, required this.child});

  final Widget child;

  @override
  State<ShareServerLifecycle> createState() => _ShareServerLifecycleState();
}

class _ShareServerLifecycleState extends State<ShareServerLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached && CommonContext.isDesktop) {
      EmbeddedServerRuntime.instance.stop();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
