part of 'setting_page.dart';

mixin _SettingPageStateMixin on State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    return _SettingPageContent(colorValue: widget.colorValue);
  }
}
