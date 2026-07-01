/// 文章分享长度限制。
abstract final class HomeArticleLimits {
  static const int maxContentLength = 2000;

  static bool isContentLengthValid(String content) {
    final length = content.trim().length;
    return length > 0 && length <= maxContentLength;
  }
}
