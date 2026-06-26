/// 环境配置
class EnvironmentConfig {
  static String get flavor => _flavor;

  /// FLAVOR: prod | dev | test
  static final String _flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'prod',
  );

  static EnvEnum get env {
    if (_flavor.contains('prod')) return EnvEnum.prod;
    if (_flavor.contains('dev')) return EnvEnum.dev;
    if (_flavor.contains('test')) return EnvEnum.test;
    return EnvEnum.prod;
  }

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

class ProductEnvironment with EnvironmentConfiguration {
  @override
  String get key => 'prod';

  @override
  String get baseUrl => 'https://api.example.com';
}

class DevEnvironment with EnvironmentConfiguration {
  @override
  String get key => 'dev';

  @override
  String get baseUrl => 'https://dev-api.example.com';
}

class TestEnvironment with EnvironmentConfiguration {
  @override
  String get key => 'test';

  @override
  String get baseUrl => 'https://test-api.example.com';
}

enum EnvEnum { prod, dev, test }

mixin EnvironmentConfiguration {
  String get baseUrl;
  String get key;
}
