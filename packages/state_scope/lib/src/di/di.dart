import 'impl/simple_service_locator.dart';

/// 依赖注入的静态门面。
/// 默认使用 [SimpleServiceLocator]，也可通过 [init] 替换为自定义实现。
class DI {
  DI._();

  static ServiceLocator _locator = SimpleServiceLocator();

  /// 替换底层 locator（可选，不调用则使用默认的 SimpleServiceLocator）。
  static void init(ServiceLocator locator) {
    _locator = locator;
  }

  /// 当前 locator，用于向下转型以使用某实现的独有能力。
  static ServiceLocator get locator => _locator;

  /// 注册实例 permanent 为 true 时，不会被删除
  static T put<T>(T dep, {String? tag, bool permanent = false}) =>
      _locator.put(dep, tag: tag, permanent: permanent);

  static T find<T>({String? tag}) => _locator.find<T>(tag: tag);

  static Future<bool> delete<T>({String? tag, bool force = false}) =>
      _locator.delete<T>(tag: tag, force: force);

  static bool isRegistered<T>({String? tag}) =>
      _locator.isRegistered<T>(tag: tag);

  /// 懒加载注册
  static void lazyPut<T>(
    T Function() builder, {
    String? tag,
    bool permanent = false,
  }) =>
      _locator.lazyPut<T>(builder, tag: tag, permanent: permanent);

  /// 异步注册
  static Future<T> putAsync<T>(
    Future<T> Function() builder, {
    String? tag,
    bool permanent = false,
  }) =>
      _locator.putAsync<T>(builder, tag: tag, permanent: permanent);
}
