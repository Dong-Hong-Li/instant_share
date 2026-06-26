import 'package:flutter/widgets.dart';

import 'rx_dependency_tracker.dart';

/// GetX [Obx] 风格：builder 内读到的 [Rx.value] 会自动订阅；这些 [Rx] 变化时仅重建本 Widget。
///
/// ```dart
/// final count = Rx(0);
///
/// Obx(() => Text('${count.value}'))
/// ```
class Obx extends StatefulWidget {
  const Obx(this.builder, {super.key});

  final Widget Function() builder;

  @override
  State<Obx> createState() => _ObxState();
}

class _ObxState extends State<Obx> {
  late final RxCollector _collector = RxCollector(_onRx);

  void _onRx() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _collector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _collector.clear();
    return RxDependencyTracker.instance.collect(_collector, widget.builder);
  }
}
