part of 'setting_page.dart';

mixin _SettingPageStateMixin on State<SettingPage> {
  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return _SettingPageContent(
      colorValue: widget.colorValue,
      isSharing: widget.isSharing,
    );
  }
}
