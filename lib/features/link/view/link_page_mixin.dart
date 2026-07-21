part of 'link_page.dart';

mixin _LinkPageStateMixin on State<LinkPage> {
  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    widget.mutual.ensureHostAdminListening();
  }

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return _LinkPageContent(
      colorValue: widget.colorValue,
      mutual: widget.mutual,
    );
  }
}
