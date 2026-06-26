/// 首页已选中的本地文件。
class HomeFileItem {
  const HomeFileItem({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
  });

  final String id;
  final String path;
  final String name;
  final int size;
}
