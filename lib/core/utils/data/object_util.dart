/// 对象工具。
class ObjectUtil {
  /// Returns true  String or List or Map is empty.
  static bool isEmpty(Object? object) {
    if (object == null) return true;
    if (object is String && object.isEmpty) {
      return true;
    } else if (object is Iterable && object.isEmpty) {
      return true;
    } else if (object is Map && object.isEmpty) {
      return true;
    }
    return false;
  }

  /// Returns true String or List or Map is not empty.
  static bool isNotEmpty(Object? object) {
    return !isEmpty(object);
  }

  /// 隐藏中间几位
  static String hideNumber(
    String phoneNo, {
    int start = 3,
    int end = 7,
    String replacement = '****',
  }) {
    return phoneNo.replaceRange(start, end, replacement);
  }
}
