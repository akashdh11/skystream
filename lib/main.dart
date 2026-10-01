import 'dart:async';
import 'dart:io';

import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter/material.dart';

import 'features/player/presentation/player_debug_flags.dart'
    show kPlayerRepaintRainbow;

import 'package:flutter/rendering.dart' show debugRepaintRainbowEnabled;
import 'package:flutter/services.dart'; // LogicalKeyboardKey, KeyDownEvent
import 'package:flutter/foundation.dart'; // For kReleaseMode
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/storage_service.dart';
import 'core/network/doh_service.dart';

import 'package:dynamic_color/dynamic_color.dart';

import 'core/utils/app_utils.dart';
import 'features/extensions/providers/extensions_controller.dart';
import 'core/addons/data/addon_repository.dart';
import 'core/models/extension_update_report.dart';
import 'core/nuvio/data/nuvio_repository.dart';
import 'features/extensions/widgets/extensions_sync_bridge.dart';
import 'core/providers/update_provider.dart';
import 'core/widgets/update_dialog.dart';
import 'core/widgets/app_error_boundary.dart';
import 'core/services/download_service.dart';
import 'core/services/notification_service.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import 'core/providers/locale_provider.dart';
import 'core/network/cloudflare_bypass.dart';
import 'core/config/tmdb_config.dart';
import 'core/providers/bootstrap_provider.dart' show quietDesktopBrightness;
import 'core/providers/device_info_provider.dart';
import 'shared/focus/app_focus.dart';
import 'shared/widgets/loading_indicator.dart';
import 'shared/widgets/tv_logical_scale.dart';
import 'core/providers/ui_scale_provider.dart';
import 'core/widgets/m3_toast_overlay.dart';
import 'features/settings/presentation/general_settings_provider.dart';
import 'features/settings/presentation/full_screen_mode_provider.dart';
import 'features/player/presentation/player_platform_service.dart'
    show immersiveRouteActive;

void main() async {
  // First statement in the process: a framework or async error raised while
  // the rest of this function runs has nowhere else to go. Installs
  // FlutterError.onError, PlatformDispatcher.onError and ErrorWidget.builder -
  // see lib/core/widgets/app_error_boundary.dart.
  installGlobalErrorHandlers();

  WidgetsFlutterBinding.ensureInitialized();

  // Cap Flutter's image cache. Default is 1000 entries / 100 MB which is too
  // generous for low-RAM TVs and even most phones — decoded TMDB posters fill
  // it quickly. Tighter limits force earlier eviction and keep raster smooth.
  PaintingBinding.instance.imageCache
    ..maximumSize = 200
    ..maximumSizeBytes = 50 * 1024 * 1024; // 50 MB

  // Repaint rainbow for the flicker hunt - see player_debug_flags.dart. A
  // compile-time constant, so a normal build carries no trace of it.
  if (kPlayerRepaintRainbow) debugRepaintRainbowEnabled = true;

  // Silence the console in release mode. Diagnostics are not lost: the Talker
  // ring buffer stays enabled in release (see app_logger.dart) so /logs and its
  // export still have the run-up to a crash in them.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Native window init (Desktop) - Run once
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();

    final windowOptions = WindowOptions(
      size: const Size(1280, 720),
      minimumSize: const Size(360, 640),
      center: true,
      backgroundColor: Colors.black, // Solid black prevents transparency during fullscreen transition
      skipTaskbar: false,
      titleBarStyle: Platform.isMacOS
          ? TitleBarStyle.normal
          : TitleBarStyle.hidden,
    );

    unawaited(
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  // AppRoot opens storage and then builds the app's ProviderScope, which the
  // rule cannot see through.
  // ignore: riverpod_lint/missing_provider_scope
  AppUtils.setRestartFunction(() => runApp(const AppRoot()));
  // ignore: riverpod_lint/missing_provider_scope
  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late StorageService _storageService;
  bool _initialized = false;
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _storageService = StorageService();
    try {
      await Future.wait([
        _storageService.init(),
        DohService.instance.init(),
        if (Platform.isAndroid)
          FlutterDisplayMode.setHighRefreshRate().catchError((Object e) {
            if (kDebugMode) debugPrint("Error setting high refresh rate: $e");
          }),
      ]);

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final alwaysOnTop = _storageService.isAlwaysOnTop();
        await windowManager.setAlwaysOnTop(alwaysOnTop);
        // Stops screen_brightness issuing DDC/CI to the monitor on desktop.
        // Here rather than in Bootstrap: bootstrapProvider is never read by
        // anything, so Bootstrap.build() does not run in the shipped app and
        // this is the init path that does.
        //
        // Deliberately not awaited. Nothing below depends on it, it swallows
        // its own failures, and awaiting would put a plugin round-trip on the
        // launch critical path - a channel call that never returns would be an
        // app that never paints. Fire it and move on.
        unawaited(quietDesktopBrightness());
      }

      if (mounted) {
        setState(() {
          _initialized = true;
        });
        // Pre-warm the system WebView after the first frame so the initial
        // render isn't delayed. This eliminates the frame jank that occurs
        // when the CF bypass spawns its HeadlessInAppWebView cold during search.
        if (Platform.isAndroid || Platform.isIOS) {
          Future.delayed(
            const Duration(seconds: 3),
            CloudflareBypass.instance.prewarm,
          );
        }
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _error = e;
          _stackTrace = stack;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return LaunchErrorApp(
        error: _error!,
        stackTrace: _stackTrace,
        storageService: _storageService,
      );
    }

    if (!_initialized) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            final color =
                lightDynamic?.primary ??
                const Color(0xFF6200EE); // Default Purple/Blue
            return ColoredBox(
              color: Colors.black,
              child: Center(child: AppLoadingIndicator(color: color)),
            );
          },
        ),
      );
    }

    return ProviderScope(
      // The app's root scope - below AppRoot only because storage has to open
      // first - so there is no parent scope for dependencies to describe.
      // ignore: riverpod_lint/scoped_providers_should_specify_dependencies
      overrides: [storageServiceProvider.overrideWithValue(_storageService)],
      child: const ExtensionsSyncBridge(child: MyApp()),
    );
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyKeyEvent);
    // Brings back the ten-foot layout if the last session was left in it.
    // Applied here rather than in `main` because it reads through a provider,
    // which needs the scope this widget sits inside.
    ref.read(fullScreenModeProvider.notifier).initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(downloadServiceProvider).init();
      unawaited(_loadInstalledExtensions());
      _checkAppUpdates();
      unawaited(_checkExtensionsUpdates());
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyKeyEvent);
    super.dispose();
  }

  KeyEventResult _handleEarlyKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }

    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) {
      return KeyEventResult.ignored;
    }

    final context = primaryFocus.context;
    if (context == null || !context.mounted) {
      return KeyEventResult.ignored;
    }

    final renderObject = context.findRenderObject();
    if (renderObject == null) {
      return KeyEventResult.ignored;
    }

    RenderObject? current = renderObject;
    bool isLaidOut = true;
    while (current != null) {
      if (current is RenderBox && !current.hasSize) {
        isLaidOut = false;
        break;
      }
      final parent = current.parent;
      if (parent is RenderObject) {
        current = parent;
      } else {
        break;
      }
    }

    if (!isLaidOut) {
      if (kDebugMode) {
        debugPrint(
          '[FocusGuard] Consumed key event ${event.logicalKey.keyLabel} because primary focus context or its ancestor is not laid out.',
        );
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _checkAppUpdates() async {
    if (kDebugMode) {
      debugPrint('[Lifecycle] Starting _checkAppUpdates after 5s delay...');
    }
    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) {
      if (kDebugMode) {
        debugPrint('[Lifecycle] _checkAppUpdates aborted: MyApp unmounted');
      }
      return;
    }

    try {
      final controller = ref.read(updateControllerProvider.notifier);
      await controller.checkForUpdates();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("[Lifecycle] App update trigger failed: $e");
      }
    }
  }

  /// Reads the plugins the user already has on disk into
  /// [ExtensionsController], on every launch, before anything asks for a
  /// stream provider.
  ///
  /// Local disk only: no repository manifest is fetched here. Discovering
  /// *newer* versions is [_checkExtensionsUpdates]'s job, and it waits for the
  /// launch to finish first. Loading what is already installed must not wait
  /// on the network at all. The installed inventory is the only thing that
  /// ever populates [ExtensionManager] - `ExtensionsSyncBridge` listens for it
  /// to change and syncs it across - and with it empty `getAllProviders()` is
  /// empty, so search finds nothing, the details screen offers no sources, and
  /// the home screen's active-provider resolution never completes: it spins
  /// forever waiting for a sync that cannot arrive. Tying this to a
  /// repository answering would strand exactly the users who already have
  /// plugins installed, whenever that repository is slow or unreachable.
  Future<void> _loadInstalledExtensions() async {
    try {
      await ref
          .read(extensionsControllerProvider.notifier)
          .loadInstalledPlugins();
    } catch (e) {
      if (kDebugMode) debugPrint('Installed extension load failed: $e');
    }
  }

  /// How long the extension update check waits after the first frame.
  ///
  /// It used to run *in* that first post-frame callback: one HTTP round trip
  /// per repository, then a download and install of every outdated plugin,
  /// then a QuickJS precompile - in the same seconds the home screen is
  /// fetching and decoding posters. On a 2016-era Android TV stick that is the
  /// first scroll of the session. Nothing downstream of this check is on
  /// screen, so it waits until the launch is over rather than racing it.
  static const Duration _extensionsCheckDelay = Duration(seconds: 15);

  /// Brings every extension system up to date in the background - SkyStream
  /// plugins, Nuvio scrapers and Stremio add-ons - and says what changed:
  /// what was updated, which repositories a followed collection brought in,
  /// and which plugins appeared in a repository.
  ///
  /// Every launch, on any connection. Extensions scrape sites that change
  /// under them, and the app's core job - finding something to play - runs on
  /// them, so a stale one is the difference between a title playing and not.
  /// The three run side by side, each on its own, so one that fails does not
  /// hold the others back.
  Future<void> _checkExtensionsUpdates() async {
    await Future<void>.delayed(_extensionsCheckDelay);
    if (!mounted) return;

    final reports = await Future.wait(<Future<ExtensionUpdateReport>>[
      _updating(
        'SkyStream plugins',
        () => ref.read(extensionsControllerProvider.notifier).autoUpdate(),
      ),
      _updating(
        'Nuvio scrapers',
        () => ref.read(nuvioRepositoryProvider.notifier).autoUpdate(),
      ),
      _updating(
        'Stremio add-ons',
        () async => ExtensionUpdateReport(
          updated: await ref
              .read(addonRepositoryProvider.notifier)
              .autoUpdate(),
        ),
      ),
    ]);
    final report = ExtensionUpdateReport.merge(reports);
    if (report.isEmpty || !mounted) return;
    _announceExtensionUpdates(report);
  }

  /// One extension system's pass, with a failure read as "nothing changed".
  static Future<ExtensionUpdateReport> _updating(
    String what,
    Future<ExtensionUpdateReport> Function() update,
  ) async {
    try {
      return await update();
    } catch (e) {
      if (kDebugMode) debugPrint('Updating $what failed: $e');
      return const ExtensionUpdateReport();
    }
  }

  /// A toast per kind of news - see [ExtensionUpdateReport.toasts]. Nothing
  /// to act on: updates are installed, repositories added, and new plugins
  /// wait on the Extensions screen.
  ///
  /// Reads its strings off the *router's* context: this State sits above
  /// `MaterialApp`, so its own context has no `Localizations` ancestor. If the
  /// navigator is not up yet there is no toast; the work is done either way.
  void _announceExtensionUpdates(ExtensionUpdateReport report) {
    final router = ref.read(appRouterProvider);
    final navContext = router.routerDelegate.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    final l10n = AppLocalizations.of(navContext);
    if (l10n == null) return;

    final notifications = ref.read(notificationServiceProvider);
    for (final toast in report.toasts(l10n)) {
      notifications.showToast(
        title: toast.title,
        message: toast.message,
        type: ToastType.extension,
        icon: Icons.extension_rounded,
      );
    }
  }

  Future<void> _toggleFullscreen() async {
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) return;
    try {
      final isFull = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFull);
    } catch (e) {
      if (kDebugMode) debugPrint('_toggleFullscreen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);
    final appRouter = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final profileAsync = ref.watch(deviceProfileProvider);

    // Mirror the resolved device profile into TmdbConfig's static cache so
    // pure-utility URL builders (AppImageFallbacks, TmdbDetails ctor) pick
    // TV / desktop-class image sizes once the async profile resolves.
    // Until then they fall back to the mobile defaults — a few cold-start
    // frames may use w1280 backdrops on TV before snapping to original.
    ref.listen<AsyncValue<DeviceProfile>>(deviceProfileProvider, (prev, next) {
      final value = next.value;
      if (value != null) TmdbConfig.setProfile(value);
    });

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme? darkScheme;
        if (darkDynamic != null) {
          darkScheme = darkDynamic;
        }

        final materialApp = MaterialApp.router(
          scaffoldMessengerKey: ref
              .read(notificationServiceProvider)
              .messengerKey,
          title: 'SkyStream',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: lightDynamic != null
              ? AppTheme.createLightTheme(lightDynamic)
              : AppTheme.createLightTheme(null),
          darkTheme: AppTheme.createDarkTheme(darkScheme),
          routerConfig: appRouter,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            Widget result = child!;

            // A television reports about 960 dp of width whatever its panel
            // is, so the same layout that breathes on a laptop is drawn at
            // twice the relative size on a set. [TvLogicalScale] hands the
            // tree more logical pixels and scales the result back up to fill
            // the screen; it steps aside on the player, whose video is a
            // platform view and has to be laid out at the panel's own
            // resolution. See that file for what this replaced and why the
            // old `devicePixelRatio: 1.0` never did it.
            final profile = profileAsync.asData?.value;
            result = TvLogicalScale(
              enabled: profile?.isTv == true,
              userScale: ref.watch(uiScaleProvider),
              router: appRouter,
              child: result,
            );

            if (!kIsWeb &&
                (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
              final isMac = Platform.isMacOS;
              if (!isMac) {
                result = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: result),
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: CustomTitleBar(),
                    ),
                  ],
                );
              }
            }

            // Both of these stand down over the player, and both need the
            // router to know it, so they sit together here - inside
            // `MaterialApp.router`'s builder, i.e. around the Navigator that
            // builds the player route.
            result = UpdatePromptHost(child: M3ToastOverlay(child: result));

            // Outermost, so every focus indicator in the app - the browsing
            // UI, the player chrome, dialogs and the toast host alike - reads
            // one answer to "is anyone driving this with a remote or a
            // keyboard right now". See `shared/focus/app_focus.dart`.
            //
            // A television shows focus from the first frame; anything else
            // waits for a key. See the scope for the rule.
            return FocusVisibilityScope(
              television: profile?.isTv == true,
              child: result,
            );
          },
        );

        Widget rootWidget = materialApp;

        if (Platform.isMacOS) {
          final alwaysOnTop = ref.watch(
            generalSettingsProvider.select((s) => s.alwaysOnTop),
          );
          rootWidget = PlatformMenuBar(
            menus: <PlatformMenuItem>[
              PlatformMenu(
                label: 'SkyStream',
                menus: <PlatformMenuItem>[
                  if (PlatformProvidedMenuItem.hasMenu(
                    PlatformProvidedMenuItemType.about,
                  ))
                    const PlatformProvidedMenuItem(
                      type: PlatformProvidedMenuItemType.about,
                    ),
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.quit,
                  ),
                ],
              ),
              PlatformMenu(
                label: 'Edit',
                menus: <PlatformMenuItem>[
                  PlatformMenuItem(
                    label: 'Undo',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyZ,
                      meta: true,
                    ),
                    onSelected: () {},
                  ),
                  PlatformMenuItem(
                    label: 'Redo',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyZ,
                      meta: true,
                      shift: true,
                    ),
                    onSelected: () {},
                  ),
                  const PlatformMenuItemGroup(
                    members: <PlatformMenuItem>[
                      PlatformMenuItem(
                        label: 'Cut',
                        shortcut: SingleActivator(
                          LogicalKeyboardKey.keyX,
                          meta: true,
                        ),
                        onSelected: null,
                      ),
                      PlatformMenuItem(
                        label: 'Copy',
                        shortcut: SingleActivator(
                          LogicalKeyboardKey.keyC,
                          meta: true,
                        ),
                        onSelected: null,
                      ),
                      PlatformMenuItem(
                        label: 'Paste',
                        shortcut: SingleActivator(
                          LogicalKeyboardKey.keyV,
                          meta: true,
                        ),
                        onSelected: null,
                      ),
                      PlatformMenuItem(
                        label: 'Select All',
                        shortcut: SingleActivator(
                          LogicalKeyboardKey.keyA,
                          meta: true,
                        ),
                        onSelected: null,
                      ),
                    ],
                  ),
                ],
              ),
              PlatformMenu(
                label: 'Window',
                menus: <PlatformMenuItem>[
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.minimizeWindow,
                  ),
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.zoomWindow,
                  ),
                  PlatformMenuItem(
                    label: alwaysOnTop ? 'Disable Stay on Top' : 'Stay on Top',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyT,
                      meta: true,
                      control: true,
                    ),
                    onSelected: () async {
                      final nextVal = !alwaysOnTop;
                      await ref
                          .read(generalSettingsProvider.notifier)
                          .setAlwaysOnTop(nextVal);
                      await windowManager.setAlwaysOnTop(nextVal);
                    },
                  ),
                ],
              ),
            ],
            child: rootWidget,
          );
        }

        return rootWidget;
      },
    );
  }
}

class LaunchErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final StorageService storageService;

  const LaunchErrorApp({
    super.key,
    required this.error,
    this.stackTrace,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n?.startupError ?? 'Startup Error',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error.toString(),
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n?.retry ?? 'Retry'),
                      onPressed: () => AppUtils.restartApp(context),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: Text(l10n?.factoryReset ?? 'Factory Reset'),
                      onPressed: () async {
                        await storageService.deleteAllData();
                        if (context.mounted) await AppUtils.restartApp(context);
                      },
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.orange),
                      ),
                      icon: const Icon(Icons.restore),
                      label: Text(
                        l10n?.resetDataKeepExtensions ??
                            'Reset Data (Keep Extensions)',
                      ),
                      onPressed: () async {
                        await storageService.clearPreferences();
                        if (context.mounted) await AppUtils.restartApp(context);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _hovered = false;
  bool _isMaximized = false;
  bool _isFullScreen = false;
  bool _isAlwaysOnTop = false;

  /// Whether a route is drawing to the window's own edges - the player.
  bool _immersiveRoute = immersiveRouteActive.value;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    immersiveRouteActive.addListener(_onImmersiveRouteChanged);
    _updateStates();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    immersiveRouteActive.removeListener(_onImmersiveRouteChanged);
    super.dispose();
  }

  void _onImmersiveRouteChanged() {
    if (!mounted) return;
    setState(() {
      _immersiveRoute = immersiveRouteActive.value;
      // The MouseRegion leaves with the bar, so its onExit never arrives.
      // Without this the bar returns fully expanded under a cursor that is
      // nowhere near it.
      if (_immersiveRoute) _hovered = false;
    });
  }

  @override
  void onWindowMaximize() {
    _updateStates();
  }

  @override
  void onWindowUnmaximize() {
    _updateStates();
  }

  @override
  void onWindowEnterFullScreen() {
    _updateStates();
  }

  @override
  void onWindowLeaveFullScreen() {
    _updateStates();
  }

  Future<void> _updateStates() async {
    // A short delay gives the OS window manager time to finalize transitions (fullscreen/maximize/etc.)
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    final isMax = await windowManager.isMaximized();
    final isFull = await windowManager.isFullScreen();
    final isAlways = await windowManager.isAlwaysOnTop();
    if (mounted) {
      setState(() {
        _isMaximized = isMax;
        _isFullScreen = isFull;
        _isAlwaysOnTop = isAlways;
        // Same reason as _onImmersiveRouteChanged: going full screen takes the
        // MouseRegion away before it can report the pointer leaving.
        if (isFull) _hovered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nothing over the player, and nothing in full screen. This bar is stacked
    // above every route and drawn last, so it wins: hovered it is a 48px slab
    // over the player's own back button and title, and collapsed it is still
    // an invisible 8px band across the top of the video that eats pointers for
    // window furniture the viewer cannot see. Full screen has no furniture to
    // offer at all - F11 is the way back out.
    if (_immersiveRoute || _isFullScreen) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleBarColor = isDark
        ? const Color(0xE0050505)
        : const Color(0xD8FAF8F5); // Transparent warm off-white (85% opacity)
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF5C5C5C); // High contrast text/icon color

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: _hovered ? (Platform.isMacOS ? 28 : 48) : 8,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _hovered ? titleBarColor : Colors.transparent,
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_hovered)
              Positioned(
                left: Platform.isMacOS ? 80 : 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) {
                    windowManager.startDragging();
                  },
                  onDoubleTap: () async {
                    final isMax = await windowManager.isMaximized();
                    if (isMax) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
              ),
            // Pin icon on the left (visible when neither maximized nor fullscreen)
            if (_hovered && !_isFullScreen && !_isMaximized)
              Positioned(
                left: Platform.isMacOS ? 80 : 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _PinButton(
                    isActive: _isAlwaysOnTop,
                    onPressed: () async {
                      final nextState = !_isAlwaysOnTop;
                      await windowManager.setAlwaysOnTop(nextState);
                      await _updateStates();
                    },
                  ),
                ),
              ),
            // Right-side window controls (fullscreen, minimize, maximize/restore, close)
            if (!Platform.isMacOS)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _hovered ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_hovered,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Full Screen Toggle / Exit Full Screen
                          _TitleBarButton(
                            onPressed: () async {
                              await windowManager.setFullScreen(!_isFullScreen);
                              await _updateStates();
                            },
                            child: Icon(
                              _isFullScreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              color: iconColor,
                              size: 16,
                            ),
                          ),
                          if (!_isFullScreen) ...[
                            const SizedBox(width: 6),
                            // 2. Minimize
                            _TitleBarButton(
                              onPressed: () => windowManager.minimize(),
                              child: Center(
                                child: Container(
                                  width: 10,
                                  height: 1.5,
                                  color: iconColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // 3. Maximize / Restore
                            _TitleBarButton(
                              onPressed: () async {
                                if (_isMaximized) {
                                  await windowManager.unmaximize();
                                } else {
                                  await windowManager.maximize();
                                }
                                await _updateStates();
                              },
                              child: Center(
                                child: _isMaximized
                                    ? SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: Stack(
                                          children: [
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: iconColor,
                                                    width: 1.2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF050505)
                                                      : const Color(0xFFFAF8F5), // overlap box bg matches titlebar
                                                  border: Border.all(
                                                    color: iconColor,
                                                    width: 1.2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: iconColor,
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // 4. Close
                            _CloseButton(
                              onPressed: () => windowManager.close(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onPressed;

  const _PinButton({required this.isActive, required this.onPressed});

  @override
  State<_PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<_PinButton> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(
            0xFFE4D9C8,
          ); // Darker warm neutral tan hover background (#E4D9C8)

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(6),
        hoverColor: hoverColor,
        splashColor: hoverColor.withValues(alpha: 0.2),
        child: SizedBox(
          width: 32,
          height: Platform.isMacOS ? 28 : 32,
          child: Icon(
            widget.isActive ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: widget.isActive
                ? theme.colorScheme.primary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF5C5C5C).withValues(alpha: 0.6)),
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _TitleBarButton({required this.child, required this.onPressed});

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(
            0xFFE4D9C8,
          ); // Darker warm neutral tan hover background (#E4D9C8)

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(6),
        hoverColor: hoverColor,
        splashColor: hoverColor.withValues(alpha: 0.2),
        child: SizedBox(width: 32, height: 32, child: widget.child),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(6),
          hoverColor: Colors.red.withValues(alpha: 0.8),
          splashColor: Colors.red,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.close_rounded,
              color: _isHovered
                  ? Colors.white
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : const Color(0xFF5C5C5C)),
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}
