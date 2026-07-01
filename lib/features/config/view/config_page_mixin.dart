part of 'config_page.dart';

mixin _ConfigPageStateMixin on State<ConfigPage> {
  @override
  Widget build(BuildContext context) {
    return _ConfigPageContent(colorValue: widget.colorValue);
  }
}
