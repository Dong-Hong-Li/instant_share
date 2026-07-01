part of 'link_page.dart';

mixin _LinkPageStateMixin on State<LinkPage> {
  @override
  Widget build(BuildContext context) {
    return _LinkPageContent(colorValue: widget.colorValue);
  }
}
