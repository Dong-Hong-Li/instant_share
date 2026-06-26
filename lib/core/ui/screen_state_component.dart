import 'package:instant_share/core/ui/base/base_view_model.dart';
import 'package:instant_share/core/utils/data/object_util.dart';
import 'package:flutter/material.dart';

/// 屏幕状态组件，与 [BaseViewModel.screenState] 配合；监听 [AppController] 的 [Listenable]，
/// 与 state_scope 的 [update] 一致。
///
/// ```dart
/// ScreenStateComponent<List<String>>(
///   controller: vm,
///   successBuilder: (data) => ListView.builder(
///     itemCount: data.length,
///     itemBuilder: (context, index) => Text(data[index]),
///   ),
///   onRetry: () => vm.load(),
/// )
/// ```
///
/// - [controller]：通常为 [DI.put] 的 [BaseViewModel] 子类实例。
/// - [successBuilder]：成功且有数据时的内容。
/// - [loadingWidget] / [initialWidget] / [errorWidget] / [emptyWidget]：可覆盖默认 UI。
/// - [showRetryButton]、[onRetry]：错误态是否展示重试（默认 `errorWidget` 为 null 时生效）。
/// - [showContentWhileRefreshing]：loading 时若 [BaseState.data] 仍有内容，则继续展示 [successBuilder]（后台刷新不闪）。
class ScreenStateComponent<T> extends StatefulWidget {
  /// 持有屏幕状态的 ViewModel（修改状态时会 [update]，触发本组件重建）
  final BaseViewModel<T> controller;

  /// 成功状态下的内容构建器
  final Widget Function(T data) successBuilder;

  /// 加载状态（[ViewModelStatus.loading]）
  final Widget? loadingWidget;

  /// 错误状态
  final Widget? errorWidget;

  /// 初始 / 未登录等（[ViewModelStatus.noLogin]）
  final Widget? initialWidget;

  /// 成功但数据为空（null 或 [ObjectUtil.isEmpty]）
  final Widget? emptyWidget;

  /// 是否在默认错误组件中显示重试按钮
  final bool showRetryButton;

  /// 重试回调
  final VoidCallback? onRetry;

  /// 动画配置，为 null 时不使用淡入动画
  final ScreenStateAnimation? animation;

  /// 为 true 时：处于 [ViewModelStatus.loading] 但若 [BaseState.data] 仍非空，
  /// 则继续走 [successBuilder]（后台刷新不闪 loading/骨架）。与 [BaseViewModel.setLoading] 保留旧 data 的写法配合。
  final bool showContentWhileRefreshing;

  const ScreenStateComponent({
    super.key,
    required this.controller,
    required this.successBuilder,
    this.loadingWidget,
    this.errorWidget,
    this.initialWidget,
    this.emptyWidget,
    this.showRetryButton = true,
    this.onRetry,
    this.animation,
    this.showContentWhileRefreshing = false,
  });

  @override
  State<ScreenStateComponent<T>> createState() =>
      _ScreenStateComponentState<T>();
}

class _ScreenStateComponentState<T> extends State<ScreenStateComponent<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  ViewModelStatus? _previousStatus;

  void _onControllerNotify() {
    if (!mounted) return;
    final currentStatus = widget.controller.status;

    if (_animationController.duration != widget.animation?.duration) {
      _animationController.duration =
          widget.animation?.duration ?? const Duration(milliseconds: 300);
    }

    if ((widget.animation?.repeat ?? false) &&
        !_animationController.isAnimating) {
      _animationController.repeat();
    } else if (!(widget.animation?.repeat ?? false) &&
        _animationController.isAnimating) {
      _animationController.stop();
    }

    if (_previousStatus != null && _previousStatus != currentStatus) {
      _handleStateChangeAnimation(_previousStatus!, currentStatus);
    }
    _previousStatus = currentStatus;

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _setupAnimationController();
    _previousStatus = widget.controller.status;
    _handleInitialState();
    widget.controller.addListener(_onControllerNotify);
  }

  void _setupAnimationController() {
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animation?.duration ?? const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: widget.animation?.curve ?? Curves.easeInOut,
      ),
    );

    if (widget.animation?.repeat ?? false) {
      _animationController.repeat();
    }
  }

  void _handleInitialState() {
    final currentStatus = widget.controller.status;
    if (currentStatus == ViewModelStatus.success) {
      if ((widget.animation?.autoPlay ?? true) &&
          !(widget.animation?.disableAnimation ?? false)) {
        _animationController.forward();
      } else {
        _animationController.value = 1.0;
      }
    } else {
      _animationController.value = 1.0;
    }
  }

  void _handleStateChangeAnimation(
    ViewModelStatus oldStatus,
    ViewModelStatus newStatus,
  ) {
    if (oldStatus == newStatus) return;

    if (widget.animation?.disableAnimation ?? false) {
      _animationController.value = 1.0;
      return;
    }

    if (newStatus == ViewModelStatus.success) {
      if (widget.animation?.autoPlay ?? true) {
        _animationController.reset();
        _animationController.forward();
      }
    } else if (oldStatus == ViewModelStatus.success) {
      _animationController.reverse().then((_) {
        if (mounted) {
          _animationController.value = 1.0;
        }
      });
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ScreenStateComponent<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerNotify);
      widget.controller.addListener(_onControllerNotify);
      _previousStatus = widget.controller.status;
    }

    if (oldWidget.animation?.duration != widget.animation?.duration ||
        oldWidget.animation?.repeat != widget.animation?.repeat) {
      _animationController.dispose();
      _setupAnimationController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerNotify);
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildChild(BaseState<T> state) {
    switch (state.status) {
      case ViewModelStatus.noLogin:
        return widget.initialWidget ??
            widget.loadingWidget ??
            const _DefaultLoadingWidget();
      case ViewModelStatus.loading:
        if (widget.showContentWhileRefreshing &&
            state.data != null &&
            !ObjectUtil.isEmpty(state.data)) {
          return widget.successBuilder(state.data as T);
        }
        return widget.loadingWidget ?? const _DefaultLoadingWidget();
      case ViewModelStatus.error:
        return widget.errorWidget ??
            _DefaultErrorWidget(
              message: state.errorMessage ?? '加载失败',
              showRetry: widget.showRetryButton,
              onRetry: widget.onRetry,
            );
      case ViewModelStatus.success:
        if (state.data == null || ObjectUtil.isEmpty(state.data)) {
          return widget.emptyWidget ?? const _DefaultEmptyWidget();
        }
        return widget.successBuilder(state.data as T);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.screenState;
    Widget currentChild = _buildChild(state);

    final showSuccessFade = state.data != null &&
        !ObjectUtil.isEmpty(state.data) &&
        (state.status == ViewModelStatus.success ||
            (widget.showContentWhileRefreshing &&
                state.status == ViewModelStatus.loading));

    if (widget.animation != null &&
        showSuccessFade &&
        !(widget.animation?.disableAnimation ?? false)) {
      return FadeTransition(opacity: _fadeAnimation, child: currentChild);
    }
    return currentChild;
  }
}

class _DefaultLoadingWidget extends StatelessWidget {
  const _DefaultLoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _DefaultEmptyWidget extends StatelessWidget {
  const _DefaultEmptyWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '暂无数据',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _DefaultErrorWidget extends StatelessWidget {
  const _DefaultErrorWidget({
    required this.message,
    required this.showRetry,
    this.onRetry,
  });

  final String message;
  final bool showRetry;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (showRetry && onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ],
        ),
      ),
    );
  }
}

/// 屏幕状态组件动画配置
class ScreenStateAnimation {
  /// 动画时长
  final Duration duration;

  /// 是否自动播放
  final bool autoPlay;

  /// 是否重复播放
  final bool repeat;

  /// 是否禁用动画
  final bool disableAnimation;

  /// 动画曲线
  final Curve curve;

  const ScreenStateAnimation({
    this.duration = const Duration(milliseconds: 300),
    this.autoPlay = true,
    this.repeat = false,
    this.disableAnimation = false,
    this.curve = Curves.easeInOut,
  });
}
