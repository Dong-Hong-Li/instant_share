import 'package:state_scope/state_scope.dart';

/// 通用状态枚举
enum ViewModelStatus {
  /// 加载状态
  loading,

  /// 成功状态
  success,

  /// 错误状态
  error,

  /// 未登录
  noLogin,
}

/// 通用状态类
class BaseState<T> {
  final ViewModelStatus status;
  final T? data;
  final String? errorMessage;

  const BaseState({
    this.status = ViewModelStatus.noLogin,
    this.data,
    this.errorMessage,
  });

  /// 创建加载状态
  BaseState<T> copyWithLoading() {
    return BaseState<T>(status: ViewModelStatus.loading, data: data);
  }

  /// 创建成功状态
  BaseState<T> copyWithSuccess(T data) {
    return BaseState<T>(status: ViewModelStatus.success, data: data);
  }

  /// 创建错误状态
  BaseState<T> copyWithError(String errorMessage) {
    return BaseState<T>(
      status: ViewModelStatus.error,
      data: data,
      errorMessage: errorMessage,
    );
  }

  /// 创建未登录状态
  BaseState<T> copyWithNoLogin() {
    return BaseState<T>(status: ViewModelStatus.noLogin, data: data);
  }
}

/// 页面级 ViewModel：屏幕状态存于 [screenState]，通过 [update] 驱动 [ControllerBuilder] /
/// [ScreenStateComponent] 刷新（与 [AppController] / state_scope 一致）。
///
/// ```dart
/// class UserPageVm extends BaseViewModel<UserProfile> {
///   @override
///   void onInit() {
///     super.onInit();
///     load();
///   }
///
///   Future<void> load() => execute(() async {
///     return UserRepository.instance.fetchProfile();
///   });
/// }
///
/// ScreenStateComponent<UserProfile>(
///   controller: vm,
///   successBuilder: (data) => Text(data.name),
///   onRetry: () => vm.load(),
/// );
/// ```
abstract class BaseViewModel<T> extends AppController {
  BaseState<T> _screenState = const BaseState();

  /// 当前屏幕状态（加载 / 成功 / 错误 / 未登录）
  BaseState<T> get screenState => _screenState;

  ViewModelStatus get status => _screenState.status;
  T? get data => _screenState.data;
  String? get errorMessage => _screenState.errorMessage;

  bool get isLoading => status == ViewModelStatus.loading;
  bool get isSuccess => status == ViewModelStatus.success;
  bool get isError => status == ViewModelStatus.error;
  bool get isNoLogin => status == ViewModelStatus.noLogin;

  void _applyScreenState(BaseState<T> next) {
    _screenState = next;
    update();
  }

  /// 更新为加载状态
  void setLoading() {
    _applyScreenState(_screenState.copyWithLoading());
  }

  /// 更新为成功状态
  void setSuccess(T data) {
    _applyScreenState(_screenState.copyWithSuccess(data));
  }

  /// 更新为错误状态
  void setError([String errorMessage = '加载失败']) {
    _applyScreenState(_screenState.copyWithError(errorMessage));
  }

  /// 更新为未登录状态
  void setNoLogin() {
    _applyScreenState(_screenState.copyWithNoLogin());
  }

  /// 重置为默认状态（未登录）
  void reset() {
    _applyScreenState(const BaseState());
  }

  /// 执行异步请求：进入 loading → 成功则 [setSuccess]；失败则 [setError]，并保留上次 [data]（便于错误页展示或重试）。
  ///
  /// 若需在发起请求时清空展示数据，可先自行 [reset] 或扩展本类。
  Future<void> execute(
    Future<T> Function() task, {
    void Function(Object e, StackTrace st)? onError,
  }) async {
    setLoading();
    try {
      final result = await task();
      setSuccess(result);
    } catch (e, st) {
      onError?.call(e, st);
      setError(e.toString());
    }
  }

  @override
  void onClose() {
    _screenState = const BaseState();
    super.onClose();
  }
}
