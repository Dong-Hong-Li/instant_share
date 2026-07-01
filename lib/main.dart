import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:instant_share/routes/router_config.router.g.dart';
import 'package:state_scope/state_scope.dart';
import 'package:instant_share/core/config/common.dart';
import 'package:instant_share/core/config/desktop_window_config.dart';
import 'package:instant_share/core/controller/app_theme_controller.dart';
import 'package:instant_share/routes/app_router_observer.dart';
import 'package:instant_share/routes/router_config.dart';
import 'package:instant_share/core/shared/initialization_provider.dart';
import 'package:instant_share/core/shared/logger_manager.dart';
import 'package:instant_share/core/shared/theme_manager.dart';
import 'package:instant_share/infrastructure/share_server/embedded_server_runtime.dart';
import 'package:instant_share/infrastructure/share_server/share_server_lifecycle.dart';
import 'package:instant_share/core/utils/storage/prefs_util.dart';
import 'package:instant_share/core/ui/widget/desktop_window_frame.dart';
import 'package:instant_share/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopWindowConfig.ensureInitialized();
  await PrefsUtil.init();
  DI.put(AppThemeController(), permanent: true);
  runAppEntry();
}

void runAppEntry() {
  runZonedGuarded(() async {
    PaintingBinding.instance.imageCache.maximumSizeBytes = 1000 * 1024 * 1024;
    PaintingBinding.instance.imageCache.maximumSize = 1000;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        statusBarColor: Colors.transparent,
      ),
    );
    await _initializeApp();
    // runApp 必须在与 ensureInitialized 同一 Zone（根 Zone）中调用，避免 Zone mismatch
    Zone.root.run(
      () => runApp(
        const ProviderScope(child: ShareServerLifecycle(child: MyApp())),
      ),
    );
  }, LoggerManager.handleError);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ControllerBuilder<AppThemeController>(
      builder: (controller) {
        return ScreenUtilInit(
          designSize: const Size(900, 700),
          minTextAdapt: true,
          splitScreenMode: true,
          ensureScreenSize: true,
          builder: (context, child) {
            controller.initScreenDimens();
            return MaterialApp(
              navigatorKey: CommonContext.navigatorKey,
              navigatorObservers: [AppRouterObserver()],
              theme: ThemeManager.instance.lightThemeData,
              darkTheme: ThemeManager.instance.darkThemeData,
              themeMode: controller.themeMode,
              debugShowCheckedModeBanner: false,
              locale: controller.currentLocale,
              localizationsDelegates: [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales(),
              initialRoute: RootPath.home,
              onGenerateRoute: CommonContext.router.generator,
              builder: (context, child) {
                Widget appChild = MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.noScaling),
                  child: _SystemOverlaySync(
                    controller: controller,
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
                if (DesktopWindowConfig.isDesktop) {
                  appChild = DesktopWindowFrame(
                    borderRadius: DesktopWindowConfig.windowBorderRadius,
                    child: appChild,
                  );
                }
                return appChild;
              },
            );
          },
        );
      },
    );
  }
}

/// 当主题为「跟随系统」时，根据系统亮度同步状态栏/导航条样式
class _SystemOverlaySync extends StatefulWidget {
  const _SystemOverlaySync({required this.controller, required this.child});

  final AppThemeController controller;
  final Widget child;

  @override
  State<_SystemOverlaySync> createState() => _SystemOverlaySyncState();
}

class _SystemOverlaySyncState extends State<_SystemOverlaySync> {
  Brightness? _lastAppliedBrightness;

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isSystemMode) {
      final brightness = MediaQuery.platformBrightnessOf(context);
      if (_lastAppliedBrightness != brightness) {
        _lastAppliedBrightness = brightness;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          SystemChrome.setSystemUIOverlayStyle(
            ThemeManager.instance.getSystemOverlayStyleForBrightness(
              brightness,
            ),
          );
        });
      }
    } else {
      _lastAppliedBrightness = null;
    }
    return widget.child;
  }
}

Future<void> _initializeApp() async {
  final manager = InitializationProvider();

  manager.addTask(
    name: 'router_init',
    critical: true,
    task: () async {
      final router = RouteConfig.instance;
      router.initAllHandlers();
    },
  );

  if (CommonContext.isDesktop || CommonContext.isAndroid) {
    manager.addTask(
      name: 'share_server',
      critical: true,
      timeout: const Duration(seconds: 20),
      retryCount: 0,
      task: EmbeddedServerRuntime.instance.ensureStarted,
    );
  }

  if (CommonContext.isMobile) {
    manager.addTask(
      name: 'orientation',
      task: () async {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      },
    );
  }

  final results = await manager.executeCritical();
  manager.executeBestEffortInBackground();

  const critical = ['router_init', 'share_server'];
  for (final name in critical) {
    if (name == 'share_server' &&
        !CommonContext.isDesktop &&
        !CommonContext.isAndroid) {
      continue;
    }
    final r = results[name];
    if (r != null && !r.isSuccess) {
      debugPrint('[Init] 关键任务失败: $name, error=${r.error}');
    }
  }
}
