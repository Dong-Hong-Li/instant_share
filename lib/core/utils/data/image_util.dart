import 'dart:async';
import 'package:flutter/widgets.dart';

/// 图片尺寸信息
class ImageSize {
  final double width;
  final double height;

  ImageSize(this.width, this.height);

  @override
  String toString() => 'ImageSize(width: $width, height: $height)';
}

class ImageUtil {
  late ImageStreamListener _listener;
  late ImageStream _imageStream;

  /// 获取图片宽高，加载错误会抛出异常.（单位 px）
  /// image
  /// url network
  /// local url , package
  Future<Rect> getImageWH({
    Image? image,
    String? url,
    String? localUrl,
    String? package,
    ImageConfiguration? configuration,
  }) {
    Completer<Rect> completer = Completer<Rect>();
    _listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        _imageStream.removeListener(_listener);
        if (!completer.isCompleted) {
          completer.complete(
            Rect.fromLTWH(
              0,
              0,
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ),
          );
        }
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        _imageStream.removeListener(_listener);
        if (!completer.isCompleted) {
          completer.completeError(exception, stackTrace);
        }
      },
    );

    if (image == null &&
        (url == null || url.isEmpty) &&
        (localUrl == null || localUrl.isEmpty)) {
      return Future.value(Rect.zero);
    }
    Image? img = image;
    img ??= (url != null && url.isNotEmpty)
        ? Image.network(url)
        : Image.asset(localUrl!, package: package);
    _imageStream = img.image.resolve(configuration ?? ImageConfiguration());
    _imageStream.addListener(_listener);
    return completer.future;
  }

  /// 获取网络图片的宽高（单位 px）
  ///
  /// 使用示例：
  /// ```dart
  /// final size = await ImageUtil.getNetworkImageSize('https://example.com/image.jpg');
  /// print('宽: ${size.width}, 高: ${size.height}');
  /// ```
  static Future<ImageSize> getNetworkImageSize(String imageUrl) async {
    final Completer<ImageSize> completer = Completer<ImageSize>();
    final Image image = Image.network(imageUrl);
    final ImageStream stream = image.image.resolve(const ImageConfiguration());

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(
            ImageSize(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ),
          );
        }
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(exception, stackTrace);
        }
      },
    );

    stream.addListener(listener);
    return completer.future;
  }

  /// 获取本地资源图片的宽高（单位 px）
  ///
  /// 使用示例：
  /// ```dart
  /// final size = await ImageUtil.getAssetImageSize('assets/images/logo.png');
  /// print('宽: ${size.width}, 高: ${size.height}');
  /// ```
  static Future<ImageSize> getAssetImageSize(
    String assetPath, {
    String? package,
  }) async {
    final Completer<ImageSize> completer = Completer<ImageSize>();
    final Image image = Image.asset(assetPath, package: package);
    final ImageStream stream = image.image.resolve(const ImageConfiguration());

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(
            ImageSize(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ),
          );
        }
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(exception, stackTrace);
        }
      },
    );

    stream.addListener(listener);
    return completer.future;
  }

  /// 计算适合显示的缓存尺寸
  ///
  /// [displayWidth] 显示宽度（逻辑像素）
  /// [displayHeight] 显示高度（逻辑像素）
  /// [devicePixelRatio] 设备像素比率，默认3.0
  ///
  /// 返回适合的缓存宽高（物理像素）
  ///
  /// 使用示例：
  /// ```dart
  /// final cacheSize = ImageUtil.calculateCacheSize(
  ///   displayWidth: 200,
  ///   displayHeight: 200,
  /// );
  ///
  /// Image.network(
  ///   url,
  ///   cacheWidth: cacheSize.width.toInt(),
  ///   cacheHeight: cacheSize.height.toInt(),
  /// );
  /// ```
  static ImageSize calculateCacheSize({
    required double displayWidth,
    required double displayHeight,
    double devicePixelRatio = 3.0,
  }) {
    return ImageSize(
      displayWidth * devicePixelRatio,
      displayHeight * devicePixelRatio,
    );
  }
}

Future<Size> getImageSize(ImageProvider imageProvider) async {
  final Completer<Size> completer = Completer<Size>();

  final ImageStream stream = imageProvider.resolve(const ImageConfiguration());

  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, bool synchronousCall) {
      stream.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete(
          Size(info.image.width.toDouble(), info.image.height.toDouble()),
        );
      }
    },
    onError: (dynamic exception, StackTrace? stackTrace) {
      stream.removeListener(listener);
      if (!completer.isCompleted) {
        completer.completeError(exception, stackTrace);
      }
    },
  );

  stream.addListener(listener);
  return completer.future;
}
