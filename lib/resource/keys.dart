/// 本地存储 Key 常量
class AppKeys {
  static const String agreeUserAgreementAndPrivacyPolicy =
      'agreeUserAgreementAndPrivacyPolicy';

  static const String homeArticles = 'homeArticles';

  static const String homeSharedArticleIds = 'homeSharedArticleIds';

  /// 是否使用自定义分享端口。
  static const String shareUseCustomPort = 'shareUseCustomPort';

  /// 自定义分享端口（int）。
  static const String shareCustomPort = 'shareCustomPort';

  @Deprecated('Use homeSharedArticleIds')
  static const String homeLastSharedArticleId = 'homeLastSharedArticleId';
}
