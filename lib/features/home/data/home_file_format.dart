/// 格式化文件大小展示。
String formatHomeFileSize(int bytes) {
  /// 单位。
  const unit = 1024;
  if (bytes < unit) return '$bytes B';

  /// 大小。
  var size = bytes.toDouble();

  /// 单位列表。
  const units = ['KB', 'MB', 'GB', 'TB'];

  /// 单位索引。
  var unitIndex = -1;

  while (size >= unit && unitIndex < units.length - 1) {
    size /= unit;
    unitIndex++;
  }

  /// 小数精度。
  final precision = size >= 100 || unitIndex == 0 ? 0 : 1;
  return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
}
