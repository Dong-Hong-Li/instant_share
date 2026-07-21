part of 'config_page.dart';

mixin _ConfigPageStateMixin on State<ConfigPage> {
  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return _ConfigPageContent(colorValue: widget.colorValue);
  }
}
