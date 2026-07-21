import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:instant_share/features/home/data/home_file_item.dart';
import 'package:instant_share/features/home/provider/provider.dart';
import 'package:instant_share/infrastructure/share_server/share_server_health.dart';
import 'package:instant_share/infrastructure/share_server/share_session_service.dart';
import 'package:instant_share/infrastructure/websocket/remote_room_client.dart';
import 'package:instant_share/infrastructure/websocket/room_ws_models.dart';
import 'package:instant_share/infrastructure/websocket/ws_frame.dart';
import 'package:uuid/uuid.dart';

/// 互传分享阶段。
enum MutualSharePhase { idle, pairingPending, joinedRoom }

/// 加入房间后的回调类型。
typedef JoinedRoomHook = Future<void> Function();

/// 互传分享状态。
class MutualShareProvider extends ChangeNotifier {
  MutualShareProvider({required ShareSessionService session})
    : _session = session;

  static const _uuid = Uuid();

  static final String _deviceId = _uuid.v4();

  final ShareSessionService _session;

  RemoteRoomClient? _remote;
  StreamSubscription<PairingOutcome>? _pairingSub;
  StreamSubscription<RoomNotifyEvent>? _notifySub;
  StreamSubscription<WsIncomingMessage>? _adminIncomingSub;
  Timer? _countdownTimer;
  JoinedRoomHook? _onJoinedRoom;

  MutualSharePhase _phase = MutualSharePhase.idle;
  int _countdownSeconds = 0;
  String? _errorMessage;
  String? _remoteHostBaseUrl;
  List<SharedEntryDto> _catalog = const [];
  List<PendingRequestDto> _pending = const [];
  List<RoomMemberDto> _members = const [];

  /// 当前阶段。
  MutualSharePhase get phase => _phase;

  /// 倒计时秒数。
  int get countdownSeconds => _countdownSeconds;

  /// 错误消息。
  String? get errorMessage => _errorMessage;

  /// 远端主机基础地址。
  String? get remoteHostBaseUrl => _remoteHostBaseUrl;

  /// 共享目录。
  List<SharedEntryDto> get catalog => List.unmodifiable(_catalog);

  /// 待处理请求。
  List<PendingRequestDto> get pending => List.unmodifiable(_pending);

  /// 成员列表。
  List<RoomMemberDto> get members => List.unmodifiable(_members);

  /// 是否已加入房间。
  bool get joinedRoom => _phase == MutualSharePhase.joinedRoom;

  /// 设置加入房间后的回调。
  void setOnJoinedRoom(JoinedRoomHook? hook) {
    _onJoinedRoom = hook;
  }

  /// 清除错误消息。
  void clearErrorMessage() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// 确保主机管理通道监听中。
  Future<void> ensureHostAdminListening() async {
    if (_adminIncomingSub != null) return;
    _adminIncomingSub = _session.incoming.listen(_handleAdminIncoming);
    await refreshHostRoomSnapshot();
  }

  /// 刷新主机房间快照。
  Future<void> refreshHostRoomSnapshot() async {
    try {
      final snapshot = await _session.fetchRoomSnapshot();
      _catalog = snapshot.catalog;
      _pending = snapshot.pending;
      _members = snapshot.members;
      notifyListeners();
    } catch (error) {
      debugPrint('[MutualShareProvider] room snapshot failed: $error');
    }
  }

  /// 处理配对决定。
  Future<void> decidePairing(String deviceId, {required bool approve}) async {
    await _session.decidePairing(deviceId, approve: approve);
    await refreshHostRoomSnapshot();
  }

  /// 开始配对。
  Future<void> startPairing({required String hostInput, int? port}) async {
    await cancelPairing();
    _errorMessage = null;

    final localHealth = await _session.fetchHealth();
    final target = _parseHostInput(hostInput, port ?? localHealth.port);
    if (_isSelfTarget(target.host, localHealth)) {
      _errorMessage = '不能连接本机';
      notifyListeners();
      return;
    }

    final remote = RemoteRoomClient(deviceId: _deviceId);
    _remote = remote;
    _pairingSub = remote.pairingOutcomes.listen(_handlePairingOutcome);
    _notifySub = remote.notifies.listen(_handleRemoteNotify);

    try {
      await remote.connect(
        hostWsUrl: Uri(
          scheme: 'ws',
          host: target.host,
          port: target.port,
          path: '/ws',
        ),
        displayName: Platform.localHostname,
        peerBaseUrl: localHealth.lanHttpBaseUri,
      );
      await remote.requestPairing();
      _phase = MutualSharePhase.pairingPending;
      _countdownSeconds = 60;
      _startCountdown();
      notifyListeners();
    } catch (error) {
      _phase = MutualSharePhase.idle;
      _errorMessage = '连接失败：$error';
      await remote.disconnect();
      notifyListeners();
    }
  }

  /// cancel配对。
  Future<void> cancelPairing() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    await _pairingSub?.cancel();
    await _notifySub?.cancel();
    _pairingSub = null;
    _notifySub = null;
    await _remote?.disconnect();
    _remote = null;
    if (_phase != MutualSharePhase.idle || _countdownSeconds != 0) {
      _phase = MutualSharePhase.idle;
      _countdownSeconds = 0;
      notifyListeners();
    }
  }

  /// leave房间。
  Future<void> leaveRoom() => cancelPairing();

  /// 提交共享文件。
  Future<void> offerFiles(List<HomeFileItem> files) async {
    if (_phase != MutualSharePhase.joinedRoom) return;
    final remote = _remote;
    if (remote == null) return;
    await remote.offerFiles(
      files
          .map(
            (file) => RoomFileOffer(
              id: file.id,
              name: file.name,
              size: file.size,
              downloadPath: '/api/v1/share/files/${file.id}/download',
            ),
          )
          .toList(),
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_phase != MutualSharePhase.pairingPending) {
        timer.cancel();
        return;
      }
      _countdownSeconds -= 1;
      if (_countdownSeconds <= 0) {
        _errorMessage = '等待认证超时';
        unawaited(cancelPairing());
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> _handlePairingOutcome(PairingOutcome outcome) async {
    switch (outcome.type) {
      case PairingOutcomeType.approved:
        _countdownTimer?.cancel();
        _phase = MutualSharePhase.joinedRoom;
        _remoteHostBaseUrl = outcome.hostBaseUrl;
        final snapshot = await _remote?.fetchSnapshot();
        if (snapshot != null) {
          _catalog = snapshot.catalog;
          _members = snapshot.members;
        }
        notifyListeners();
        // 入房后立刻把本机已选文件 offer 进房间目录。
        final hook = _onJoinedRoom;
        if (hook != null) {
          try {
            await hook();
          } catch (error) {
            debugPrint('[MutualShareProvider] onJoinedRoom failed: $error');
          }
        }
      case PairingOutcomeType.rejected:
        _errorMessage = '对方已拒绝连接';
        await cancelPairing();
      case PairingOutcomeType.timeout:
        _errorMessage = '等待认证超时';
        await cancelPairing();
    }
  }

  void _handleRemoteNotify(RoomNotifyEvent event) {
    if (event.event == 'room_closed') {
      _errorMessage = '主机已结束共享';
      unawaited(cancelPairing());
      return;
    }
    if (event.event == 'catalog_updated') {
      _catalog = event.catalog;
      _members = event.members;
    } else {
      if (event.catalog.isNotEmpty) _catalog = event.catalog;
      if (event.members.isNotEmpty) _members = event.members;
    }
    notifyListeners();
  }

  void _handleAdminIncoming(WsIncomingMessage message) {
    if (message is! WsJsonMessage) return;
    final response = message.response;
    if (response.type != 'room.notify' || !response.isSuccess) return;
    final data = response.data;
    if (data is! Map<String, dynamic>) return;
    final event = RoomNotifyEvent.fromJson(data);
    if (event.event == 'catalog_updated') {
      _catalog = event.catalog;
      _members = event.members;
    } else if (event.event == 'pending_updated') {
      _pending = event.pending;
      _members = event.members;
    } else {
      if (event.catalog.isNotEmpty) _catalog = event.catalog;
      if (event.pending.isNotEmpty) _pending = event.pending;
      if (event.members.isNotEmpty) _members = event.members;
    }
    notifyListeners();
  }

  _HostTarget _parseHostInput(String input, int defaultPort) {
    var raw = input.trim();
    if (raw.isEmpty) {
      throw const FormatException('请输入对方 IP');
    }
    if (!raw.contains('://')) {
      raw = 'http://$raw';
    }
    final uri = Uri.parse(raw);
    if (uri.host.isEmpty) {
      throw const FormatException('请输入有效 IP');
    }
    return _HostTarget(uri.host, uri.hasPort ? uri.port : defaultPort);
  }

  bool _isSelfTarget(String host, ShareServerHealthDto health) {
    return host == '127.0.0.1' ||
        host == 'localhost' ||
        health.localIps.contains(host) ||
        host == health.lanIp;
  }

  /// 释放资源。
  @override
  void dispose() {
    _countdownTimer?.cancel();
    unawaited(_adminIncomingSub?.cancel());
    unawaited(cancelPairing());
    super.dispose();
  }
}

class _HostTarget {
  const _HostTarget(this.host, this.port);

  /// 主机地址。
  final String host;

  /// 端口。
  final int port;
}

/// mutual分享状态。
final mutualShareProvider = ChangeNotifierProvider<MutualShareProvider>((ref) {
  // 与 home 共用同一 admin WS，避免 Go 端按 uid=admin 踢掉旧连接。
  final provider = MutualShareProvider(
    session: ref.read(homeProvider).shareSession,
  );
  ref.onDispose(provider.dispose);
  return provider;
});
