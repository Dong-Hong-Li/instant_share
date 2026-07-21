import 'package:ai_localizations/ai_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instant_share/core/shared/theme_manager.dart';
import 'package:instant_share/core/ui/extension/localizations_extension.dart';
import 'package:instant_share/core/ui/extension/theme_extension.dart';
export 'package:instant_share/resource/screen_utils/screen_dimens.dart';
export 'package:instant_share/resource/screen_utils/font_size.dart';
export 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';
export 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
export 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';

/// Common混入。
mixin CommonMixin {
  BuildContext? _context;

  BuildContext get ctx => _context!;

  /// 系统导航栏样式
  /// 默认使用主题管理器中的系统导航栏样式
  /// 如果需要自定义系统导航栏样式，可以重写此方法
  SystemUiOverlayStyle? get systemOverlayStyle =>
      ThemeManager.instance.systemOverlayStyle;

  /// 主题色（与 ThemeManager / MaterialApp themeMode 同源）。
  ColorValue get tc => ctx.themeColor;

  /// 本地化。
  LocalizationsSdk get l10n => ctx.l10n;

  /// initBaseCommon。
  @protected
  void initBaseCommon(BuildContext context) {
    _context = context;
  }
}
