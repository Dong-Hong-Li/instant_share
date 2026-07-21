/// 分享文件数据。
class ShareFileDto {
  const ShareFileDto({
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'size': size,
  };

  factory ShareFileDto.fromJson(Map<String, dynamic> json) {
    return ShareFileDto(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 分享文章数据。
class ShareArticleDto {
  const ShareArticleDto({
    required this.id,
    required this.title,
    required this.content,
  });

  /// ID。
  final String id;

  /// 标题。
  final String title;

  /// 内容。
  final String content;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
  };

  factory ShareArticleDto.fromJson(Map<String, dynamic> json) {
    return ShareArticleDto(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

/// 分享Status数据。
class ShareStatusDto {
  const ShareStatusDto({
    required this.active,
    required this.files,
    required this.articles,
    this.sessionId,
    this.baseUrl,
    this.ip,
    this.port,
    this.startedAt,
  });

  /// 是否激活。
  final bool active;

  /// sessionId。
  final String? sessionId;

  /// 基础地址。
  final String? baseUrl;

  /// ip。
  final String? ip;

  /// 端口。
  final int? port;

  /// 启动时间。
  final DateTime? startedAt;

  /// 文件列表。
  final List<ShareFileDto> files;

  /// 文章列表。
  final List<ShareArticleDto> articles;

  factory ShareStatusDto.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final files = rawFiles is List
        ? rawFiles
              .whereType<Map<String, dynamic>>()
              .map(ShareFileDto.fromJson)
              .toList()
        : const <ShareFileDto>[];

    DateTime? startedAt;
    final rawStartedAt = json['started_at'];
    if (rawStartedAt is String && rawStartedAt.isNotEmpty) {
      startedAt = DateTime.tryParse(rawStartedAt);
    }

    final articles = _parseArticles(json);

    return ShareStatusDto(
      active: json['active'] as bool? ?? false,
      sessionId: json['session_id'] as String?,
      baseUrl: json['base_url'] as String?,
      ip: json['ip'] as String?,
      port: (json['port'] as num?)?.toInt(),
      startedAt: startedAt,
      files: files,
      articles: articles,
    );
  }

  static List<ShareArticleDto> _parseArticles(Map<String, dynamic> json) {
    final rawArticles = json['articles'];
    if (rawArticles is List) {
      return rawArticles
          .whereType<Map<String, dynamic>>()
          .map(ShareArticleDto.fromJson)
          .toList();
    }

    final rawArticle = json['article'];
    if (rawArticle is Map<String, dynamic>) {
      return [ShareArticleDto.fromJson(rawArticle)];
    }

    return const <ShareArticleDto>[];
  }
}

/// Sync文章请求数据。
class SyncArticleRequestDto {
  const SyncArticleRequestDto({required this.articles});

  /// 文章列表。
  final List<ShareArticleDto> articles;

  Map<String, dynamic> toJson() => {
    'articles': articles.map((article) => article.toJson()).toList(),
  };
}

/// Start分享请求数据。
class StartShareRequestDto {
  const StartShareRequestDto({required this.files, this.port});

  /// 文件列表。
  final List<ShareFileDto> files;

  /// 端口。
  final int? port;

  Map<String, dynamic> toJson() => {
    if (port != null) 'port': port,
    'files': files.map((file) => file.toJson()).toList(),
  };
}

/// 文件Download请求数据。
class FileDownloadRequestDto {
  const FileDownloadRequestDto({required this.fileId});

  /// fileId。
  final String fileId;

  Map<String, dynamic> toJson() => {'file_id': fileId};
}

/// 文件DownloadStart数据。
class FileDownloadStartDto {
  const FileDownloadStartDto({
    required this.fileId,
    required this.name,
    required this.size,
  });

  /// fileId。
  final String fileId;

  /// 名称。
  final String name;

  /// 大小。
  final int size;

  factory FileDownloadStartDto.fromJson(Map<String, dynamic> json) {
    return FileDownloadStartDto(
      fileId: json['file_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}
