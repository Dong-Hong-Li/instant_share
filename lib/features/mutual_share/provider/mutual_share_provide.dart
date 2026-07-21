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
enum MutualSharePhase { idle, pairingPending, joinedRoom, reconnecting }

/// 加入房间后的回调类型。
typedef JoinedRoomHook = Future<void> Function();

/// 互传分享状态。
class MutualShareProvider extends ChangeNotifier {
  MutualShareProvider({required ShareSessionService session})
    : _session = session;

  static const _uuid = Uuid();

  static final String _deviceId = _uuid.v4();

  /// 重连前等待：1s / 2s / 4s，共 3 次。
  static const _reconnectBackoffs = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  static const _reconnectAttemptTimeout = Duration(seconds: 10);
  static const _offerWaitTimeout = Duration(seconds: 20);

  final ShareSessionService _session;

  RemoteRoomClient? _remote;
  StreamSubscription<PairingOutcome>? _pairingSub;
  StreamSubscription<RoomNotifyEvent>? _notifySub;
  StreamSubscription<void>? _disconnectedSub;
  StreamSubscription<WsIncomingMessage>? _adminIncomingSub;
  Timer? _countdownTimer;
  JoinedRoomHook? _onJoinedRoom;

  MutualSharePhase _phase = MutualSharePhase.idle;
  int _mirrorEpoch = 0;
  int _reconnectGeneration = 0;
  Completer<bool>? _reconnectCompleter;
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

  /// 是否已加入房间（含重连中，便于 UI 保持房间视图）。
  bool get joinedRoom =>
      _phase == MutualSharePhase.joinedRoom ||
      _phase == MutualSharePhase.reconnecting;

  /// 是否正在短时重连。
  bool get isReconnecting => _phase == MutualSharePhase.reconnecting;

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
    _disconnectedSub = remote.disconnected.listen(_handleRemoteDisconnected);

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
    // 先切换本地状态（并递增 epoch），使仍在飞行中的 `_mirrorPublicCatalog`
    // 的 phase/epoch 守卫立刻失效，避免其在 clear 之后又把镜像同步回去。
    _mirrorEpoch += 1;
    _reconnectGeneration += 1;
    final reconnectWait = _reconnectCompleter;
    _reconnectCompleter = null;
    if (reconnectWait != null && !reconnectWait.isCompleted) {
      reconnectWait.complete(false);
    }

    final remote = _remote;
    // 待审批取消：必须先撤回 Host 上的 pending，否则 A 仍可「同意」把已取消的 B 加进房间。
    final shouldWithdrawPending = _phase == MutualSharePhase.pairingPending;
    final shouldNotifyLeave =
        _phase == MutualSharePhase.joinedRoom ||
        _phase == MutualSharePhase.reconnecting;

    final hadCatalog = _catalog.isNotEmpty;
    final stateChanged =
        _phase != MutualSharePhase.idle || _countdownSeconds != 0 || hadCatalog;
    _phase = MutualSharePhase.idle;
    _countdownSeconds = 0;
    _catalog = const [];
    await _pairingSub?.cancel();
    await _notifySub?.cancel();
    await _disconnectedSub?.cancel();
    _pairingSub = null;
    _notifySub = null;
    _disconnectedSub = null;

    if (remote != null) {
      if (shouldWithdrawPending) {
        try {
          await remote.cancelPairingRequest();
        } catch (error) {
          debugPrint(
            '[MutualShareProvider] pairing.cancel failed: $error',
          );
        }
      }
      // 主动离房：先通知 Host 移除成员，再断开（保留重连场景下的半开不断成员）。
      if (shouldNotifyLeave) {
        try {
          await remote.leaveRoom();
        } catch (error) {
          debugPrint('[MutualShareProvider] room.leave failed: $error');
        }
      }
    }

    await remote?.disconnect();
    _remote = null;
    if (stateChanged) {
      notifyListeners();
    }
    // clear 放在状态切换之后（best-effort），此时 phase 已非 joinedRoom，
    // 之后到达的 catalog_updated 也不会再触发新的 sync。
    await _clearPublicCatalogMirror();
  }

  /// leave房间。
  Future<void> leaveRoom() => cancelPairing();

  /// 提交共享文件。
  Future<void> offerFiles(List<HomeFileItem> files) async {
    if (_phase == MutualSharePhase.reconnecting) {
      final waiting = _reconnectCompleter;
      if (waiting != null) {
        final ok = await waiting.future.timeout(
          _offerWaitTimeout,
          onTimeout: () => false,
        );
        if (!ok) return;
      }
    }
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

  /// 将当前房间目录镜像到本机 Go（仅 Peer 已入房时；Host 由 Go 自身读取 RoomService，无需镜像）。
  Future<void> _mirrorPublicCatalog() async {
    if (_phase != MutualSharePhase.joinedRoom) return;
    final epoch = _mirrorEpoch;
    final snapshot = _catalog;
    // 再次确认 epoch 未被 cancelPairing 递增，防止在此之前已通过守卫、
    // 但即将发起 sync 的调用在 leave 之后把镜像"复活"。
    if (epoch != _mirrorEpoch || _phase != MutualSharePhase.joinedRoom) return;
    try {
      await _session.syncPublicRoomCatalog(snapshot);
    } catch (error) {
      debugPrint('[MutualShareProvider] public catalog sync failed: $error');
    }
  }

  /// 清空本机 Go 上的公共房间目录镜像（离房时最好努力尝试一次）。
  Future<void> _clearPublicCatalogMirror() async {
    try {
      await _session.clearPublicRoomCatalog();
    } catch (error) {
      debugPrint('[MutualShareProvider] public catalog clear failed: $error');
    }
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

  void _handleRemoteDisconnected([_]) {
    if (_phase == MutualSharePhase.pairingPending) {
      _errorMessage = '与主机连接已断开';
      unawaited(cancelPairing());
      return;
    }
    if (_phase != MutualSharePhase.joinedRoom) return;
    // 同步切入 reconnecting，避免 onError/onDone 双事件并发启动两次重连。
    _phase = MutualSharePhase.reconnecting;
    _remote?.stopHeartbeat();
    final wait = Completer<bool>();
    _reconnectCompleter = wait;
    notifyListeners();
    unawaited(_attemptReconnect(wait));
  }

  Future<void> _attemptReconnect(Completer<bool> wait) async {
    final generation = ++_reconnectGeneration;
    final remote = _remote;
    if (remote == null) {
      if (!wait.isCompleted) wait.complete(false);
      if (_reconnectCompleter == wait) _reconnectCompleter = null;
      _errorMessage = '与主机连接已断开';
      await cancelPairing();
      return;
    }

    var success = false;
    for (var i = 0; i < _reconnectBackoffs.length; i++) {
      if (generation != _reconnectGeneration ||
          _phase != MutualSharePhase.reconnecting) {
        return;
      }
      await Future<void>.delayed(_reconnectBackoffs[i]);
      if (generation != _reconnectGeneration ||
          _phase != MutualSharePhase.reconnecting) {
        return;
      }

      try {
        await remote.reconnect().timeout(_reconnectAttemptTimeout);
        final snapshot = await remote.fetchSnapshot().timeout(
          _reconnectAttemptTimeout,
        );
        if (generation != _reconnectGeneration ||
            _phase != MutualSharePhase.reconnecting) {
          return;
        }

        _catalog = snapshot.catalog;
        _members = snapshot.members;
        _phase = MutualSharePhase.joinedRoom;
        remote.startHeartbeat();
        notifyListeners();
        unawaited(_mirrorPublicCatalog());
        final hook = _onJoinedRoom;
        if (hook != null) {
          try {
            await hook();
          } catch (error) {
            debugPrint(
              '[MutualShareProvider] onJoinedRoom after reconnect failed: $error',
            );
          }
        }
        success = true;
        break;
      } catch (error) {
        debugPrint(
          '[MutualShareProvider] reconnect attempt ${i + 1} failed: $error',
        );
      }
    }

    if (generation != _reconnectGeneration) return;

    if (_reconnectCompleter == wait && !wait.isCompleted) {
      wait.complete(success);
    }
    if (_reconnectCompleter == wait) {
      _reconnectCompleter = null;
    }

    if (!success) {
      _errorMessage = '与主机连接已断开';
      await cancelPairing();
    }
  }

  Future<void> _handlePairingOutcome(PairingOutcome outcome) async {
    switch (outcome.type) {
      case PairingOutcomeType.approved:
        _countdownTimer?.cancel();
        _phase = MutualSharePhase.joinedRoom;
        _remoteHostBaseUrl = outcome.hostBaseUrl;
        _remote?.startHeartbeat();
        final epoch = _mirrorEpoch;
        final snapshot = await _remote?.fetchSnapshot();
        // 若等待快照期间用户已 cancel（epoch 递增/phase 被置回 idle），
        // 则不再写入 _catalog、不通知、不镜像、不触发 onJoinedRoom。
        if (epoch != _mirrorEpoch || _phase != MutualSharePhase.joinedRoom) {
          return;
        }
        if (snapshot != null) {
          _catalog = snapshot.catalog;
          _members = snapshot.members;
        }
        notifyListeners();
        unawaited(_mirrorPublicCatalog());
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
      unawaited(_mirrorPublicCatalog());
    } else {
      if (event.catalog.isNotEmpty) {
        _catalog = event.catalog;
        unawaited(_mirrorPublicCatalog());
      }
      if (event.members.isNotEmpty || event.event == 'members_updated') {
        _members = event.members;
      }
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
    // 注意：此回调来自本机 admin WS 的 room.notify，即“本地 Host”房间事件，
    // 不代表本机作为 Peer 加入的远端房间目录，绝不能据此镜像到本机 Go。
    // 镜像仅允许来自 `_handleRemoteNotify`（远端 notify）或 approved 配对
    // 后的快照拉取（见 `_handlePairingOutcome`）。
    if (event.event == 'catalog_updated') {
      _catalog = event.catalog;
      // 必须原样赋值：Peer 离房后 members 可能为空，不能用 isNotEmpty 守卫。
      _members = event.members;
    } else if (event.event == 'pending_updated') {
      _pending = event.pending;
      _members = event.members;
    } else {
      if (event.catalog.isNotEmpty) _catalog = event.catalog;
      if (event.pending.isNotEmpty) _pending = event.pending;
      // members 允许被清空（Peer 离房）。
      if (event.members.isNotEmpty || event.event == 'members_updated') {
        _members = event.members;
      }
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
