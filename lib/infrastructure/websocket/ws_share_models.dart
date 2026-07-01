class ShareFileDto {
  const ShareFileDto({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
  });

  final String id;
  final String path;
  final String name;
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

class ShareArticleDto {
  const ShareArticleDto({
    required this.id,
    required this.title,
    required this.content,
  });

  final String id;
  final String title;
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

  final bool active;
  final String? sessionId;
  final String? baseUrl;
  final String? ip;
  final int? port;
  final DateTime? startedAt;
  final List<ShareFileDto> files;
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

class SyncArticleRequestDto {
  const SyncArticleRequestDto({required this.articles});

  final List<ShareArticleDto> articles;

  Map<String, dynamic> toJson() => {
    'articles': articles.map((article) => article.toJson()).toList(),
  };
}

class StartShareRequestDto {
  const StartShareRequestDto({required this.files, this.port});

  final List<ShareFileDto> files;
  final int? port;

  Map<String, dynamic> toJson() => {
    if (port != null) 'port': port,
    'files': files.map((file) => file.toJson()).toList(),
  };
}

class FileDownloadRequestDto {
  const FileDownloadRequestDto({required this.fileId});

  final String fileId;

  Map<String, dynamic> toJson() => {'file_id': fileId};
}

class FileDownloadStartDto {
  const FileDownloadStartDto({
    required this.fileId,
    required this.name,
    required this.size,
  });

  final String fileId;
  final String name;
  final int size;

  factory FileDownloadStartDto.fromJson(Map<String, dynamic> json) {
    return FileDownloadStartDto(
      fileId: json['file_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}
