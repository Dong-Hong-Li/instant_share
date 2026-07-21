/// 房间文件共享信息。
class RoomFileOffer {
  const RoomFileOffer({
    required this.id,
    required this.name,
    required this.size,
    required this.downloadPath,
  });

  /// ID。
  final String id;

  /// 名称。
  final String name;

  /// 大小。
  final int size;

  /// 下载路径。
  final String downloadPath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'download_path': downloadPath,
  };

  factory RoomFileOffer.fromJson(Map<String, dynamic> json) => RoomFileOffer(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    size: (json['size'] as num?)?.toInt() ?? 0,
    downloadPath: json['download_path'] as String? ?? '',
  );
}

/// 共享目录条目数据。
class SharedEntryDto {
  const SharedEntryDto({
    required this.id,
    required this.name,
    required this.size,
    required this.ownerId,
    required this.baseUrl,
    required this.downloadPath,
    this.ownerDisplayName,
  });

  /// ID。
  final String id;

  /// 名称。
  final String name;

  /// 大小。
  final int size;

  /// 所属设备 ID。
  final String ownerId;

  /// 所属设备名称。
  final String? ownerDisplayName;

  /// 基础地址。
  final String baseUrl;

  /// 下载路径。
  final String downloadPath;

  /// 下载链接。
  Uri get downloadUri => Uri.parse(baseUrl).resolve(downloadPath);

  factory SharedEntryDto.fromJson(Map<String, dynamic> json) => SharedEntryDto(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    size: (json['size'] as num?)?.toInt() ?? 0,
    ownerId: json['owner_id'] as String? ?? '',
    ownerDisplayName: json['owner_display_name'] as String?,
    baseUrl: json['base_url'] as String? ?? '',
    downloadPath: json['download_path'] as String? ?? '',
  );
}

/// 待处理配对请求数据。
class PendingRequestDto {
  const PendingRequestDto({
    required this.deviceId,
    required this.displayName,
    required this.peerBaseUrl,
    this.requestedAt,
    this.expiresAt,
  });

  /// 设备 ID。
  final String deviceId;

  /// 设备名称。
  final String displayName;

  /// 对端基础地址。
  final String peerBaseUrl;

  /// 请求时间。
  final DateTime? requestedAt;

  /// 过期时间。
  final DateTime? expiresAt;

  factory PendingRequestDto.fromJson(Map<String, dynamic> json) =>
      PendingRequestDto(
        deviceId: json['device_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        peerBaseUrl: json['peer_base_url'] as String? ?? '',
        requestedAt: _parseTime(json['requested_at']),
        expiresAt: _parseTime(json['expires_at']),
      );
}

/// 房间成员数据。
class RoomMemberDto {
  const RoomMemberDto({
    required this.deviceId,
    required this.displayName,
    required this.peerBaseUrl,
  });

  /// 设备 ID。
  final String deviceId;

  /// 设备名称。
  final String displayName;

  /// 对端基础地址。
  final String peerBaseUrl;

  factory RoomMemberDto.fromJson(Map<String, dynamic> json) => RoomMemberDto(
    deviceId: json['device_id'] as String? ?? '',
    displayName: json['display_name'] as String? ?? '',
    peerBaseUrl: json['peer_base_url'] as String? ?? '',
  );
}

/// 房间快照数据。
class RoomSnapshot {
  const RoomSnapshot({
    required this.catalog,
    required this.members,
    required this.pending,
    required this.revision,
  });

  /// 共享目录。
  final List<SharedEntryDto> catalog;

  /// 成员列表。
  final List<RoomMemberDto> members;

  /// 待处理请求。
  final List<PendingRequestDto> pending;

  /// 版本号。
  final int revision;

  factory RoomSnapshot.fromJson(Map<String, dynamic> json) => RoomSnapshot(
    catalog: _parseList(json['catalog'], SharedEntryDto.fromJson),
    members: _parseList(json['members'], RoomMemberDto.fromJson),
    pending: _parseList(json['pending'], PendingRequestDto.fromJson),
    revision: (json['revision'] as num?)?.toInt() ?? 0,
  );
}

/// 配对结果类型。
enum PairingOutcomeType { approved, rejected, timeout }

/// 配对结果。
class PairingOutcome {
  const PairingOutcome(this.type, {this.hostBaseUrl, this.roomId});

  /// 类型。
  final PairingOutcomeType type;

  /// 主机基础地址。
  final String? hostBaseUrl;

  /// 房间 ID。
  final String? roomId;
}

/// 房间通知事件。
class RoomNotifyEvent {
  const RoomNotifyEvent({
    required this.event,
    required this.catalog,
    required this.members,
    required this.pending,
    required this.revision,
  });

  /// 事件名称。
  final String event;

  /// 共享目录。
  final List<SharedEntryDto> catalog;

  /// 成员列表。
  final List<RoomMemberDto> members;

  /// 待处理请求。
  final List<PendingRequestDto> pending;

  /// 版本号。
  final int revision;

  factory RoomNotifyEvent.fromJson(Map<String, dynamic> json) =>
      RoomNotifyEvent(
        event: json['event'] as String? ?? '',
        catalog: _parseList(json['catalog'], SharedEntryDto.fromJson),
        members: _parseList(json['members'], RoomMemberDto.fromJson),
        pending: _parseList(json['pending'], PendingRequestDto.fromJson),
        revision: (json['revision'] as num?)?.toInt() ?? 0,
      );
}

List<T> _parseList<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().map(parse).toList();
}

DateTime? _parseTime(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
