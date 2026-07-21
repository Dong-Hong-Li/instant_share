/// 首页已选中的本地文件。
class HomeFileItem {
  const HomeFileItem({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
  });

  /// ID。
  final String id;

  /// 路径。
  final String path;

  /// 名称。
  final String name;

  /// 大小。
  final int size;
}
