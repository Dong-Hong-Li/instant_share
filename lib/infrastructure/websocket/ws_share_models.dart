/// 分享相关 DTO，字段与 Go 端 model 对齐。
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

class ShareStatusDto {
  const ShareStatusDto({
    required this.active,
    required this.files,
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

    return ShareStatusDto(
      active: json['active'] as bool? ?? false,
      sessionId: json['session_id'] as String?,
      baseUrl: json['base_url'] as String?,
      ip: json['ip'] as String?,
      port: (json['port'] as num?)?.toInt(),
      startedAt: startedAt,
      files: files,
    );
  }
}

class StartShareRequestDto {
  const StartShareRequestDto({
    required this.files,
    this.port,
  });

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
