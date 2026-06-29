import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';

/// 文章正文输入快捷键（换行 / 创建）。
abstract final class HomeArticleInputShortcuts {
  /// Shift+Enter；macOS 为 ⌘+Enter，其它桌面为 Ctrl+Enter。
  static bool shouldInsertNewlineOnEnter() {
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed) return true;

    if (Platform.isMacOS) {
      return keyboard.isMetaPressed || keyboard.isControlPressed;
    }
    return keyboard.isControlPressed;
  }

  static String get contentHintText {
    if (Platform.isMacOS) {
      return '输入文章内容，回车创建，Shift/⌘+回车换行';
    }
    return '输入文章内容，回车创建，Shift/Ctrl+回车换行';
  }
}

/// 多行输入框滚动辅助（程序插入换行后同步视口）。
abstract final class HomeArticleInputScroll {
  static double get lineHeight => f14 * 1.5;

  static void scrollToCaret({
    required TextEditingController controller,
    required ScrollController scrollController,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      final selection = controller.selection;
      if (!selection.isValid) return;

      final text = controller.text;
      final offset = selection.extentOffset.clamp(0, text.length);
      final textBefore = text.substring(0, offset);
      final lineIndex = '\n'.allMatches(textBefore).length;
      final caretTop = lineIndex * lineHeight;
      final caretBottom = caretTop + lineHeight;

      final position = scrollController.position;
      final viewportTop = position.pixels;
      final viewportBottom = viewportTop + position.viewportDimension;

      double? target;
      if (caretBottom > viewportBottom) {
        target = caretBottom - position.viewportDimension;
      } else if (caretTop < viewportTop) {
        target = caretTop;
      }

      if (target == null) return;
      scrollController.jumpTo(target.clamp(0.0, position.maxScrollExtent));
    });
  }
}

/// 无滚动条、无回弹的多行输入滚动行为。
class HomeArticleInputScrollBehavior extends ScrollBehavior {
  const HomeArticleInputScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
