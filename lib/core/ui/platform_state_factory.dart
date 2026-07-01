import 'package:flutter/widgets.dart';
import 'package:instant_share/core/config/common.dart';

/// 在 [createState] 中按平台返回 PC / App 对应的 [State]。
State<T> createPlatformState<T extends StatefulWidget>({
  required State<T> Function() pc,
  required State<T> Function() app,
}) {
  return CommonContext.isDesktop ? pc() : app();
}
