/// WebSocket 协议常量，与 Go 端 [instant_share_server] 保持一致。
abstract final class WsFrameType {
  /// auth。
  static const auth = 'auth';

  /// authAck。
  static const authAck = 'auth_ack';

  /// 发送心跳。
  static const ping = 'ping';

  /// pong。
  static const pong = 'pong';

  /// 错误对象。
  static const error = 'error';

  /// shareStart。
  static const shareStart = 'share.start';

  /// shareStartAck。
  static const shareStartAck = 'share.start_ack';

  /// shareStop。
  static const shareStop = 'share.stop';

  /// shareStopAck。
  static const shareStopAck = 'share.stop_ack';

  /// shareSync。
  static const shareSync = 'share.sync';

  /// shareSyncAck。
  static const shareSyncAck = 'share.sync_ack';

  /// share文章Sync。
  static const shareArticleSync = 'share.article.sync';

  /// share文章SyncAck。
  static const shareArticleSyncAck = 'share.article.sync_ack';

  /// shareStatus。
  static const shareStatus = 'share.status';

  /// shareStatusAck。
  static const shareStatusAck = 'share.status_ack';

  /// pairing请求。
  static const pairingRequest = 'pairing.request';

  /// pairing请求Ack。
  static const pairingRequestAck = 'pairing.request_ack';

  /// pairingApprove。
  static const pairingApprove = 'pairing.approve';

  /// pairingReject。
  static const pairingReject = 'pairing.reject';

  /// pairingTimeout。
  static const pairingTimeout = 'pairing.timeout';

  /// Peer 主动撤回待审批申请。
  static const pairingCancel = 'pairing.cancel';

  /// pairingCancelAck。
  static const pairingCancelAck = 'pairing.cancel_ack';

  /// pairingDecide。
  static const pairingDecide = 'pairing.decide';

  /// pairingDecideAck。
  static const pairingDecideAck = 'pairing.decide_ack';

  /// shareOffer。
  static const shareOffer = 'share.offer';

  /// shareOfferAck。
  static const shareOfferAck = 'share.offer_ack';

  /// roomNotify。
  static const roomNotify = 'room.notify';

  /// roomSnapshot。
  static const roomSnapshot = 'room.snapshot';

  /// roomSnapshotAck。
  static const roomSnapshotAck = 'room.snapshot_ack';

  /// roomLeave Peer 主动离房。
  static const roomLeave = 'room.leave';

  /// roomLeaveAck。
  static const roomLeaveAck = 'room.leave_ack';

  /// roomPublicCatalogSync。
  static const roomPublicCatalogSync = 'room.public_catalog.sync';

  /// roomPublicCatalogSyncAck。
  static const roomPublicCatalogSyncAck = 'room.public_catalog.sync_ack';

  /// roomPublicCatalogClear。
  static const roomPublicCatalogClear = 'room.public_catalog.clear';

  /// roomPublicCatalogClearAck。
  static const roomPublicCatalogClearAck = 'room.public_catalog.clear_ack';

  /// file列表。
  static const fileList = 'file.list';

  /// file列表Ack。
  static const fileListAck = 'file.list_ack';

  /// fileDownload。
  static const fileDownload = 'file.download';

  /// fileDownloadAck。
  static const fileDownloadAck = 'file.download_ack';

  /// fileDownloadStart。
  static const fileDownloadStart = 'file.download_start';

  /// fileDownloadEnd。
  static const fileDownloadEnd = 'file.download_end';
}

/// WSRole。
abstract final class WsRole {
  /// admin。
  static const admin = 'admin';

  /// peer。
  static const peer = 'peer';
}

/// WSCode。
abstract final class WsCode {
  /// success。
  static const success = 0;

  /// bad请求。
  static const badRequest = 400;

  /// unauthorized。
  static const unauthorized = 401;

  /// forbidden。
  static const forbidden = 403;

  /// notFound。
  static const notFound = 404;

  /// conflict。
  static const conflict = 409;

  /// internal。
  static const internal = 500;
}
