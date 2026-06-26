import 'package:flutter/widgets.dart';

import 'app_stream_provider.dart';

/// Tier 3：对 [AppStreamProvider] 使用 [StreamBuilder] 的声明式封装。
///
/// ```dart
/// final tickerProvider = AppStreamProvider<int>(
///   () => Stream.periodic(const Duration(seconds: 1), (i) => i),
/// );
///
/// AppStreamBuilder<int>(
///   provider: tickerProvider,
///   builder: (context, snapshot) {
///     if (snapshot.hasError) return Text('${snapshot.error}');
///     if (!snapshot.hasData) return const CircularProgressIndicator();
///     return Text('${snapshot.data}');
///   },
/// )
/// ```
class AppStreamBuilder<T> extends StatefulWidget {
  const AppStreamBuilder({
    super.key,
    required this.provider,
    required this.builder,
    this.initialData,
  });

  final AppStreamProvider<T> provider;

  /// 对应 [StreamBuilder.initialData]。
  final T? initialData;

  final AsyncWidgetBuilder<T> builder;

  @override
  State<AppStreamBuilder<T>> createState() => _AppStreamBuilderState<T>();
}

class _AppStreamBuilderState<T> extends State<AppStreamBuilder<T>> {
  late Stream<T> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.provider.create();
  }

  @override
  void didUpdateWidget(covariant AppStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.provider, widget.provider)) {
      _stream = widget.provider.create();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: _stream,
      initialData: widget.initialData,
      builder: widget.builder,
    );
  }
}

/// [AppStreamFamilyProvider] + [StreamBuilder]；[arg] 或 provider 引用变化时重新 [create]。
class AppStreamFamilyBuilder<T, Arg> extends StatefulWidget {
  const AppStreamFamilyBuilder({
    super.key,
    required this.provider,
    required this.arg,
    required this.builder,
    this.initialData,
  });

  final AppStreamFamilyProvider<T, Arg> provider;

  final Arg arg;

  final T? initialData;

  final AsyncWidgetBuilder<T> builder;

  @override
  State<AppStreamFamilyBuilder<T, Arg>> createState() =>
      _AppStreamFamilyBuilderState<T, Arg>();
}

class _AppStreamFamilyBuilderState<T, Arg>
    extends State<AppStreamFamilyBuilder<T, Arg>> {
  late Stream<T> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.provider.create(widget.arg);
  }

  @override
  void didUpdateWidget(covariant AppStreamFamilyBuilder<T, Arg> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.provider, widget.provider) ||
        oldWidget.arg != widget.arg) {
      _stream = widget.provider.create(widget.arg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: _stream,
      initialData: widget.initialData,
      builder: widget.builder,
    );
  }
}
