/// WebSocket 协议常量，与 Go 端 [instant_share_server] 保持一致。
abstract final class WsFrameType {
  static const auth = 'auth';
  static const authAck = 'auth_ack';
  static const ping = 'ping';
  static const pong = 'pong';
  static const error = 'error';

  static const shareStart = 'share.start';
  static const shareStartAck = 'share.start_ack';
  static const shareStop = 'share.stop';
  static const shareStopAck = 'share.stop_ack';
  static const shareSync = 'share.sync';
  static const shareSyncAck = 'share.sync_ack';
  static const shareArticleSync = 'share.article.sync';
  static const shareArticleSyncAck = 'share.article.sync_ack';
  static const shareStatus = 'share.status';
  static const shareStatusAck = 'share.status_ack';

  static const fileList = 'file.list';
  static const fileListAck = 'file.list_ack';
  static const fileDownload = 'file.download';
  static const fileDownloadAck = 'file.download_ack';
  static const fileDownloadStart = 'file.download_start';
  static const fileDownloadEnd = 'file.download_end';
}

abstract final class WsRole {
  static const admin = 'admin';
}

abstract final class WsCode {
  static const success = 0;
  static const badRequest = 400;
  static const unauthorized = 401;
  static const forbidden = 403;
  static const notFound = 404;
  static const conflict = 409;
  static const internal = 500;
}
