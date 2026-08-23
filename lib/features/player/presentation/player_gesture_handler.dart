import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../settings/presentation/player_settings_provider.dart';

part 'player_gesture_handler.g.dart';

enum PlayerDragMode { none, vertical, horizontal }

@immutable
class PlayerGestureState {
  final PlayerGesture? currentGesture;
  final bool showOSD;
  final IconData osdIcon;
  final double? osdValue;
  final String osdLabel;
  final Alignment osdAlignment;
  final PlayerDragMode activeDragMode;
  final Duration? swipeSeekValue;
  final Duration? swipeSeekStartValue;
  final bool? swipeSeekForward;

  const PlayerGestureState({
    this.currentGesture,
    this.showOSD = false,
    this.osdIcon = Icons.settings,
    this.osdValue,
    this.osdLabel = "",
    this.osdAlignment = Alignment.center,
    this.activeDragMode = PlayerDragMode.none,
    this.swipeSeekValue,
    this.swipeSeekStartValue,
    this.swipeSeekForward,
  });

  static const Object _keep = Object();

  PlayerGestureState copyWith({
    PlayerGesture? currentGesture,
    bool? showOSD,
    IconData? osdIcon,
    Object? osdValue = _keep,
    String? osdLabel,
    Alignment? osdAlignment,
    PlayerDragMode? activeDragMode,
    Object? swipeSeekValue = _keep,
    Object? swipeSeekStartValue = _keep,
    Object? swipeSeekForward = _keep,
  }) {
    return PlayerGestureState(
      currentGesture: currentGesture ?? this.currentGesture,
      showOSD: showOSD ?? this.showOSD,
      osdIcon: osdIcon ?? this.osdIcon,
      osdValue: identical(osdValue, _keep)
          ? this.osdValue
          : osdValue as double?,
      osdLabel: osdLabel ?? this.osdLabel,
      osdAlignment: osdAlignment ?? this.osdAlignment,
      activeDragMode: activeDragMode ?? this.activeDragMode,
      swipeSeekValue: identical(swipeSeekValue, _keep)
          ? this.swipeSeekValue
          : swipeSeekValue as Duration?,
      swipeSeekStartValue: identical(swipeSeekStartValue, _keep)
          ? this.swipeSeekStartValue
          : swipeSeekStartValue as Duration?,
      swipeSeekForward: identical(swipeSeekForward, _keep)
          ? this.swipeSeekForward
          : swipeSeekForward as bool?,
    );
  }
}

@Riverpod(keepAlive: true)
class PlayerGestureHandler extends _$PlayerGestureHandler {
  // We will initialize these via a setup method since they depend on the specific player instance
  Future<PlayerSettings> Function()? getSettings;
  bool? isTv;
  bool? isDesktop;

  // State from player
  Duration Function()? getDuration;
  Duration Function()? getPosition;
  bool Function()? canSeek;
  double Function()? getMaxVolumeLevel;

  // Callbacks to interact with UI
  VoidCallback? onInteraction;
  VoidCallback? onHideControls;
  Future<void> Function(Duration)? onSeekRelative;
  Future<void> Function(Duration)? onSeekTo;
  Future<double> Function()? getVolumeLevel;
  Future<double> Function(double value)? setVolumeLevel;
  Future<double> Function(double step)? onVolumeChange;
  Future<double> Function()? toggleMuteLevel;
  void Function(bool isLeft, Offset tapPos, int seekSeconds)?
  onDoubleTapAnimationStart;

  double _boostLevel = 1.0;
  Timer? _osdTimer;
  PlayerSettings? _cachedSettings;

  bool get supportsVolumeBoost =>
      getMaxVolumeLevel?.call() != null && getMaxVolumeLevel!() > 1.0;

  @override
  PlayerGestureState build() {
    ref.onDispose(() {
      _osdTimer?.cancel();
    });
    return const PlayerGestureState();
  }

  /// Drops every callback handed in by [init].
  ///
  /// This notifier is `keepAlive: true`, so it outlives the player screen. The
  /// closures [init] receives capture the controls' State — `setState`, the
  /// hide timer, `widget.*` — so leaving them attached pins that State and its
  /// whole element tree in memory for the rest of the app's life, once per
  /// player session. Call this from the controls' dispose().
  void detach() {
    getSettings = null;
    isTv = null;
    isDesktop = null;
    getDuration = null;
    getPosition = null;
    canSeek = null;
    getMaxVolumeLevel = null;
    onInteraction = null;
    onHideControls = null;
    onSeekRelative = null;
    onSeekTo = null;
    getVolumeLevel = null;
    setVolumeLevel = null;
    onVolumeChange = null;
    toggleMuteLevel = null;
    onDoubleTapAnimationStart = null;
    _osdTimer?.cancel();
    _osdTimer = null;
    _cachedSettings = null;
  }

  void init({
    required Future<PlayerSettings> Function() getSettings,
    required bool isTv,
    required bool isDesktop,
    required Duration Function() getDuration,
    required Duration Function() getPosition,
    required bool Function() canSeek,
    required double Function() getMaxVolumeLevel,
    required VoidCallback onInteraction,
    required VoidCallback onHideControls,
    required Future<void> Function(Duration) onSeekRelative,
    required Future<void> Function(Duration) onSeekTo,
    required Future<double> Function() getVolumeLevel,
    required Future<double> Function(double value) setVolumeLevel,
    required Future<double> Function(double step) onVolumeChange,
    required Future<double> Function() toggleMuteLevel,
    required void Function(bool isLeft, Offset tapPos, int seekSeconds)
    onDoubleTapAnimationStart,
  }) {
    this.getSettings = getSettings;
    this.isTv = isTv;
    this.isDesktop = isDesktop;
    this.getDuration = getDuration;
    this.getPosition = getPosition;
    this.canSeek = canSeek;
    this.getMaxVolumeLevel = getMaxVolumeLevel;
    this.onInteraction = onInteraction;
    this.onHideControls = onHideControls;
    this.onSeekRelative = onSeekRelative;
    this.onSeekTo = onSeekTo;
    this.getVolumeLevel = getVolumeLevel;
    this.setVolumeLevel = setVolumeLevel;
    this.onVolumeChange = onVolumeChange;
    this.toggleMuteLevel = toggleMuteLevel;
    this.onDoubleTapAnimationStart = onDoubleTapAnimationStart;
  }

  void _triggerOSDTimer() {
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 1), () {
      state = state.copyWith(showOSD: false);
    });
  }

  void dismissOSD() {
    state = state.copyWith(showOSD: false);
  }

  void showToast(String message, IconData icon) {
    state = state.copyWith(
      showOSD: true,
      osdIcon: icon,
      osdLabel: message,
      osdValue: null,
      osdAlignment: Alignment.bottomCenter,
    );

    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 2), () {
      state = state.copyWith(showOSD: false);
    });
  }

  // Pixels from each edge that are reserved for system gestures.
  static const double _edgeExclusionHorizontal = 48.0; // left/right
  static const double _edgeExclusionTop = 48.0; // top

  Future<void> handleDragStart(
    DragStartDetails details,
    double screenWidth,
    double screenHeight,
  ) async {
    if ((isTv ?? false) || (isDesktop ?? false)) return;
    if (state.activeDragMode == PlayerDragMode.horizontal) return;

    final x = details.globalPosition.dx;
    final y = details.globalPosition.dy;

    if (x < _edgeExclusionHorizontal ||
        x > screenWidth - _edgeExclusionHorizontal ||
        y < _edgeExclusionTop) {
      return;
    }

    if (getSettings == null) return;
    final settings = _cachedSettings ?? await getSettings!();
    _cachedSettings ??= settings;
    unawaited(getSettings!().then((s) => _cachedSettings = s));

    PlayerGesture type = PlayerGesture.none;
    Alignment alignment = state.osdAlignment;
    if (x < screenWidth / 2) {
      type = settings.leftGesture;
      alignment = Alignment.centerRight; // Opposite side
    } else {
      type = settings.rightGesture;
      alignment = Alignment.centerLeft; // Opposite side
    }

    if (type == PlayerGesture.none) return;

    double startVal = 0.5;
    if (type == PlayerGesture.brightness) {
      try {
        startVal = await ScreenBrightness().application;
      } catch (e) {
        startVal = 0.5;
      }
    } else {
      if (getVolumeLevel == null) return;
      startVal = await getVolumeLevel!();
      _boostLevel = supportsVolumeBoost && startVal > 1.0 ? startVal : 1.0;
    }

    state = state.copyWith(
      activeDragMode: PlayerDragMode.vertical,
      currentGesture: type,
      showOSD: true,
      osdIcon: _getIconForValue(type, startVal),
      osdValue: startVal,
      osdLabel: type == PlayerGesture.brightness ? "Brightness" : "Volume",
      osdAlignment: alignment,
      swipeSeekValue: null,
      swipeSeekStartValue: null,
      swipeSeekForward: null,
    );

    _osdTimer?.cancel();
  }

  void handleDragUpdate(DragUpdateDetails details) {
    if (state.activeDragMode != PlayerDragMode.vertical) return;
    if (state.currentGesture == null ||
        state.currentGesture == PlayerGesture.none) {
      return;
    }

    final delta = -(details.primaryDelta ?? 0) / 300;
    if (delta == 0) return;

    final double min = (state.currentGesture == PlayerGesture.brightness)
        ? -0.05
        : 0.0;
    final double max = (state.currentGesture == PlayerGesture.brightness)
        ? 1.0
        : (getMaxVolumeLevel?.call() ?? 1.0);

    final double newVal = ((state.osdValue ?? 0.0) + delta).clamp(min, max);

    if (state.currentGesture == PlayerGesture.brightness) {
      if (newVal <= 0.0) {
        ScreenBrightness().resetApplicationScreenBrightness();
        state = state.copyWith(
          osdValue: newVal,
          osdIcon: _getIconForValue(state.currentGesture!, newVal),
          osdLabel: "Auto",
        );
      } else {
        ScreenBrightness().setApplicationScreenBrightness(newVal);
        state = state.copyWith(
          osdValue: newVal,
          osdIcon: _getIconForValue(state.currentGesture!, newVal),
          osdLabel: "Brightness",
        );
      }
    } else {
      _boostLevel = supportsVolumeBoost && newVal > 1.0 ? newVal : 1.0;
      final Future<double>? future = setVolumeLevel?.call(newVal);
      unawaited(future?.then((_) => null) ?? Future.value());
      state = state.copyWith(
        osdValue: newVal,
        osdIcon: _getIconForValue(state.currentGesture!, newVal),
      );
    }
  }

  void handleDragEnd(DragEndDetails details) {
    if (state.activeDragMode != PlayerDragMode.vertical) return;
    state = state.copyWith(
      activeDragMode: PlayerDragMode.none,
      currentGesture: null,
    );
    _triggerOSDTimer();
  }

  Future<void> handleHorizontalDragStart(
    DragStartDetails details,
    bool isControlsVisible,
    double screenWidth,
    double screenHeight,
    double bottomPadding,
  ) async {
    if (state.activeDragMode == PlayerDragMode.vertical) return;
    if (getDuration == null ||
        getDuration!() == Duration.zero ||
        canSeek == null ||
        !canSeek!()) {
      return;
    }

    final settings = await getSettings!();
    if (!settings.swipeSeekEnabled) return;

    if ((isTv ?? false) || (isDesktop ?? false)) return;

    final x = details.globalPosition.dx;
    if (x < _edgeExclusionHorizontal ||
        x > screenWidth - _edgeExclusionHorizontal) {
      return;
    }

    if (isControlsVisible) {
      if (details.globalPosition.dy > (screenHeight - 56 - bottomPadding)) {
        return;
      }
    }

    final startPosition = getPosition?.call() ?? Duration.zero;
    state = state.copyWith(
      activeDragMode: PlayerDragMode.horizontal,
      currentGesture: null,
      showOSD: false,
      osdValue: null,
      swipeSeekValue: startPosition,
      swipeSeekStartValue: startPosition,
      swipeSeekForward: null,
    );
  }

  void handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (state.activeDragMode != PlayerDragMode.horizontal) return;
    if (state.swipeSeekValue == null) return;

    final delta = details.primaryDelta ?? 0;
    final newMs = (state.swipeSeekValue!.inMilliseconds + (delta * 200))
        .toInt();
    final clamped = newMs.clamp(0, getDuration?.call().inMilliseconds ?? 0);

    state = state.copyWith(
      swipeSeekValue: Duration(milliseconds: clamped),
      swipeSeekForward: delta == 0 ? state.swipeSeekForward : delta > 0,
    );
  }

  void handleHorizontalDragEnd(DragEndDetails details) {
    if (state.activeDragMode != PlayerDragMode.horizontal) return;
    if (state.swipeSeekValue == null) return;
    final target = state.swipeSeekValue!;
    state = state.copyWith(
      activeDragMode: PlayerDragMode.none,
      swipeSeekValue: null,
      swipeSeekStartValue: null,
      swipeSeekForward: null,
    );
    unawaited(onSeekTo?.call(target) ?? Future.value());
  }

  Future<void> handleDoubleTap(Offset tapPosition, double screenWidth) async {
    if (getDuration?.call() == Duration.zero || getSettings == null) return;

    final settings = await getSettings!();
    if (!settings.doubleTapEnabled) return;

    final isLeft = tapPosition.dx < screenWidth / 2;
    final seconds = settings.seekDuration;

    onDoubleTapAnimationStart?.call(isLeft, tapPosition, seconds);

    if (isLeft) {
      unawaited(
        onSeekRelative?.call(Duration(seconds: -seconds)) ?? Future.value(),
      );
    } else {
      unawaited(
        onSeekRelative?.call(Duration(seconds: seconds)) ?? Future.value(),
      );
    }
  }

  Future<void> toggleMute() async {
    final value = await toggleMuteLevel?.call();
    if (value == null) return;
    if (value <= 0) {
      showToast("Mute", Icons.volume_off);
    } else {
      _showVolumeOsd(value);
    }
  }

  Future<void> changeVolume(double step) async {
    final value = await onVolumeChange?.call(step);
    if (value == null) return;
    _showVolumeOsd(value);
  }

  void _showVolumeOsd(double value) {
    _boostLevel = supportsVolumeBoost && value > 1.0 ? value : 1.0;
    final double effectiveValue = (supportsVolumeBoost && _boostLevel > 1.0)
        ? _boostLevel
        : value;
    final String label = "Volume ${(effectiveValue * 100).toInt()}%";

    state = state.copyWith(
      showOSD: true,
      osdIcon: _getIconForValue(PlayerGesture.volume, value),
      osdValue: effectiveValue,
      osdLabel: label,
    );
    _triggerOSDTimer();
  }

  IconData _getIconForValue(PlayerGesture type, double value) {
    if (type == PlayerGesture.brightness) {
      if (value <= 0.0) return Icons.brightness_auto;
      if (value < 0.3) return Icons.brightness_low;
      if (value < 0.7) return Icons.brightness_medium;
      return Icons.brightness_high;
    } else if (type == PlayerGesture.volume) {
      if (value <= 0.0) return Icons.volume_off;
      if (value < 0.3) return Icons.volume_mute;
      if (value < 0.7) return Icons.volume_down;
      if (!supportsVolumeBoost || value <= 1.0) return Icons.volume_up;
      return Icons.campaign;
    }
    return Icons.settings;
  }
}
