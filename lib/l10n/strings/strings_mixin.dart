import 'package:ai_localizations/ai_localizations.dart';

mixin MixinStrings {
  String intlMessage(String messageText, {required String sid, Map<String, Object>? args}) {
    return TranslatorApiAccess.instance.translator.translate(defaultEn: messageText, sid: sid, args: args);
  }
}
