import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 屏幕适配尺寸快照（在 [ScreenUtilInit] 之后 [ensureInitialized] 一次）。
///
/// 数值为 **final 快照**：旋转/分屏后如需跟随变化，可调用 [reset] 再在下一帧 [ensureInitialized]。
class ScreenDimens {
  ScreenDimens._();

  static ScreenDimens? _instance;

  static ScreenDimens get instance {
    assert(
      _instance != null,
      'ScreenDimens：请先在 ScreenUtilInit.builder 内调用 ensureInitialized()。',
    );
    return _instance!;
  }

  /// 在 **ScreenUtilInit 的子树中**、首次构建时调用；重复调用忽略。
  static void ensureInitialized() {
    if (_instance != null) return;
    final d = ScreenDimens._();
    const max = _maxIndex;
    d._w = List<double>.generate(max + 1, (i) => i.w);
    d._h = List<double>.generate(max + 1, (i) => i.h);
    d._s = List<double>.generate(max + 1, (i) => i.r);
    d._f = List<double>.generate(max + 1, (i) => i.sp);
    _instance = d;
  }

  /// 调试或强制按当前 ScreenUtil 重算（例如重建根前调用）。
  static void reset() {
    _instance = null;
  }

  static const int _maxIndex = 500;

  late final List<double> _w;
  late final List<double> _h;
  late final List<double> _s;
  late final List<double> _f;

  double w(int i) {
    assert(i >= 0 && i <= _maxIndex);
    return _w[i];
  }

  double h(int i) {
    assert(i >= 0 && i <= _maxIndex);
    return _h[i];
  }

  double s(int i) {
    assert(i >= 0 && i <= _maxIndex);
    return _s[i];
  }

  double font(int i) {
    assert(i >= 0 && i <= _maxIndex);
    return _f[i];
  }
}
