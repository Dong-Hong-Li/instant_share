/// 环境配置
class EnvironmentConfig {
  static String get flavor => _flavor;

  static final String _flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'prod',
  );

  /// 当前环境枚举。
  static EnvEnum get env {
    if (_flavor.contains('prod')) return EnvEnum.prod;
    if (_flavor.contains('dev')) return EnvEnum.dev;
    if (_flavor.contains('test')) return EnvEnum.test;
    return EnvEnum.prod;
  }

  /// 当前环境配置。
  static EnvironmentConfiguration get environment {
    switch (env) {
      case EnvEnum.prod:
        return ProductEnvironment();
      case EnvEnum.dev:
        return DevEnvironment();
      case EnvEnum.test:
        return TestEnvironment();
    }
  }
}

/// 生产环境配置。
class ProductEnvironment with EnvironmentConfiguration {
  /// 键。
  @override
  String get key => 'prod';

  /// 基础地址。
  @override
  String get baseUrl => 'https://api.example.com';
}

/// 开发环境配置。
class DevEnvironment with EnvironmentConfiguration {
  /// 键。
  @override
  String get key => 'dev';

  /// 基础地址。
  @override
  String get baseUrl => 'https://dev-api.example.com';
}

/// 测试环境配置。
class TestEnvironment with EnvironmentConfiguration {
  /// 键。
  @override
  String get key => 'test';

  /// 基础地址。
  @override
  String get baseUrl => 'https://test-api.example.com';
}

/// EnvEnum枚举。
enum EnvEnum { prod, dev, test }

/// 环境配置接口。
mixin EnvironmentConfiguration {
  /// 基础地址。
  String get baseUrl;

  /// 键。
  String get key;
}
