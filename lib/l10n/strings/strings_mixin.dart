import 'package:ai_localizations/ai_localizations.dart';

/// 混入Strings。
mixin MixinStrings {
  /// 国际化消息。
  String intlMessage(
    String messageText, {
    required String sid,
    Map<String, Object>? args,
  }) {
    return TranslatorApiAccess.instance.translator.translate(
      defaultEn: messageText,
      sid: sid,
      args: args,
    );
  }
}
