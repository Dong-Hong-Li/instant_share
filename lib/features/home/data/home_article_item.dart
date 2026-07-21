/// 本地文章条目。
class HomeArticleItem {
  const HomeArticleItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAtMs,
  });

  /// ID。
  final String id;

  /// 标题。
  final String title;

  /// 内容。
  final String content;

  /// 创建时间戳。
  final int createdAtMs;

  /// 展示标题。
  String get displayTitle {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final body = content.trim();
    if (body.isEmpty) return '无标题';
    return body.length <= 12 ? body : '${body.substring(0, 12)}…';
  }

  /// 正文预览。
  String get bodyPreview {
    final body = content.trim();
    if (body.isEmpty) return '（空正文）';
    return body.length <= 48 ? body : '${body.substring(0, 48)}…';
  }

  /// 字符数量。
  int get charCount => content.trim().length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'created_at_ms': createdAtMs,
  };

  factory HomeArticleItem.fromJson(Map<String, dynamic> json) {
    return HomeArticleItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAtMs: json['created_at_ms'] as int? ?? 0,
    );
  }
}
