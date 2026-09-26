import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/core/utils/layout_constants.dart';
import 'package:skystream/core/utils/responsive_breakpoints.dart';
import 'package:skystream/shared/widgets/custom_bottom_nav.dart';
import 'package:skystream/shared/widgets/app_sidebar.dart';

import 'package:skystream/l10n/generated/app_localizations.dart';
import '../../features/settings/presentation/general_settings_provider.dart';
import 'loading_indicator.dart';

/// The shell's television cursor layer.
///
/// Named because there is more than one [MouseRegion] in the shell - the
/// sidebar's dock magnification and every InkWell add their own - and a test
/// asking "what is the cursor right now" has to be able to say which one it
/// means.
@visibleForTesting
const Key kTvCursorRegionKey = Key('app-scaffold-tv-cursor');

class AppScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  // Owned here so the content-area LEFT key handler can focus them directly,
  // crossing the Branch Navigator's FocusScope boundary. Count comes from
  // [kSidebarDestinationCount] in app_sidebar.dart — single source of truth.
  late final List<FocusNode> _sidebarNodes = List.generate(
    kSidebarDestinationCount,
    (i) => FocusNode(debugLabel: 'sidebar_$i'),
  );

  /// How long a pointer may sit still on a television before the cursor goes.
  ///
  /// Android TV boxes and Fire sticks report a pointer whether or not one is
  /// attached, and trackpad remotes move a real one, so a stationary arrow
  /// parked mid-screen is reachable on shipping hardware. Netflix, Prime Video
  /// and YouTube all take it away after roughly this long; so does Android
  /// TV's own launcher.
  static const Duration kTvCursorIdleTimeout = Duration(seconds: 3);

  /// Runs between the last pointer activity and the cursor going away.
  Timer? _cursorIdleTimer;

  /// Whether [kTvCursorIdleTimeout] has elapsed with the pointer still. Only
  /// ever true while [_cursorAutoHide] is true.
  bool _cursorHidden = false;

  /// Whether the cursor clock may run at all this frame. Written by [build],
  /// read by the pointer handlers and by the timer, so a stand-down also stops
  /// a clock that is already ticking. See [_setCursorAutoHide].
  bool _cursorAutoHide = false;

  /// Where the pointer was when the clock was last re-armed.
  ///
  /// Motion is what counts: a hover is re-delivered at an unchanged position
  /// when the widget under a *stationary* pointer changes, and a ten-foot home
  /// screen is carousels animating under it. Without this the clock would be
  /// re-armed forever and the cursor would never go. The player learned the
  /// same lesson - see `_onHover` in vlc_player_controls.dart.
  Offset? _pointerAt;

  @override
  void dispose() {
    _cursorIdleTimer?.cancel();
    for (final n in _sidebarNodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Every pointer event means the same two things: the focus highlight is no
  /// longer the thing being driven, and the cursor is in use.
  void _onPointerDown(PointerDownEvent event) {
    _pointerIsDriving();
    // A press is activity even when the pointer did not travel to get here, so
    // this one does not go through the motion filter: a click without a nudge
    // has to bring the cursor back.
    _pointerAt = event.position;
    _wakeCursor();
  }

  /// A pointer appearing at all - the box reporting a mouse at launch, or the
  /// viewer brushing a trackpad remote - starts the clock too. Without this an
  /// arrow that arrives and is never touched again would sit there for good,
  /// which is the exact thing this exists to stop.
  void _onPointerEnter(PointerEnterEvent event) {
    _pointerAt = event.position;
    _wakeCursor();
  }

  void _onPointerHover(PointerHoverEvent event) {
    _pointerIsDriving();
    _pointerMoved(event);
  }

  /// A drag: the press that started it already said who is driving, so this
  /// one only feeds the cursor clock. Which also keeps a touch device, where
  /// every scroll is a stream of these, exactly as cheap as it was before.
  void _onPointerMove(PointerMoveEvent event) => _pointerMoved(event);

  void _pointerMoved(PointerEvent event) {
    if (event.position == _pointerAt) return; // see [_pointerAt]
    _pointerAt = event.position;
    _wakeCursor();
  }

  void _pointerIsDriving() {
    ref.read<DpadActiveNotifier>(isDpadActiveProvider.notifier).set(false);
  }

  /// Shows the cursor now and starts the clock that will take it away.
  void _wakeCursor() {
    if (!_cursorAutoHide) return;
    if (_cursorHidden) {
      setState(() => _cursorHidden = false);
    }
    _cursorIdleTimer?.cancel();
    _cursorIdleTimer = Timer(kTvCursorIdleTimeout, _hideCursor);
  }

  void _hideCursor() {
    if (!mounted || !_cursorAutoHide || _cursorHidden) return;
    setState(() => _cursorHidden = true);
  }

  /// Latches whether the cursor clock may run, and puts the cursor back the
  /// instant it may not.
  ///
  /// Two things can forbid it. Off a television there is a real mouse on a
  /// desk and no OS hides that; and while another route sits on top of the
  /// shell the cursor belongs to whatever is up there. The player is the case
  /// that matters: it is a top-level route with a cursor auto-hide of its own
  /// (vlc_player_controls.dart, `MouseCursor.defer` while the bars are up),
  /// and a `defer` from an inner region resolves to whatever an outer one
  /// asks for - so a shell still holding `SystemMouseCursors.none` would hide
  /// the pointer out from under the player's visible chrome. Standing down
  /// here means the two can never disagree.
  void _setCursorAutoHide(bool value) {
    _cursorAutoHide = value;
    if (value) return;
    _cursorIdleTimer?.cancel();
    _cursorIdleTimer = null;
    _cursorHidden = false;
  }

  void _onItemTapped(int index, BuildContext context) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  int _getRouteIndex(String route) {
    switch (route) {
      case '/home':
        return 0;
      case '/search':
        return 1;
      case '/explore':
        return 2;
      case '/library':
        return 3;
      case '/settings':
        return 4;
      default:
        return 0;
    }
  }

  // Intercepts D-pad LEFT only when the currently focused widget has no
  // focusable neighbour to the left within the content area. In that case we
  // explicitly focus the sidebar item (different FocusScope, so directional
  // traversal can't bridge it on its own). Otherwise we let the event continue
  // so normal in-row navigation works.
  KeyEventResult _onContentKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return KeyEventResult.ignored;

    final moved = primary.focusInDirection(TraversalDirection.left);
    if (moved) {
      return KeyEventResult.handled;
    }
    // No focusable to the left in this scope — fall back to sidebar. Bail
    // back to ignored if the target node is out of range or unfocusable so
    // we don't silently swallow the Left key when focus can't move.
    final idx = widget.navigationShell.currentIndex;
    if (idx < 0 || idx >= _sidebarNodes.length) {
      return KeyEventResult.ignored;
    }
    final target = _sidebarNodes[idx];
    if (!target.canRequestFocus) {
      return KeyEventResult.ignored;
    }
    target.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final deviceProfileAsync = ref.watch(deviceProfileProvider);
    final defaultHome = ref.watch(
      generalSettingsProvider.select((s) => s.defaultHomeScreen),
    );
    final defaultIndex = _getRouteIndex(defaultHome);
    final isAtDefaultHome = widget.navigationShell.currentIndex == defaultIndex;

    return deviceProfileAsync.when(
      data: (profile) {
        // `isCurrent` is a dependency, so pushing or popping the player route
        // rebuilds this and flips the clock with it.
        _setCursorAutoHide(
          profile.isTv && (ModalRoute.of(context)?.isCurrent ?? true),
        );

        if (profile.isTv || context.isTabletOrLarger) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (isAtDefaultHome) {
                // Nothing is left to go back to. The shell's own route has
                // nowhere to pop to, so an unhandled back press is a button
                // that does nothing — the most common "the app is stuck"
                // report on a television. Leave the app instead.
                SystemNavigator.pop();
              } else {
                widget.navigationShell.goBranch(defaultIndex);
              }
            },
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerHover: _onPointerHover,
              onPointerMove: _onPointerMove,
              child: MouseRegion(
                key: kTvCursorRegionKey,
                // Not opaque: `deferToChild` adds no hit target of its own, so
                // taking the cursor away cannot take a tap away with it.
                opaque: false,
                onEnter: _onPointerEnter,
                // Present in every frame, cursor value or not. Putting the
                // MouseRegion into the tree only when it has something to say
                // would remount the branch Navigator under it and throw away
                // the scroll position of every screen in the shell.
                cursor: _cursorHidden
                    ? SystemMouseCursors.none
                    : MouseCursor.defer,
                child: Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      final key = event.logicalKey;
                      if (key == LogicalKeyboardKey.arrowDown ||
                          key == LogicalKeyboardKey.arrowUp ||
                          key == LogicalKeyboardKey.arrowLeft ||
                          key == LogicalKeyboardKey.arrowRight ||
                          key == LogicalKeyboardKey.enter ||
                          key == LogicalKeyboardKey.select ||
                          key == LogicalKeyboardKey.space ||
                          key == LogicalKeyboardKey.tab) {
                        ref
                            .read<DpadActiveNotifier>(
                              isDpadActiveProvider.notifier,
                            )
                            .set(true);
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Material(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: SafeArea(
                      bottom: false,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Content in its own traversal group, positioned first (bottom layer)
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: LayoutConstants.sidebarWidthCompact,
                              ),
                              child: FocusTraversalGroup(
                                policy: WidgetOrderTraversalPolicy(),
                                child: Focus(
                                  canRequestFocus: false,
                                  skipTraversal: true,
                                  onKeyEvent: _onContentKeyEvent,
                                  child: widget.navigationShell,
                                ),
                              ),
                            ),
                          ),
                          // Sidebar in its own traversal group, positioned second (top layer)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: LayoutConstants.sidebarWidthCompact,
                            child: FocusTraversalGroup(
                              policy: WidgetOrderTraversalPolicy(),
                              child: AppSidebar(
                                currentIndex:
                                    widget.navigationShell.currentIndex,
                                onItemTapped: (int index) =>
                                    _onItemTapped(index, context),
                                focusNodes: _sidebarNodes,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Mobile uses Bottom Navigation
        final bottomInset = CustomBottomNavBar.bottomInsetFor(context);
        final navBarTotalHeight = CustomBottomNavBar.height + bottomInset;
        final mq = MediaQuery.of(context);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (isAtDefaultHome) {
              // Same rule as the television branch: at the default home the
              // back button leaves the app instead of doing nothing.
              SystemNavigator.pop();
            } else {
              widget.navigationShell.goBranch(defaultIndex);
            }
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            extendBody: true,
            body: MediaQuery(
              data: mq.copyWith(
                padding: mq.padding.copyWith(
                  bottom: mq.padding.bottom + navBarTotalHeight,
                ),
                viewPadding: mq.viewPadding.copyWith(
                  bottom: mq.viewPadding.bottom + navBarTotalHeight,
                ),
              ),
              child: widget.navigationShell,
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: bottomInset,
              ),
              child: CustomBottomNavBar(
                currentIndex: widget.navigationShell.currentIndex,
                onTap: (index) => _onItemTapped(index, context),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: AppLoadingIndicator())),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text(
            AppLocalizations.of(context)!.errorPrefix(err.toString()),
          ),
        ),
      ),
    );
  }
}
