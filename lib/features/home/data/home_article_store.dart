import 'dart:convert';

import 'package:instant_share/core/utils/storage/prefs_util.dart';
import 'package:instant_share/features/home/data/home_article_item.dart';
import 'package:instant_share/resource/keys.dart';

/// 文章列表与选中分享标记的本地持久化。
class HomeArticleStore {
  HomeArticleStore._();

  static Future<HomeArticleStoreSnapshot> load() async {
    final raw = PrefsUtil.getString(AppKeys.homeArticles);
    final sharedIds = _loadSharedArticleIds();

    if (raw == null || raw.isEmpty) {
      return HomeArticleStoreSnapshot(
        articles: const [],
        sharedArticleIds: sharedIds,
      );
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return HomeArticleStoreSnapshot(
        articles: const [],
        sharedArticleIds: sharedIds,
      );
    }

    final articles = decoded
        .whereType<Map<String, dynamic>>()
        .map(HomeArticleItem.fromJson)
        .toList(growable: false);

    return HomeArticleStoreSnapshot(
      articles: articles,
      sharedArticleIds: sharedIds,
    );
  }

  static Set<String> _loadSharedArticleIds() {
    final rawIds = PrefsUtil.getString(AppKeys.homeSharedArticleIds);
    if (rawIds != null && rawIds.isNotEmpty) {
      final decoded = jsonDecode(rawIds);
      if (decoded is List<dynamic>) {
        return decoded.whereType<String>().toSet();
      }
    }

    final legacyId = PrefsUtil.getString(AppKeys.homeLastSharedArticleId);
    if (legacyId != null && legacyId.isNotEmpty) {
      return {legacyId};
    }

    return {};
  }

  static Future<void> save({
    required List<HomeArticleItem> articles,
    required Set<String> sharedArticleIds,
  }) async {
    final encoded = jsonEncode(articles.map((item) => item.toJson()).toList());
    await PrefsUtil.setString(AppKeys.homeArticles, encoded);

    if (sharedArticleIds.isEmpty) {
      await PrefsUtil.remove(AppKeys.homeSharedArticleIds);
      await PrefsUtil.remove(AppKeys.homeLastSharedArticleId);
      return;
    }

    final idsEncoded = jsonEncode(sharedArticleIds.toList());
    await PrefsUtil.setString(AppKeys.homeSharedArticleIds, idsEncoded);
    await PrefsUtil.remove(AppKeys.homeLastSharedArticleId);
  }
}

class HomeArticleStoreSnapshot {
  const HomeArticleStoreSnapshot({
    required this.articles,
    required this.sharedArticleIds,
  });

  final List<HomeArticleItem> articles;
  final Set<String> sharedArticleIds;
}
