import 'package:flutter/material.dart';
import 'package:instant_share/core/ui/base/base_state_page.dart';

export 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:instant_share/core/ui/base/base_state_page.dart';
export 'package:instant_share/resource/screen_utils/font_size.dart';
export 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';
export 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
export 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';

/// 让 [BaseStatePage] 拥有一个 Riverpod [WidgetRef]。
///
/// 子页面通过重写 [buildPage] 拿到 (context, ref)，
/// 在 build 之外的方法里也可通过 [ref] getter 访问（仅在 mount 之后有效）。
///
/// 实现细节：内部用一个 [Consumer] 把 `widget.builder` 的 ref 暴露出来；
/// 由于 Consumer 自身是 StatefulWidget，每个页面会拥有一个稳定的 ConsumerStatefulElement，
/// `ref.watch` / `ref.read` 的订阅生命周期与该 Element 绑定，符合 Riverpod 设计。
mixin AppConsumerMixin on CommonMixin {
  WidgetRef? _ref;

  /// 当前页面的 [WidgetRef]。仅在 [buildPageWithRef] 至少触发一次后非空。
  WidgetRef get ref {
    assert(_ref != null, 'ref is not initialized, please use buildPageWithRef');
    return _ref!;
  }

  /// 页面内容。子页面在 build 中通过 ref 访问 provider。
  Widget buildPage(BuildContext context, WidgetRef ref);

  /// build页面WithRef。
  Widget buildPageWithRef(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        _ref = ref;
        return buildPage(context, ref);
      },
    );
  }
}
