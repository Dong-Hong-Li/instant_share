/// 文章分享长度限制。
abstract final class HomeArticleLimits {
  /// 最大内容长度。
  static const int maxContentLength = 2000;

  /// 内容长度是否有效。
  static bool isContentLengthValid(String content) {
    final length = content.trim().length;
    return length > 0 && length <= maxContentLength;
  }
}
