/// 格式化文件大小展示。
String formatHomeFileSize(int bytes) {
  const unit = 1024;
  if (bytes < unit) return '$bytes B';

  var size = bytes.toDouble();
  const units = ['KB', 'MB', 'GB', 'TB'];
  var unitIndex = -1;

  while (size >= unit && unitIndex < units.length - 1) {
    size /= unit;
    unitIndex++;
  }

  final precision = size >= 100 || unitIndex == 0 ? 0 : 1;
  return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
}
