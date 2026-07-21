part of 'link_page.dart';

mixin _LinkPageStateMixin on State<LinkPage> {
  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    widget.mutual.ensureHostAdminListening();
    return _LinkPageContent(
      colorValue: widget.colorValue,
      mutual: widget.mutual,
    );
  }
}
