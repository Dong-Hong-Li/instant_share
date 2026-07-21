/// 本地存储 Key 常量
class AppKeys {
  /// agreeUserAgreementAndPrivacyPolicy。
  static const String agreeUserAgreementAndPrivacyPolicy =
      'agreeUserAgreementAndPrivacyPolicy';

  /// homeArticles。
  static const String homeArticles = 'homeArticles';

  /// homeShared文章Ids。
  static const String homeSharedArticleIds = 'homeSharedArticleIds';

  /// 是否使用自定义分享端口。
  static const String shareUseCustomPort = 'shareUseCustomPort';

  /// 自定义分享端口（int）。
  static const String shareCustomPort = 'shareCustomPort';

  /// homeLastShared文章Id。
  @Deprecated('Use homeSharedArticleIds')
  static const String homeLastSharedArticleId = 'homeLastSharedArticleId';
}
