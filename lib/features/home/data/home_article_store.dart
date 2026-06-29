import 'dart:convert';

import 'package:instant_share/core/utils/storage/prefs_util.dart';
import 'package:instant_share/features/home/data/home_article_item.dart';
import 'package:instant_share/resource/keys.dart';

/// 文章列表与上次分享标记的本地持久化。
class HomeArticleStore {
  HomeArticleStore._();

  static Future<HomeArticleStoreSnapshot> load() async {
    final raw = PrefsUtil.getString(AppKeys.homeArticles);
    final lastSharedId = PrefsUtil.getString(AppKeys.homeLastSharedArticleId);

    if (raw == null || raw.isEmpty) {
      return HomeArticleStoreSnapshot(
        articles: const [],
        lastSharedArticleId: lastSharedId,
      );
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return HomeArticleStoreSnapshot(
        articles: const [],
        lastSharedArticleId: lastSharedId,
      );
    }

    final articles = decoded
        .whereType<Map<String, dynamic>>()
        .map(HomeArticleItem.fromJson)
        .toList(growable: false);

    return HomeArticleStoreSnapshot(
      articles: articles,
      lastSharedArticleId: lastSharedId,
    );
  }

  static Future<void> save({
    required List<HomeArticleItem> articles,
    String? lastSharedArticleId,
  }) async {
    final encoded = jsonEncode(articles.map((item) => item.toJson()).toList());
    await PrefsUtil.setString(AppKeys.homeArticles, encoded);

    if (lastSharedArticleId == null || lastSharedArticleId.isEmpty) {
      await PrefsUtil.remove(AppKeys.homeLastSharedArticleId);
    } else {
      await PrefsUtil.setString(
        AppKeys.homeLastSharedArticleId,
        lastSharedArticleId,
      );
    }
  }
}

class HomeArticleStoreSnapshot {
  const HomeArticleStoreSnapshot({
    required this.articles,
    required this.lastSharedArticleId,
  });

  final List<HomeArticleItem> articles;
  final String? lastSharedArticleId;
}
