import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

/// Whether the player chrome is on screen, and the one clock that takes it
/// away.
///
/// The timer has no public surface. Callers say what happened - a [poke], a
/// [toggle], a hold for as long as a sheet or a drag or a resting mouse lasts -
/// and the clock is a consequence.
///
/// A [ValueNotifier] rather than widget state so gesture callbacks, key
/// handlers, sheet lifetimes and hover can all drive it without any of them
/// owning a setState; the chrome listens once.
class ChromeVisibilityController extends ValueNotifier<bool> {
  /// When [initiallyVisible] is false (default), the chrome starts hidden
  /// for an immersive viewing experience until summoned by explicit interaction.
  ChromeVisibilityController({
    required bool Function() isPlaying,
    this.hideAfter = const Duration(seconds: 2),
    bool initiallyVisible = false,
  }) : _isPlaying = isPlaying,
       super(initiallyVisible) {
    if (initiallyVisible) {
      _restart();
    }
  }

  /// Explicitly hides the chrome and clears the timer.
  void hide() => _hide();

  final Duration hideAfter;
  final bool Function() _isPlaying;

  Timer? _timer;
  int _holds = 0;
  bool _disposed = false;

  /// Whether an assistive technology is driving navigation - TalkBack,
  /// VoiceOver, Switch Access.
  ///
  /// The same bit `MediaQuery.accessibleNavigationOf` reports. Read off the
  /// binding rather than a context because this clock lives outside the widget
  /// tree, and read live on every decision rather than cached at construction,
  /// because a viewer can turn a screen reader on in the middle of a film.
  static bool get _accessibleNavigation => SemanticsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .accessibleNavigation;

  /// True while something owns the screen - a sheet, a drag, a mouse resting
  /// on a bar - and the chrome must not go out from under it.
  bool get isHeld => _holds > 0;

  /// Something happened that the viewer should see the chrome for. Reveals it
  /// if hidden and restarts the clock either way.
  ///
  /// With [hold] the clock stops instead, until the matching [release]. Holds
  /// nest, so a sheet opened from a hovered bar comes out right whichever
  /// ends first.
  void poke({bool hold = false}) {
    if (hold) _holds++;
    value = true;
    _restart();
  }

  /// Ends one hold. The clock re-arms only when the last one goes.
  void release() {
    assert(_holds > 0, 'release without a matching hold');
    if (_holds > 0) _holds--;
    _restart();
  }

  /// Keeps visible chrome alive without revealing hidden chrome. For raw
  /// pointer-down: a tap that dismisses the bars also produces one, and if
  /// that re-showed them the bars could never be dismissed at all.
  void keepAlive() {
    if (value) _restart();
  }

  /// The bare tap on the video. Hiding here is the viewer's explicit choice,
  /// so it goes through even while paused; a hold still wins, because what is
  /// being held is not what was tapped.
  void toggle() {
    if (!value) {
      poke();
    } else if (isHeld) {
      _restart();
    } else {
      _hide();
    }
  }

  /// Holds for the life of [action] - a sheet, a dialog - then re-arms.
  Future<T> whileHeld<T>(Future<T> Function() action) async {
    poke(hold: true);
    try {
      return await action();
    } finally {
      release();
    }
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || !value || isHeld) return;
    // A screen reader explores by swiping or flicking between elements, which
    // dispatches no pointer event to Flutter, so nothing in that exploration
    // pokes this clock. Hiding mid-exploration is not just visual: both bars
    // hide behind an opacity-0 AnimatedOpacity, and RenderAnimatedOpacityMixin
    // drops a fully transparent subtree from the semantics tree, so every
    // bottom-bar control leaves the accessibility tree and focus resets. So
    // while an assistive technology is driving, the chrome stays.
    if (_accessibleNavigation) return;
    _timer = Timer(hideAfter, _expire);
  }

  void _expire() {
    // Paused means the viewer is looking at something, so wait and re-check
    // rather than hiding on a schedule. Same for a screen reader switched on
    // after this timer was armed: [_restart] declines to re-arm.
    if (!_isPlaying() || _accessibleNavigation) {
      _restart();
      return;
    }
    _hide();
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    value = false;
  }

  /// A sheet can outlive the player and release its hold afterwards; that
  /// must not start a timer into a dead notifier.
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
