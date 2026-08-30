import 'package:flutter/widgets.dart';
import 'package:vlc_player/vlc_player.dart';

/// Rebuilds only when the value it actually cares about changes.
///
/// [ValueListenableBuilder] rebuilds on every notification, and the player
/// notifies several times a second as the position advances. For chrome that
/// only depends on, say, whether playback is buffering, that is dozens of
/// pointless rebuilds a minute.
///
/// This matters more than it sounds on a platform view. The overlay is
/// composited *on top of* the native video surface, so every rebuild of a
/// full-screen widget above it re-uploads a window-sized texture — a cost that
/// grows with the window and shows up as flicker on a large one, while being
/// invisible on a small one.
class PlayerValueSelector<T> extends StatefulWidget {
  const PlayerValueSelector({
    required this.controller,
    required this.selector,
    required this.builder,
    super.key,
  });

  final VlcPlayerController controller;

  /// Extracts the one thing this widget renders from.
  final T Function(VlcPlayerValue value) selector;

  final Widget Function(BuildContext context, T value) builder;

  @override
  State<PlayerValueSelector<T>> createState() => _PlayerValueSelectorState<T>();
}

class _PlayerValueSelectorState<T> extends State<PlayerValueSelector<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.selector(widget.controller.value);
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant PlayerValueSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
      _value = widget.selector(widget.controller.value);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final next = widget.selector(widget.controller.value);
    if (next == _value) return;
    setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
