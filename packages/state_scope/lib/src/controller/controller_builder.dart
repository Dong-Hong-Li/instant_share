import 'package:flutter/material.dart';

import '../di/di.dart';
import 'app_controller.dart';

/// 当 [T] 调用 [AppController.update] 时重建。
/// 从 [DI] 解析 [T]；若注册时带了 tag，则传入 [tag]。
///
/// **ID 策略**（可选 [id]）：
/// - [id] 为 null：监听全量 `update()`，任意 update() 都会重建。
/// - [id] 非 null：仅当 `update(['thisId'])` 包含该 id 时才重建，适合局部刷新。
class ControllerBuilder<T extends AppController> extends StatelessWidget {
  const ControllerBuilder({
    super.key,
    this.tag,
    this.id,
    required this.builder,
  });

  /// 注册到 DI 时使用的 tag，与 [DI.put] 的 tag 一致。
  final String? tag;

  /// 可选。指定后仅当 controller.update([id]) 包含该 id 时重建，实现局部刷新。
  final Object? id;

  final Widget Function(T controller) builder;

  @override
  Widget build(BuildContext context) {
    final controller = DI.find<T>(tag: tag);
    if (id == null) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => builder(controller),
      );
    }
    return _IdControllerBuilder(
        controller: controller, id: id!, builder: builder);
  }
}

class _IdControllerBuilder<T extends AppController> extends StatefulWidget {
  const _IdControllerBuilder({
    required this.controller,
    required this.id,
    required this.builder,
  });

  final T controller;
  final Object id;
  final Widget Function(T controller) builder;

  @override
  State<_IdControllerBuilder<T>> createState() =>
      _IdControllerBuilderState<T>();
}

class _IdControllerBuilderState<T extends AppController>
    extends State<_IdControllerBuilder<T>> {
  @override
  void initState() {
    super.initState();
    widget.controller.addIdListener(widget.id, _onIdUpdate);
  }

  void _onIdUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeIdListener(widget.id, _onIdUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(widget.controller);
  }
}
