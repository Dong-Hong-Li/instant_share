import '../../controller/app_controller.dart';

abstract class ServiceLocator {
  /// 注册实例
  T put<T>(T instance, {String? tag, bool permanent = false});

  /// 查找实例
  T find<T>({String? tag});

  /// 删除实例
  Future<bool> delete<T>({String? tag, bool force = false});

  /// 是否已注册
  bool isRegistered<T>({String? tag});

  /// 懒加载：首次 find 时才调用 builder 创建实例。
  void lazyPut<T>(T Function() builder, {String? tag, bool permanent = false});

  /// 异步创建：await builder 完成后注册。
  Future<T> putAsync<T>(
    Future<T> Function() builder, {
    String? tag,
    bool permanent = false,
  });
}

class SimpleServiceLocator implements ServiceLocator {
  SimpleServiceLocator();

  /// 实例缓存
  final Map<String, _Entry> _instances = {};

  String _key<T>(String? tag) => '${T.toString()}${tag ?? ''}';

  @override
  T put<T>(T instance, {String? tag, bool permanent = false}) {
    final key = _key<T>(tag);
    _instances[key] = _Entry(instance: instance, permanent: permanent);
    _runInitialize(instance);
    return instance;
  }

  @override
  T find<T>({String? tag}) {
    final key = _key<T>(tag);
    final entry = _instances[key];
    if (entry == null) {
      throw StateError(
        '"$T" 未注册，请先调用 "DI.put($T())" 或 "DI.lazyPut(() => $T())"。',
      );
    }
    if (entry.builder != null) {
      final instance = entry.builder!() as T;
      _instances[key] = _Entry(instance: instance, permanent: entry.permanent);
      _runInitialize(instance);
      return instance;
    }
    return entry.instance as T;
  }

  @override
  Future<bool> delete<T>({String? tag, bool force = false}) async {
    final key = _key<T>(tag);
    final entry = _instances[key];
    if (entry == null) return false;
    if (entry.permanent && !force) return false;
    _instances.remove(key);
    return true;
  }

  @override
  bool isRegistered<T>({String? tag}) {
    return _instances.containsKey(_key<T>(tag));
  }

  @override
  void lazyPut<T>(
    T Function() builder, {
    String? tag,
    bool permanent = false,
  }) {
    final key = _key<T>(tag);
    _instances[key] = _Entry(
      permanent: permanent,
      builder: builder,
    );
  }

  @override
  Future<T> putAsync<T>(
    Future<T> Function() builder, {
    String? tag,
    bool permanent = false,
  }) async {
    final instance = await builder();
    put<T>(instance, tag: tag, permanent: permanent);
    return instance;
  }

  /// 若 [instance] 为 [AppController]，自动调用 [AppController.initialize]（幂等）。
  void _runInitialize(dynamic instance) {
    if (instance is AppController) {
      instance.initialize();
    }
  }
}

class _Entry {
  _Entry({
    this.instance,
    required this.permanent,
    this.builder,
  });

  /// 实例
  final dynamic instance;

  /// 是否永久
  final bool permanent;

  /// 懒加载构建器
  final dynamic Function()? builder;
}
