/// 本地文章条目。
class HomeArticleItem {
  const HomeArticleItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAtMs,
  });

  final String id;
  final String title;
  final String content;
  final int createdAtMs;

  String get displayTitle {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final body = content.trim();
    if (body.isEmpty) return '无标题';
    return body.length <= 12 ? body : '${body.substring(0, 12)}…';
  }

  String get bodyPreview {
    final body = content.trim();
    if (body.isEmpty) return '（空正文）';
    return body.length <= 48 ? body : '${body.substring(0, 48)}…';
  }

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
