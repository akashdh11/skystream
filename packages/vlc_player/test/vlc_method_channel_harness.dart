import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_player/src/vlc_player_controller_internals.dart';
import 'package:vlc_player/vlc_player.dart';

class VlcMethodChannelHarness {
  static const MethodChannel methodChannel = MethodChannel('vlc_player');

  final List<MethodCall> calls = <MethodCall>[];
  final List<EventChannel> _eventChannels = <EventChannel>[];

  void install({Future<Object?> Function(MethodCall call)? onCall}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          calls.add(call);
          return onCall?.call(call);
        });
  }

  Future<void> attachController(VlcPlayerController controller, int viewId) {
    return (controller as VlcPlayerControllerInternals).attach(viewId);
  }

  Future<int> attachTexturePlayer(VlcPlayerController controller) {
    return (controller as VlcPlayerControllerInternals).attachTexturePlayer();
  }

  Future<void> detachController(VlcPlayerController controller) {
    return (controller as VlcPlayerControllerInternals).detach();
  }

  void mockEventChannel(int viewId) {
    final channel = EventChannel('vlc_player/events/$viewId');
    _eventChannels.add(channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          channel,
          MockStreamHandler.inline(onListen: (arguments, events) {}),
        );
  }

  Future<void> sendEvent(int viewId, Map<String, Object?> event) {
    final channel = EventChannel('vlc_player/events/$viewId');
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeSuccessEnvelope(event),
          null,
        );
  }

  Future<void> sendEvents(
    int viewId,
    Iterable<Map<String, Object?>> events,
  ) async {
    for (final event in events) {
      await sendEvent(viewId, event);
    }
  }

  Future<void> sendError(
    int viewId, {
    required String code,
    String? message,
    Object? details,
  }) {
    final channel = EventChannel('vlc_player/events/$viewId');
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeErrorEnvelope(
            code: code,
            message: message,
            details: details,
          ),
          null,
        );
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    for (final channel in _eventChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(channel, null);
    }
  }
}
